import Foundation

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
