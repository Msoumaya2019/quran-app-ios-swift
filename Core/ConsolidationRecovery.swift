import Foundation

enum ConsolidationRecovery {
    /// Backfill old accounts only from actual review history, as in the existing app.
    static func applying(to state: JSONValue) -> JSONValue {
        let zone = TimeZone(secondsFromGMT: 0)!
        let events = state["reviewHistory"].array.compactMap { row -> (VerseRange, String, String?)? in
            guard let range = VerseRange(json: row), let date = row["date"].string,
                  ProgramProjection.addingDays(0, to: date, timeZone: zone) != nil else { return nil }
            return (range, date, row["completedAt"].string)
        }.sorted { ($0.1, $0.0.start) < ($1.1, $1.0.start) }
        var rows = state["reviewConsolidations"], dates: [String: JSONValue] = [:]
        for (id, knowledge) in state["knowledge"].object {
            guard let verse = Int(id), (1...6236).contains(verse), ["perfect", "review"].contains(knowledge.string ?? ""),
                  let learned = state["memorizedAt"][id].string else { continue }
            if dates[learned] == nil {
                guard ProgramProjection.addingDays(0, to: learned, timeZone: zone) != nil else { continue }
                dates[learned] = .object(Dictionary(uniqueKeysWithValues: [1, 3, 7].compactMap { offset -> (String, JSONValue)? in
                    ProgramProjection.addingDays(offset, to: learned, timeZone: zone).map { (String(offset), .string($0)) }
                }))
            }
            let stored = rows[id], scheduled = dates[learned]!
            if stored["learnedAt"].string == learned {
                var rowDates = stored["scheduledDates"]
                for offset in ["1", "3", "7"] where rowDates[offset] == .null { rowDates = rowDates.setting(offset, scheduled[offset]) }
                rows = rows.setting(id, stored.setting("scheduledDates", rowDates))
                continue
            }
            var completed: JSONValue = .object([:]), completedAt: JSONValue = .object([:]), previous = ""
            for offset in ["1", "3", "7"] {
                guard let due = scheduled[offset].string, let event = events.first(where: {
                    ($0.0.start...$0.0.end).contains(verse) && $0.1 >= due && $0.1 > previous
                }) else { break }
                completed = completed.setting(offset, .string(event.1)); previous = event.1
                if let at = event.2 { completedAt = completedAt.setting(offset, .string(at)) }
            }
            rows = rows.setting(id, stored.setting("learnedAt", .string(learned)).setting("scheduledDates", scheduled)
                .setting("completed", completed).setting("completedAt", completedAt))
        }
        return rows == state["reviewConsolidations"] ? state : state.setting("reviewConsolidations", rows)
    }
}
