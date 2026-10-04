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
    private var player: AVPlayer?
    private var ended: NSObjectProtocol?
    private var request = 0
    func pause() { request += 1; player?.pause(); playing = false; loading = false }
    func toggle(start: Int) {
        if playing || loading { pause() }
        else if let player, verseID == start {
            if let item = player.currentItem { observeEnd(item, token: request) }
            player.play(); playing = true
        }
        else { play(start) }
    }
    func play(_ id: Int) {
        guard (1...6236).contains(id) else { return }
        request += 1; let token = request
        player?.pause(); playing = false; loading = true; verseID = id; error = nil
        let reciter = Reciter.available.first { $0.id == reciterID } ?? Reciter.available[0]
        Task {
            do {
                let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("QuranAudio/\(reciter.id)")
                let file = directory.appendingPathComponent("\(id).mp3")
                if !FileManager.default.fileExists(atPath: file.path) {
                    let remote = URL(string: "https://cdn.islamic.network/quran/audio/\(reciter.bitrate)/\(reciter.id)/\(id).mp3")!
                    let (temporary, response) = try await URLSession.shared.download(from: remote)
                    defer { try? FileManager.default.removeItem(at: temporary) }
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    if !FileManager.default.fileExists(atPath: file.path) { try FileManager.default.moveItem(at: temporary, to: file) }
                }
                guard token == request else { return }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let item = AVPlayerItem(url: file)
                player = AVPlayer(playerItem: item)
                observeEnd(item, token: token)
                player?.play(); loading = false; playing = true
            } catch { guard token == request else { return }; loading = false; playing = false; self.error = "Audio indisponible. Les versets déjà téléchargés peuvent être écoutés hors connexion." }
        }
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
    func changeReciter(_ id: String) { pause(); player = nil; reciterID = id }
    deinit { if let ended { NotificationCenter.default.removeObserver(ended) } }
}
