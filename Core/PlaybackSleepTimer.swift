import Foundation

/// A process-local clock that includes device sleep and ignores wall-clock changes.
enum PlaybackMonotonicClock {
    private static let origin = ContinuousClock.now
    static var now: TimeInterval {
        let duration = origin.duration(to: ContinuousClock.now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1_000_000_000_000_000_000
    }
}

struct PlaybackSleepTimer: Equatable {
    enum Option: Int, CaseIterable, Identifiable {
        case off = 0, five = 5, ten = 10, fifteen = 15, thirty = 30, sixty = 60, end = -1
        var id: Int { rawValue }
        var title: String {
            switch self { case .off: return "Désactivée"; case .end: return "Fin de l’audio"; default: return "\(rawValue) minutes" }
        }
    }
    private(set) var option: Option = .off
    private(set) var deadline: TimeInterval?
    mutating func set(_ option: Option, now: TimeInterval) {
        self.option = option
        deadline = option.rawValue > 0 ? now + Double(option.rawValue * 60) : nil
    }
    func remaining(now: TimeInterval) -> Int? { deadline.map { Int(ceil(max(0, $0 - now))) } }
    func expired(now: TimeInterval) -> Bool { deadline.map { now >= $0 } ?? false }
}
