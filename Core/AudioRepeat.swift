import Foundation

struct AudioRepeatSettings: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable { case passage, eachVerse = "each-verse" }
    var mode: Mode = .eachVerse
    /// Zero means continuous playback.
    var count = 1
    var gap = 0
    var speed: Double = 1
    var autoStop = true
    var valid: Bool { (0...999).contains(count) && [0, 2, 5, 10].contains(gap) && [0.75, 1, 1.25].contains(speed) }
    var countLabel: String { count == 0 ? "∞" : String(count) }
    struct Position: Equatable { let verse: Int; let repetition: Int }
    func next(range: ClosedRange<Int>, current: Position) -> Position? {
        guard valid, range.lowerBound >= 1, range.upperBound <= 6236, range.contains(current.verse), current.repetition > 0 else { return nil }
        if mode == .eachVerse {
            if count == 0 || current.repetition < count { return Position(verse: current.verse, repetition: current.repetition + 1) }
            if current.verse < range.upperBound { return Position(verse: current.verse + 1, repetition: 1) }
            return autoStop ? nil : Position(verse: range.lowerBound, repetition: 1)
        }
        if current.verse < range.upperBound { return Position(verse: current.verse + 1, repetition: current.repetition) }
        if count == 0 || !autoStop || current.repetition < count { return Position(verse: range.lowerBound, repetition: current.repetition + 1) }
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
