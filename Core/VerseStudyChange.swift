import Foundation

/// Individual actions replay through ReaderOperation and the existing shared state queue.
struct VerseStudyChange: Codable, Sendable {
    enum Action: String, Codable { case learned, nextRevision }
    let verseID: Int
    let action: Action
    let day: String
    let at: String
    init(verseID: Int, action: Action, now: Date = .now) {
        self.verseID = verseID; self.action = action; day = LocalCalendar.key(now, timeZone: .current)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; at = formatter.string(from: now)
    }
    func applying(to state: JSONValue) -> JSONValue {
        guard (1...6236).contains(verseID) else { return state }
        let key = String(verseID)
        guard (state["nativeVerseActionAt"][action.rawValue][key].string ?? "") < at else { return state }
        var result = state
        if action == .nextRevision {
            guard ["perfect", "review"].contains(state["knowledge"][key].string ?? "") else { return state }
            result = result.setting("nativeManualReviewDue", state["nativeManualReviewDue"].setting(key, .string(day)))
        } else {
            if !["perfect", "review"].contains(state["knowledge"][key].string ?? "") {
                var dates: [String: JSONValue] = [:]
                for offset in [1, 3, 7] { if let date = ProgramProjection.addingDays(offset, to: day, timeZone: TimeZone(secondsFromGMT: 0)!) { dates[String(offset)] = .string(date) } }
                result = result.setting("memorizedAt", state["memorizedAt"].setting(key, .string(day)))
                    .setting("reviewConsolidations", state["reviewConsolidations"].setting(key, .object(["learnedAt": .string(day), "scheduledDates": .object(dates), "completed": .object([:])])))
                    .setting("knowledge", state["knowledge"].setting(key, .string("perfect")))
            }
        }
        return result.setting("nativeVerseActionAt", state["nativeVerseActionAt"].setting(action.rawValue, state["nativeVerseActionAt"][action.rawValue].setting(key, .string(at))))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}
