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
    let timeline = QuranAudioTimeline()
    private let cache: QuranAudioCache
    private var player: AVPlayer?
    private var ended: NSObjectProtocol?
    private var timeObserver: Any?
    private var itemObserver: NSKeyValueObservation?
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
    func pause() { request += 1; player?.pause(); playing = false; loading = false; prefetch?.cancel() }
    func toggle(start: Int) {
        if playing || loading { pause() }
        else if let player, verseID == start, player.currentItem?.status != .failed {
            if let item = player.currentItem { observeEnd(item, token: request) }
            if timeline.duration > 0 && timeline.elapsed >= timeline.duration - 0.1 { seek(to: 0) }
            player.play(); playing = true
        }
        else { play(start) }
    }
    func play(_ id: Int) {
        guard (1...6236).contains(id) else { return }
        request += 1; let token = request
        releasePlayer(); prefetch?.cancel()
        playing = false; loading = true; verseID = id; error = nil
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
                player?.play(); loading = false; playing = true
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
        player.seek(to: CMTime(seconds: value, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        timeline.update(elapsed: value, duration: timeline.duration)
    }
    private func observeProgress(_ observedPlayer: AVPlayer, item: AVPlayerItem) {
        timeObserver = observedPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self, weak observedPlayer] time in
            Task { @MainActor [weak self, weak observedPlayer] in
                guard let self, let observedPlayer, self.player === observedPlayer else { return }
                self.timeline.update(elapsed: time.seconds, duration: observedPlayer.currentItem?.duration.seconds ?? 0)
            }
        }
        itemObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === observed else { return }
                if observed.status == .readyToPlay {
                    self.timeline.update(elapsed: self.player?.currentTime().seconds ?? 0, duration: observed.duration.seconds)
                } else if observed.status == .failed {
                    self.pause(); self.error = "Ce fichier audio n’a pas pu être lu. Réessaie avec un autre réciteur."
                }
            }
        }
    }
    private func releasePlayer() {
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil; itemObserver?.invalidate(); itemObserver = nil
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = nil; player = nil
    }
    private func observeEnd(_ item: AVPlayerItem, token: Int) {
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.request == token, self.playing, self.player?.currentItem === item else { return }
                if self.verseID < 6236 { self.play(self.verseID + 1) } else { self.pause() }
            }
        }
    }
    func changeReciter(_ id: String) {
        guard Reciter.available.contains(where: { $0.id == id }), id != reciterID else { return }
        let resume = playing
        pause(); releasePlayer(); timeline.update(elapsed: 0, duration: 0); reciterID = id
        if resume { play(verseID) }
    }
    deinit {
        prefetch?.cancel()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let ended { NotificationCenter.default.removeObserver(ended) }
    }
}
