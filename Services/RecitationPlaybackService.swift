import AVFoundation
import Combine
import MediaPlayer

@MainActor final class RecitationPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var activeID: String?
    private var player: AVAudioPlayer?
    private var stream: AVPlayer?
    private var streamObserver: NSKeyValueObservation?
    var onCheckpoint: ((String, Double, Double) -> Void)?
    @Published private(set) var playbackError: String?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private let focusID = UUID()
    @Published private(set) var elapsed = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var paused = false
    private var speed: Float = 1
    @Published private(set) var sleepTimer = PlaybackSleepTimer()
    private var sleepTask: Task<Void, Never>?
    private var remoteGeneration = UUID()
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var streamNotifications: [NSObjectProtocol] = []
    private var streamTitle = "Roqya"
    private var streamArtist = ""
    enum RemoteAction: Sendable { case play, pause, toggle, stop, forward, backward, seek(Double) }
    func setSleepTimer(_ option: PlaybackSleepTimer.Option) {
        sleepTask?.cancel(); sleepTask = nil
        guard stream != nil else { sleepTimer.set(.off, now: ProcessInfo.processInfo.systemUptime); return }
        sleepTimer.set(option, now: ProcessInfo.processInfo.systemUptime)
        guard option.rawValue > 0 else { return }
        let token = remoteGeneration
        sleepTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(option.rawValue * 60)) } catch { return }
            guard let self, token == self.remoteGeneration else { return }
            self.checkSleepTimer()
        }
    }
    func checkSleepTimer(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard sleepTimer.expired(now: now) else { return }
        sleepTask?.cancel(); sleepTask = nil; sleepTimer.set(.off, now: ProcessInfo.processInfo.systemUptime)
        setStreamPaused(true)
    }
    func setStreamPaused(_ pause: Bool) {
        guard let stream else { return }
        if pause { stream.pause() } else { claimFocus(); stream.playImmediately(atRate: speed) }
        paused = pause; updateNowPlaying()
    }
    func handleRemote(_ action: RemoteAction) {
        guard stream != nil else { return }
        checkSleepTimer()
        switch action {
        case .play: setStreamPaused(false)
        case .pause: setStreamPaused(true)
        case .toggle: togglePause()
        case .stop: stop()
        case .forward: seekStream(elapsed + 15)
        case .backward: seekStream(elapsed - 15)
        case .seek(let seconds): seekStream(seconds)
        }
    }
    private func updateNowPlaying() {
        guard stream != nil, !remoteTargets.isEmpty else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: streamTitle, MPMediaItemPropertyArtist: streamArtist,
            MPMediaItemPropertyAlbumTitle: "Roqya", MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: paused ? 0.0 : Double(speed),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]
    }
    private func installRemoteControls() {
        let center = MPRemoteCommandCenter.shared(), token = remoteGeneration
        let actions: [(MPRemoteCommand, RemoteAction)] = [
            (center.playCommand, .play), (center.pauseCommand, .pause), (center.togglePlayPauseCommand, .toggle),
            (center.stopCommand, .stop), (center.skipForwardCommand, .forward), (center.skipBackwardCommand, .backward)
        ]
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]; center.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        for (command, action) in actions {
            command.isEnabled = true
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor in guard let self, self.remoteGeneration == token else { return }; self.handleRemote(action) }
                return .success
            }
            remoteTargets.append((command, target))
        }
        center.changePlaybackPositionCommand.isEnabled = true
        let seek = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let value = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = value.positionTime
            Task { @MainActor in guard let self, self.remoteGeneration == token else { return }; self.handleRemote(.seek(position)) }
            return .success
        }
        remoteTargets.append((center.changePlaybackPositionCommand, seek))
        let interruptions = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] event in
            let began = (event.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in guard began, let self, self.remoteGeneration == token else { return }; self.setStreamPaused(true) }
        }
        let routes = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] event in
            let removed = (event.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            Task { @MainActor in guard removed, let self, self.remoteGeneration == token else { return }; self.setStreamPaused(true) }
        }
        streamNotifications = [interruptions, routes]
        updateNowPlaying()
    }
    private func clearRemoteControls() {
        remoteGeneration = UUID(); sleepTask?.cancel(); sleepTask = nil
        sleepTimer.set(.off, now: ProcessInfo.processInfo.systemUptime)
        if !remoteTargets.isEmpty {
            for (command, target) in remoteTargets { command.removeTarget(target); command.isEnabled = false }
            remoteTargets = []; MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
        for observer in streamNotifications { NotificationCenter.default.removeObserver(observer) }; streamNotifications = []
    }
    private func claimFocus() { NativeAudioFocus.shared.claim(focusID) { [weak self] in self?.stop() } }
    func reserveFocus(onInterrupt: @escaping () -> Void) {
        NativeAudioFocus.shared.claim(focusID) { [weak self] in self?.stop(); onInterrupt() }
    }
    func playStream(url: URL, id: String, position: Double = 0, title: String = "Roqya", artist: String = "") throws {
        stop(); claimFocus()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        streamTitle = title; streamArtist = artist
        let value = AVPlayer(url: url); stream = value; activeID = id; paused = false; playbackError = nil
        streamObserver = value.currentItem?.observe(\.status, options: [.new]) { [weak self, weak value] item, _ in
            let failed = item.status == .failed
            Task { @MainActor in
                guard failed, let self, let value, self.stream === value else { return }
                self.stop(); self.playbackError = "Impossible de lire cet audio. Vérifie la connexion ou télécharge-le pour l’écouter hors connexion."
            }
        }
        timeObserver = value.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak value] time in
            Task { @MainActor in
                guard let self, let value, self.stream === value else { return }
                let length = value.currentItem?.duration.seconds ?? 0
                self.elapsed = time.seconds.isFinite ? max(0, time.seconds) : 0
                self.duration = length.isFinite ? max(0, length) : 0
                self.checkSleepTimer(); self.updateNowPlaying()
                if let id = self.activeID { self.onCheckpoint?(id, self.elapsed, self.duration) }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: value.currentItem, queue: .main) { [weak self, weak value] _ in
            Task { @MainActor in guard let self, let value, self.stream === value else { return }; self.stop() }
        }
        if position.isFinite && position > 0 { value.seek(to: CMTime(seconds: position, preferredTimescale: 600)) }
        value.playImmediately(atRate: speed)
        installRemoteControls()
    }
    func togglePause() {
        checkSleepTimer()
        setStreamPaused(!paused)
    }
    func setSpeed(_ value: Double) {
        guard [0.75, 1, 1.25, 1.5, 2].contains(value) else { return }
        speed = Float(value); if !paused { stream?.rate = speed }; updateNowPlaying()
    }
    func seekStream(_ seconds: Double) {
        guard seconds.isFinite, duration > 0 else { return }
        elapsed = min(duration, max(0, seconds))
        stream?.seek(to: CMTime(seconds: elapsed, preferredTimescale: 600)); updateNowPlaying()
    }
    func stop() {
        clearRemoteControls()
        if let id = activeID, elapsed > 0 { onCheckpoint?(id, elapsed, duration) }
        streamObserver?.invalidate(); streamObserver = nil
        player?.stop(); player = nil
        if let timeObserver { stream?.removeTimeObserver(timeObserver) }; timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        stream?.pause(); stream = nil; activeID = nil; paused = false; elapsed = 0; duration = 0
        NativeAudioFocus.shared.release(focusID)
    }
    func play(file: URL, id: String) throws {
        stop(); claimFocus()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        let value = try AVAudioPlayer(contentsOf: file)
        try begin(value, id: id)
    }
    func play(data: Data, id: String) throws {
        stop(); claimFocus()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        try begin(AVAudioPlayer(data: data), id: id)
    }
    private func begin(_ value: AVAudioPlayer, id: String) throws {
        value.delegate = self
        guard value.play() else { throw URLError(.cannotDecodeContentData) }
        player = value; activeID = id
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard let self, self.player === player else { return }; self.stop() }
    }
}
