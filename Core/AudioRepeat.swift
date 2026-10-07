import Foundation

struct AudioRepeatSettings: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable { case passage, eachVerse = "each-verse" }
    var mode: Mode = .eachVerse
    /// Zero means continuous playback.
    var count = 1
    var gap = 0
    var speed: Double = 1
    var autoStop = true
    enum After: String, Codable, CaseIterable { case stop, nextVerse, continuous }
    var after: After? = nil
    var recitePause: Int? = nil
    var rangeStart: Int? = nil
    var rangeEnd: Int? = nil
    var selection: String? = nil
    var ending: After { after ?? (autoStop ? .stop : .continuous) }
    var valid: Bool { (0...999).contains(count) && [0, 1, 2, 3, 5, 10].contains(gap) && [0.75, 0.85, 1, 1.15, 1.25].contains(speed) && [0, 3, 5, 10, 15].contains(recitePause ?? 0) && (rangeStart == nil && rangeEnd == nil || (1...6236).contains(rangeStart ?? 0) && (rangeEnd ?? 0) >= (rangeStart ?? 0) && (rangeEnd ?? 0) <= 6236) }
    var countLabel: String { count == 0 ? "∞" : String(count) }
    struct Position: Equatable { let verse: Int; let repetition: Int }
    func next(range: ClosedRange<Int>, current: Position) -> Position? {
        guard valid, range.lowerBound >= 1, range.upperBound <= 6236, range.contains(current.verse), current.repetition > 0 else { return nil }
        if mode == .eachVerse {
            if count == 0 || current.repetition < count { return Position(verse: current.verse, repetition: current.repetition + 1) }
            if current.verse < range.upperBound { return Position(verse: current.verse + 1, repetition: 1) }
            if after == .continuous || ending == .nextVerse { return range.upperBound < 6236 ? Position(verse: range.upperBound + 1, repetition: 1) : nil }
            return ending == .stop ? nil : Position(verse: range.lowerBound, repetition: 1)
        }
        if current.verse < range.upperBound { return Position(verse: current.verse + 1, repetition: current.repetition) }
        if count == 0 || current.repetition < count { return Position(verse: range.lowerBound, repetition: current.repetition + 1) }
        if after == .continuous { return range.upperBound < 6236 ? Position(verse: range.upperBound + 1, repetition: 1) : nil }
        if ending == .continuous { return Position(verse: range.lowerBound, repetition: current.repetition + 1) }
        if ending == .nextVerse { return range.upperBound < 6236 ? Position(verse: range.upperBound + 1, repetition: 1) : nil }
        return nil
    }
    static func load(_ state: JSONValue) -> Self {
        guard let data = try? JSONEncoder().encode(state["audioPreferences"]["nativeRepeat"]),
              let settings = try? JSONDecoder().decode(Self.self, from: data), settings.valid else { return Self() }
        return settings
    }
    func applying(to state: JSONValue, at: String) -> JSONValue {
        guard valid, (state["audioPreferences"]["nativeRepeatUpdatedAt"].string ?? "") < at,
              let data = try? JSONEncoder().encode(self), let json = try? JSONDecoder().decode(JSONValue.self, from: data) else { return state }
        return state.setting("audioPreferences", state["audioPreferences"].setting("nativeRepeat", json).setting("nativeRepeatUpdatedAt", .string(at)))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}
