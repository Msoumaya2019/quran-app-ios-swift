import AVFoundation
import Foundation

@MainActor final class QuranAudioService: ObservableObject {
    struct Reciter: Identifiable {
        let id: String; let name: String; let bitrate: Int
        static let available = [Reciter(id: "ar.shaatree", name: "Abu Bakr Ash-Shatri", bitrate: 128), Reciter(id: "ar.husary", name: "Mahmoud Khalil Al-Husary", bitrate: 128), Reciter(id: "ar.alafasy", name: "Mishary Alafasy", bitrate: 128), Reciter(id: "ar.minshawi", name: "Mohammed Siddiq Al-Minshawi", bitrate: 128)]
    }
    @Published var reciterID = "ar.shaatree"
    @Published private(set) var verseID = 1
    @Published private(set) var playing = false
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var repeatSettings = AudioRepeatSettings()
    @Published private(set) var repetition = 1
    private(set) var playbackRange = 1...6236
    private var transition: Task<Void, Never>?
    private var pendingRepeat: AudioRepeatSettings.Position?
    private var pendingDelay: Double = 0
    let timeline = QuranAudioTimeline()
    private let cache: QuranAudioCache
    private var player: AVPlayer?
    private var ended: NSObjectProtocol?
    private var timeObserver: Any?
    private var itemObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var pendingSeek: UUID?
    private var prefetch: Task<Void, Never>?
    private var request = 0
    init(cache: QuranAudioCache? = nil) {
        #if DEBUG
        if cache == nil, ProcessInfo.processInfo.arguments.contains("--ui-test-audio"),
           let url = Bundle.main.resourceURL?.appendingPathComponent("ReaderTestFixtures/audio.wav"),
           let data = try? Data(contentsOf: url) {
            self.cache = QuranAudioCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("UITestAudio-\(UUID().uuidString)"), downloader: { _ in data })
            return
        }
        #endif
        self.cache = cache ?? .shared
    }
    func pause() { request += 1; player?.pause(); playing = false; loading = false; prefetch?.cancel(); transition?.cancel(); transition = nil }
    func toggle(start: Int) {
        if playing || loading { pause() }
        else if pendingRepeat != nil, verseID == start {
            playing = true; scheduleTransition(token: request)
        }
        else if let player, verseID == start, player.currentItem?.status != .failed {
            if let item = player.currentItem { observeEnd(item, token: request) }
            if timeline.duration > 0 && timeline.elapsed >= timeline.duration - 0.1 { seek(to: 0) }
            player.playImmediately(atRate: Float(repeatSettings.speed)); playing = true
        }
        else { play(start) }
    }
    func configure(_ settings: AudioRepeatSettings) {
        guard settings.valid else { return }
        let rangeChanged = repeatSettings.rangeStart != settings.rangeStart || repeatSettings.rangeEnd != settings.rangeEnd
        repeatSettings = settings
        if rangeChanged, let first = settings.rangeStart, let last = settings.rangeEnd { updateRange(first...last) }
        if playing && transition == nil { player?.rate = Float(settings.speed) }
    }
    func updateRange(_ range: ClosedRange<Int>) {
        guard range.lowerBound >= 1, range.upperBound <= 6236, range != playbackRange else { return }
        playbackRange = range
        if !range.contains(verseID) {
            if playing || loading { play(range.lowerBound) }
            else { releasePlayer(); verseID = range.lowerBound; repetition = 1; timeline.update(elapsed: 0, duration: 0) }
        }
    }
    func start(range: ClosedRange<Int>, settings: AudioRepeatSettings) {
        guard range.lowerBound >= 1, range.upperBound <= 6236, settings.valid else { return }
        var value = settings; value.rangeStart = range.lowerBound; value.rangeEnd = range.upperBound
        playbackRange = range; configure(value); play(range.lowerBound)
    }
    func play(_ id: Int) { load(id, repetition: 1) }
    private func load(_ id: Int, repetition nextRepetition: Int) {
        guard (1...6236).contains(id) else { return }
        request += 1; let token = request
        releasePlayer(); prefetch?.cancel(); transition?.cancel(); transition = nil; pendingRepeat = nil
        playing = false; loading = true; verseID = id; repetition = nextRepetition; error = nil
        timeline.update(elapsed: 0, duration: 0)
        let reciter = Reciter.available.first { $0.id == reciterID } ?? Reciter.available[0]
        Task {
            do {
                let file = try await cache.file(reciterID: reciter.id, verseID: id)
                guard token == request else { return }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let item = AVPlayerItem(url: file)
                let nextPlayer = AVPlayer(playerItem: item)
                player = nextPlayer
                observeProgress(nextPlayer, item: item)
                observeEnd(item, token: token)
                player?.playImmediately(atRate: Float(repeatSettings.speed)); loading = false; playing = true
                if id < 6236 {
                    let cache = cache
                    prefetch = Task { _ = try? await cache.file(reciterID: reciter.id, verseID: id + 1) }
                }
            } catch { guard token == request else { return }; loading = false; playing = false; self.error = "Audio indisponible. Les versets déjà téléchargés peuvent être écoutés hors connexion." }
        }
    }
    func seek(to seconds: Double) {
        guard seconds.isFinite, timeline.duration > 0, let player else { return }
        let value = min(max(0, seconds), timeline.duration)
        let operation = UUID(); pendingSeek = operation
        player.seek(to: CMTime(seconds: value, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] finished in
            Task { @MainActor [weak self, weak player] in
                guard let self, let player, self.player === player, self.pendingSeek == operation else { return }
                self.pendingSeek = nil
                self.timeline.update(elapsed: finished ? value : player.currentTime().seconds, duration: self.timeline.duration)
            }
        }
        timeline.update(elapsed: value, duration: timeline.duration)
    }
    private func observeProgress(_ observedPlayer: AVPlayer, item: AVPlayerItem) {
        timeObserver = observedPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self, weak observedPlayer] time in
            Task { @MainActor [weak self, weak observedPlayer] in
                guard let self, let observedPlayer, self.player === observedPlayer, self.pendingSeek == nil else { return }
                self.updateProgress(elapsed: time.seconds, duration: observedPlayer.currentItem?.duration.seconds ?? 0)
            }
        }
        itemObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === observed else { return }
                if observed.status == .readyToPlay {
                    self.updateProgress(elapsed: self.player?.currentTime().seconds ?? 0, duration: observed.duration.seconds)
                } else if observed.status == .failed {
                    self.pause(); self.error = "Ce fichier audio n’a pas pu être lu. Réessaie avec un autre réciteur."
                }
            }
        }
        durationObserver = item.observe(\.duration, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === observed, self.pendingSeek == nil else { return }
                self.updateProgress(elapsed: self.player?.currentTime().seconds ?? 0, duration: observed.duration.seconds)
            }
        }
    }
    private func updateProgress(elapsed: Double, duration: Double) {
        // An indefinite duration during preparation must not erase known metadata.
        timeline.update(elapsed: elapsed, duration: duration.isFinite && duration > 0 ? duration : timeline.duration)
    }
    private func releasePlayer() {
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil; itemObserver?.invalidate(); itemObserver = nil
        durationObserver?.invalidate(); durationObserver = nil; pendingSeek = nil
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = nil; player = nil
    }
    private func observeEnd(_ item: AVPlayerItem, token: Int) {
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.request == token, self.playing, self.player?.currentItem === item else { return }
                guard let next = self.repeatSettings.next(range: self.playbackRange, current: .init(verse: self.verseID, repetition: self.repetition)) else { self.pause(); return }
                let isRepeat = self.repeatSettings.mode == .eachVerse ? next.verse == self.verseID : next.repetition > self.repetition
                let delay = max(isRepeat ? Double(self.repeatSettings.gap) : 0.2, Double(self.repeatSettings.recitePause ?? 0))
                self.pendingRepeat = next; self.pendingDelay = delay
                self.scheduleTransition(token: token)
            }
        }
    }
    private func scheduleTransition(token: Int) {
        guard pendingRepeat != nil else { return }
        let delay = pendingDelay
        transition = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
            guard let self, self.request == token, self.playing else { return }
            guard let next = self.repeatSettings.next(range: self.playbackRange, current: .init(verse: self.verseID, repetition: self.repetition)) else { self.pendingRepeat = nil; self.pause(); return }
            if !self.playbackRange.contains(next.verse) { self.playbackRange = next.verse...(self.repeatSettings.ending == .nextVerse ? next.verse : 6236) }
            self.transition = nil
            if next.verse == self.verseID, let player = self.player {
                await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                guard self.request == token, self.playing else { return }
                self.pendingRepeat = nil; self.repetition = next.repetition
                self.timeline.update(elapsed: 0, duration: self.timeline.duration)
                if let item = player.currentItem { self.observeEnd(item, token: token) }
                player.playImmediately(atRate: Float(self.repeatSettings.speed))
            } else { self.pendingRepeat = nil; self.load(next.verse, repetition: next.repetition) }
        }
    }
    func changeReciter(_ id: String) {
        guard Reciter.available.contains(where: { $0.id == id }), id != reciterID else { return }
        let resume = playing
        pause(); pendingRepeat = nil; releasePlayer(); timeline.update(elapsed: 0, duration: 0); reciterID = id
        if resume { play(verseID) }
    }
    deinit {
        prefetch?.cancel(); transition?.cancel()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let ended { NotificationCenter.default.removeObserver(ended) }
    }
}
