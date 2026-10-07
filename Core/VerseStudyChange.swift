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
            let reviewedToday = state["reviewHistory"].array.contains { row in row["date"].string == day && VerseRange(json: row).map { ($0.start...$0.end).contains(verseID) } == true }
            let due = reviewedToday ? ProgramProjection.addingDays(1, to: day, timeZone: TimeZone(secondsFromGMT: 0)!) ?? day : day
            result = result.setting("nativeManualReviewDue", state["nativeManualReviewDue"].setting(key, .string(due)))
        } else {
            if !["perfect", "review"].contains(state["knowledge"][key].string ?? "") {
                var dates: [String: JSONValue] = [:]
                for offset in [1, 3, 7] { if let date = ProgramProjection.addingDays(offset, to: day, timeZone: TimeZone(secondsFromGMT: 0)!) { dates[String(offset)] = .string(date) } }
                result = result.setting("memorizedAt", state["memorizedAt"].setting(key, .string(day)))
                    .setting("reviewConsolidations", state["reviewConsolidations"].setting(key, .object(["learnedAt": .string(day), "scheduledDates": .object(dates), "completed": .object([:])])))
                    .setting("knowledge", state["knowledge"].setting(key, .string("perfect")))
                let progress: JSONValue = .object(["id": .string("verse-\(verseID)"), "mode": .string("learning"), "start": .number(Double(verseID)), "end": .number(Double(verseID)), "through": .number(Double(verseID)), "status": .string("completed"), "updatedAt": .string(at), "validations": .array([.object(["start": .number(Double(verseID)), "end": .number(Double(verseID)), "date": .string(day), "validatedAt": .string(at)])])])
                result = result.setting("studyProgress", state["studyProgress"].setting("learning:verse-\(verseID)", progress))
                var revisions = state["revisions"].array
                let revisionID = "r-\(verseID)-\(verseID)"
                if !revisions.contains(where: { $0["id"].string == revisionID }), let due = dates["1"] {
                    revisions.append(.object(["id": .string(revisionID), "start": .number(Double(verseID)), "end": .number(Double(verseID)), "due": due, "interval": .number(1), "streak": .number(0), "completedCount": .number(0)]))
                    result = result.setting("revisions", .array(revisions))
                }
            }
        }
        return result.setting("nativeVerseActionAt", state["nativeVerseActionAt"].setting(action.rawValue, state["nativeVerseActionAt"][action.rawValue].setting(key, .string(at))))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}
