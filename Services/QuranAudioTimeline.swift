import Foundation
import Combine

/// Only the timeline view subscribes: playback ticks never invalidate the Mushaf.
@MainActor final class QuranAudioTimeline: ObservableObject {
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    func update(elapsed: Double, duration: Double) {
        let length = duration.isFinite && duration > 0 ? duration : 0
        self.duration = length
        self.elapsed = elapsed.isFinite ? min(max(0, elapsed), length) : 0
    }
    static func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let value = Int(min(seconds, 86_400))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
