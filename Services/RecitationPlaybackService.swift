import AVFoundation
import Combine

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
    private func claimFocus() { NativeAudioFocus.shared.claim(focusID) { [weak self] in self?.stop() } }
    func playStream(url: URL, id: String, position: Double = 0) throws {
        stop(); claimFocus()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
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
                if let id = self.activeID { self.onCheckpoint?(id, self.elapsed, self.duration) }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: value.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        if position.isFinite && position > 0 { value.seek(to: CMTime(seconds: position, preferredTimescale: 600)) }
        value.playImmediately(atRate: speed)
    }
    func togglePause() {
        guard let stream else { return }
        if paused { claimFocus(); stream.playImmediately(atRate: speed) } else { stream.pause() }
        paused.toggle()
    }
    func setSpeed(_ value: Double) {
        guard [0.75, 1, 1.25, 1.5, 2].contains(value) else { return }
        speed = Float(value); if !paused { stream?.rate = speed }
    }
    func seekStream(_ seconds: Double) {
        guard seconds.isFinite, duration > 0 else { return }
        stream?.seek(to: CMTime(seconds: min(duration, max(0, seconds)), preferredTimescale: 600))
    }
    func stop() {
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
