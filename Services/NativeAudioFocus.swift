import Foundation

/// One foreground audio owner across Quran, personal recitations, Roqya and recording.
@MainActor final class NativeAudioFocus {
    static let shared = NativeAudioFocus()
    private var owner: UUID?
    private var interrupt: (() -> Void)?
    func claim(_ id: UUID, interrupt: @escaping () -> Void) {
        if owner != id { let previous = self.interrupt; owner = nil; self.interrupt = nil; previous?() }
        owner = id; self.interrupt = interrupt
    }
    func release(_ id: UUID) { if owner == id { owner = nil; interrupt = nil } }
}
