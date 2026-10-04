import AVFoundation
import Combine

@MainActor final class RecitationPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var activeID: String?
    private var player: AVAudioPlayer?
    func stop() { player?.stop(); player = nil; activeID = nil }
    func play(file: URL, id: String) throws {
        stop()
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        let value = try AVAudioPlayer(contentsOf: file)
        value.delegate = self
        guard value.play() else { throw URLError(.cannotDecodeContentData) }
        player = value; activeID = id
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard let self, self.player === player else { return }; self.stop() }
    }
}
