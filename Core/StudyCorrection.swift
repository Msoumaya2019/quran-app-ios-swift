import Foundation

/// Explicit user corrections, merged into the existing user_state contract and offline queue.
struct StudyCorrection: Codable, Sendable {
    enum Action: String, Codable, Hashable { case learned, review, unlearned, revised, removeRevision }
    let id: UUID
    let action: Action
    let start: Int
    let end: Int
    let day: String
    let today: String
    let at: String
    let original: JSONValue?
    var preserveKnown: Bool? = nil
    init(action: Action, start: Int, end: Int, date: Date, original: JSONValue? = nil, preserveKnown: Bool = false, now: Date = .now) {
        id = UUID(); self.action = action; self.start = start; self.end = end
        day = LocalCalendar.key(date); today = LocalCalendar.key(now); self.original = original; self.preserveKnown = preserveKnown
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        at = formatter.string(from: now)
    }
    func applying(to state: JSONValue) -> JSONValue {
        guard (1...6236).contains(start), (start...6236).contains(end), day <= today,
              ProgramProjection.addingDays(0, to: day, timeZone: TimeZone(secondsFromGMT: 0)!) != nil,
              (state["nativeStudyResetAt"].string ?? "") < at,
              !state["nativeStudyCorrections"].array.contains(where: { $0["id"].string == id.uuidString }) else { return state }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard formatter.date(from: at) != nil else { return state }
        let selected = Set(start...end)
        var affected = selected
        if let original, let range = VerseRange(json: original) { affected.formUnion(range.start...range.end) }
        guard affected.allSatisfy({ (state["nativeStudyCorrectionAt"][String($0)].string ?? "") < at }) else { return state }
        var result = state
        if action == .revised || action == .removeRevision {
            var history = state["reviewHistory"].array
            if let original {
                let matches = history.indices.filter { history[$0] == original }
                guard matches.count == 1 else { return state } // Never silently overwrite an edit from another device.
                history.remove(at: matches[0])
            } else if action == .removeRevision { return state }
            if action == .revised {
                guard selected.allSatisfy({ ["perfect", "review"].contains(state["knowledge"][String($0)].string ?? "") }),
                      !history.contains(where: { row in
                          row["date"].string == day && VerseRange(json: row).map { !selected.isDisjoint(with: $0.start...$0.end) } == true
                      }) else { return state }
                var event = original ?? .object(["category": .string("manual"), "grade": .string("perfect")])
                event = event.setting("id", .string(original?["id"].string ?? "manual-\(id.uuidString)"))
                    .setting("start", .number(Double(start))).setting("end", .number(Double(end)))
                    .setting("date", .string(day)).setting("completedAt", .string(at)).setting("correctedAt", .string(at))
                history.append(event)
            }
            result = result.setting("reviewHistory", .array(history))
            // Invalidate only affected progress rows. History remains the source of credits.
            var progress = result["studyProgress"].object
            for (key, row) in progress where row["mode"].string == "revision" && Self.overlaps(row, affected) { progress.removeValue(forKey: key) }
            result = result.setting("studyProgress", .object(progress))
            let cycle = state["reviewCycle"]
            if let cycleStart = cycle["startDate"].string {
                var completed = Set(cycle["completed"].array.compactMap(\.int))
                let currentEvent = original == nil || (original?["scheduledDate"].string ?? original?["date"].string ?? "") >= cycleStart
                if currentEvent {
                    completed.subtract(affected)
                    let corpus = Set(cycle["corpus"].array.compactMap(\.int))
                    for event in history where (event["scheduledDate"].string ?? event["date"].string ?? "") >= cycleStart {
                        if let range = VerseRange(json: event) { completed.formUnion(affected.intersection(range.start...range.end).intersection(corpus)) }
                    }
                    result = result.setting("reviewCycle", cycle.setting("completed", .array(completed.sorted().map { .number(Double($0)) })))
                }
            }
            if action == .removeRevision {
                // Supplemental revisions must become selectable again without changing difficult markers.
                var due = result["nativeManualReviewDue"]
                for verse in affected where ["perfect", "review"].contains(result["knowledge"][String(verse)].string ?? "") { due = due.setting(String(verse), .string(today)) }
                result = result.setting("nativeManualReviewDue", due)
            }
        } else {
            var changed = Set<Int>()
            for verse in start...end {
                if preserveKnown == true, action == .learned, ["perfect", "review"].contains(state["knowledge"][String(verse)].string ?? "") { continue }
                changed.insert(verse)
                let key = String(verse)
                if action == .unlearned {
                    for field in ["knowledge", "memorizedAt", "reviewConsolidations", "nativeManualReviewDue", "reviewPriorityDue"] {
                        var values = result[field].object; values.removeValue(forKey: key); result = result.setting(field, .object(values))
                    }
                } else {
                    if result["memorizedAt"][key].string != day {
                        var dates: [String: JSONValue] = [:]
                        for offset in [1, 3, 7] { if let due = ProgramProjection.addingDays(offset, to: day, timeZone: TimeZone(secondsFromGMT: 0)!) { dates[String(offset)] = .string(due) } }
                        result = result.setting("reviewConsolidations", result["reviewConsolidations"].setting(key, .object(["learnedAt": .string(day), "scheduledDates": .object(dates), "completed": .object([:])])))
                    }
                    result = result.setting("knowledge", result["knowledge"].setting(key, .string(action == .review ? "review" : "perfect")))
                        .setting("memorizedAt", result["memorizedAt"].setting(key, .string(day)))
                    if action == .review { result = result.setting("nativeManualReviewDue", result["nativeManualReviewDue"].setting(key, .string(today))) }
                }
            }
            var progress = result["studyProgress"].object
            for row in state["sessions"].array where row["status"].string == "done" && Self.overlaps(row, changed) {
                guard let sessionID = row["id"].string, progress["learning:\(sessionID)"] == nil else { continue }
                let date = row["completedDate"].string ?? row["completedAt"].string.map { String($0.prefix(10)) } ?? row["date"].string ?? ""
                progress["learning:\(sessionID)"] = row.setting("mode", .string("learning")).setting("validations", .array([row.setting("date", .string(date))]))
            }
            // Keep unaffected portions of old validations, replacing only the selected verses.
            for (key, row) in progress where row["mode"].string == "learning" && Self.overlaps(row, changed) {
                let validations = row["validations"].array.flatMap { Self.subtract(changed, from: $0) }
                if validations.isEmpty && key.hasPrefix("learning:verse-") { progress.removeValue(forKey: key) }
                else { progress[key] = row.setting("validations", .array(validations)) }
            }
            if action != .unlearned {
                var spans: [(Int, Int)] = []
                for verse in changed.sorted() {
                    if let last = spans.last, last.1 + 1 == verse { spans[spans.count - 1].1 = verse } else { spans.append((verse, verse)) }
                }
                var revisions = result["revisions"].array
                for (a, b) in spans {
                    let event: JSONValue = .object(["start": .number(Double(a)), "end": .number(Double(b)), "date": .string(day), "validatedAt": .string(at)])
                    let key = "correction-\(id.uuidString)-\(a)"
                    progress["learning:\(key)"] = .object(["id": .string(key), "mode": .string("learning"), "start": .number(Double(a)), "end": .number(Double(b)), "through": .number(Double(b)), "status": .string("completed"), "updatedAt": .string(at), "validations": .array([event])])
                    if let due = ProgramProjection.addingDays(1, to: day, timeZone: TimeZone(secondsFromGMT: 0)!) {
                        revisions.append(.object(["id": .string("r-\(key)"), "start": .number(Double(a)), "end": .number(Double(b)), "due": .string(due), "interval": .number(1), "streak": .number(0), "completedCount": .number(0)]))
                    }
                }
                result = result.setting("revisions", .array(revisions))
            }
            var sessions = result["sessions"].array
            for index in sessions.indices where Self.overlaps(sessions[index], changed) {
                let row = sessions[index]
                guard let range = VerseRange(json: row), let sessionID = row["id"].string else { continue }
                var through = range.start - 1
                for verse in range.start...range.end {
                    guard ["perfect", "review"].contains(result["knowledge"][String(verse)].string ?? "") else { break }; through = verse
                }
                let done = through == range.end
                sessions[index] = row.setting("status", .string(done ? "done" : through >= range.start ? "partial" : "todo"))
                    .setting("completedAt", done ? row["completedAt"].string.map(JSONValue.string) ?? .string(at) : .null)
                    .setting("completedDate", done ? .string(day) : .null)
                let key = "learning:\(sessionID)"
                var p = progress[key] ?? row.setting("id", .string(sessionID)).setting("mode", .string("learning"))
                p = p.setting("through", .number(Double(through))).setting("status", .string(done ? "completed" : "partial")).setting("updatedAt", .string(at))
                progress[key] = p
            }
            result = result.setting("studyProgress", .object(progress)).setting("sessions", .array(sessions))
            if action == .unlearned {
                result = result.setting("reviewCycle", result["reviewCycle"] == .null ? .null : result["reviewCycle"].setting("completed", .array(result["reviewCycle"]["completed"].array.filter { !selected.contains($0.int ?? 0) })))
            }
        }
        var audit = result["nativeStudyCorrections"].array
        audit.append(.object(["id": .string(id.uuidString), "at": .string(at), "action": .string(action.rawValue), "start": .number(Double(start)), "end": .number(Double(end)), "date": .string(day), "previousRevision": original ?? .null,
                              "previousKnowledge": .object(Dictionary(uniqueKeysWithValues: (start...end).map { (String($0), state["knowledge"][String($0)]) })),
                              "previousMemorizedAt": .object(Dictionary(uniqueKeysWithValues: (start...end).map { (String($0), state["memorizedAt"][String($0)]) }))]))
        var times = result["nativeStudyCorrectionAt"]
        for verse in affected { times = times.setting(String(verse), .string(at)) }
        return result.setting("nativeStudyCorrections", .array(audit)).setting("nativeStudyCorrectionAt", times)
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
    private static func overlaps(_ row: JSONValue, _ verses: Set<Int>) -> Bool { VerseRange(json: row).map { !verses.isDisjoint(with: $0.start...$0.end) } ?? false }
    private static func subtract(_ verses: Set<Int>, from row: JSONValue) -> [JSONValue] {
        guard let range = VerseRange(json: row) else { return [row] }
        var spans: [(Int, Int)] = []
        for verse in range.start...range.end where !verses.contains(verse) {
            if let last = spans.last, last.1 + 1 == verse { spans[spans.count - 1].1 = verse } else { spans.append((verse, verse)) }
        }
        return spans.map { row.setting("start", .number(Double($0.0))).setting("end", .number(Double($0.1))) }
    }
}
