import Foundation

/// Replays against the latest shared state, crediting only the not-yet-validated prefix.
struct LearningValidation: Codable, Sendable {
    let sessionID: String
    let start: Int
    let end: Int
    let through: Int
    let scheduledDate: String
    let completedDate: String
    let completedAt: String
    let source: String
    let page: Int
    init?(context: QuranSessionContext, through: Int, source: String, catalog: QuranCatalog, now: Date = .now, timeZone: TimeZone = .current) {
        guard context.mode == .learning, (context.range.start...context.range.end).contains(through) else { return nil }
        sessionID = context.id; start = context.range.start; end = context.range.end; self.through = through
        scheduledDate = context.scheduledDate; completedDate = LocalCalendar.key(now, timeZone: timeZone)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        completedAt = formatter.string(from: now); self.source = source
        let selected = QuranSource.available.first { $0.id == source } ?? .medina
        page = QuranSourceMapping.page(source: selected, verseID: through, catalog: catalog)
    }
    func applying(to state: JSONValue) -> JSONValue {
        guard (1...6236).contains(start), (start...6236).contains(end), (start...end).contains(through) else { return state }
        var sessions = state["sessions"].array
        guard let index = sessions.firstIndex(where: { $0["id"].string == sessionID }) else { return state }
        let session = sessions[index]
        guard session["start"].int == start, session["end"].int == end,
              (session["scheduledDate"].string ?? session["date"].string) == scheduledDate,
              ["todo", "pending", "partial", "partiallyCompleted"].contains(session["status"].string ?? "") else { return state }
        let progressKey = "learning:\(sessionID)", previous = state["studyProgress"][progressKey]
        guard previous == .null || (previous["start"].int == start && previous["end"].int == end) else { return state }
        let first = max(start, (previous["through"].int ?? (start - 1)) + 1)
        guard first <= through else { return state }
        var knowledge = state["knowledge"], memorized = state["memorizedAt"], consolidations = state["reviewConsolidations"]
        for verse in first...through {
            let key = String(verse)
            if !["perfect", "review"].contains(knowledge[key].string ?? ""), memorized[key] == .null {
                memorized = memorized.setting(key, .string(completedDate))
                var dates: [String: JSONValue] = [:]
                for offset in [1, 3, 7] {
                    if let due = ProgramProjection.addingDays(offset, to: completedDate, timeZone: TimeZone(secondsFromGMT: 0)!) { dates[String(offset)] = .string(due) }
                }
                consolidations = consolidations.setting(key, .object(["learnedAt": .string(completedDate), "scheduledDates": .object(dates), "completed": .object([:])]))
            }
            knowledge = knowledge.setting(key, .string("perfect"))
        }
        var revisions = state["revisions"].array
        let revisionID = "r-\(first)-\(through)"
        if !revisions.contains(where: { $0["id"].string == revisionID }),
           let due = ProgramProjection.addingDays(1, to: completedDate, timeZone: TimeZone(secondsFromGMT: 0)!) {
            revisions.append(.object(["id": .string(revisionID), "start": .number(Double(first)), "end": .number(Double(through)), "due": .string(due), "interval": .number(1), "streak": .number(0), "completedCount": .number(0)]))
        }
        let completed = through == end
        if completed {
            sessions[index] = session.setting("status", .string("done")).setting("completedAt", .string(completedAt)).setting("completedDate", .string(completedDate))
        }
        var validations = previous["validations"].array
        validations.append(.object(["start": .number(Double(first)), "end": .number(Double(through)), "date": .string(completedDate), "validatedAt": .string(completedAt)]))
        let progress: JSONValue = .object(["id": .string(sessionID), "mode": .string("learning"), "start": .number(Double(start)), "end": .number(Double(end)), "through": .number(Double(through)), "page": .number(Double(page)), "source": .string(source), "updatedAt": .string(completedAt), "status": .string(completed ? "completed" : "partial"), "validations": .array(validations)])
        return state.setting("sessions", .array(sessions)).setting("knowledge", knowledge).setting("memorizedAt", memorized)
            .setting("reviewConsolidations", consolidations).setting("revisions", .array(revisions))
            .setting("studyProgress", state["studyProgress"].setting(progressKey, progress))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", completedAt)))
    }
    static func completedCount(context: QuranSessionContext, state: JSONValue) -> Int {
        let through = state["studyProgress"]["learning:\(context.id)"]["through"].int ?? (context.range.start - 1)
        return min(context.range.count, max(0, through - context.range.start + 1))
    }
}
