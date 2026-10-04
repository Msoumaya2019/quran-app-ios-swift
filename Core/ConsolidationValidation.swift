import Foundation

/// Immutable learning anchor makes retries safe even after a later consolidation or relearning.
struct ConsolidationValidation: Codable, Sendable {
    let start: Int
    let end: Int
    let learnedAt: String
    let offset: Int
    let completedDate: String
    let completedAt: String
    init?(context: QuranSessionContext, now: Date = .now, timeZone: TimeZone = .current) {
        guard context.mode == .consolidation, let learned = context.learnedAt,
              let offset = context.consolidationDay, [1, 3, 7].contains(offset) else { return nil }
        start = context.range.start; end = context.range.end; learnedAt = learned; self.offset = offset
        completedDate = LocalCalendar.key(now, timeZone: timeZone)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        completedAt = formatter.string(from: now)
    }
    func applying(to state: JSONValue) -> JSONValue {
        guard (1...6236).contains(start), (start...6236).contains(end), [1, 3, 7].contains(offset) else { return state }
        var rows = state["reviewConsolidations"]
        var history = state["consolidationHistory"].array
        var changed = false
        for verse in start...end {
            let key = String(verse), row = rows[key]
            guard ["perfect", "review"].contains(state["knowledge"][key].string ?? ""),
                  state["memorizedAt"][key].string == learnedAt, row["learnedAt"].string == learnedAt,
                  [1, 3, 7].first(where: { row["completed"][String($0)] == .null }) == offset,
                  let scheduled = row["scheduledDates"][String(offset)].string ?? ProgramProjection.addingDays(offset, to: learnedAt, timeZone: TimeZone(secondsFromGMT: 0)!) else { continue }
            let eventID = "\(verse)-\(learnedAt)-\(offset)"
            guard !history.contains(where: { $0["id"].string == eventID }) else { continue }
            rows = rows.setting(key, row.setting("completed", row["completed"].setting(String(offset), .string(completedDate)))
                .setting("completedAt", row["completedAt"].setting(String(offset), .string(completedAt))))
            history.append(.object(["id": .string(eventID), "verseId": .number(Double(verse)), "offset": .number(Double(offset)), "learnedAt": .string(learnedAt), "scheduledDate": .string(scheduled), "completedAt": .string(completedAt)]))
            changed = true
        }
        guard changed else { return state }
        return state.setting("reviewConsolidations", rows).setting("consolidationHistory", .array(history))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", completedAt)))
    }
}
