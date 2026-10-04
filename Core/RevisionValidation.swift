import Foundation

enum RevisionGrade: String, Codable, CaseIterable, Hashable {
    case perfect, hesitant, rework
    var title: String {
        switch self { case .perfect: return "Bien maîtrisé"; case .hesitant: return "Avec hésitations"; case .rework: return "À retravailler" }
    }
}

struct RevisionValidation: Codable, Sendable {
    let eventID: String
    let taskID: String
    let start: Int
    let end: Int
    let through: Int
    let scheduledDate: String
    let completedDate: String
    let completedAt: String
    let cycleIndex: Int
    let cycleStart: String
    let grade: RevisionGrade
    let source: String
    let page: Int
    let learnedAnchors: [String: String]
    init?(context: QuranSessionContext, through: Int, grade: RevisionGrade, state: JSONValue, source: QuranSource, catalog: QuranCatalog, now: Date = .now, timeZone: TimeZone = .current) {
        guard context.mode == .revision, let index = context.revisionCycleIndex, let cycleStart = context.revisionCycleStart,
              (context.range.start...context.range.end).contains(through) else { return nil }
        eventID = UUID().uuidString; taskID = context.id; start = context.range.start; end = context.range.end; self.through = through
        scheduledDate = context.scheduledDate; completedDate = LocalCalendar.key(now, timeZone: timeZone)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        completedAt = formatter.string(from: now); cycleIndex = index; self.cycleStart = cycleStart; self.grade = grade
        self.source = source.id; page = QuranSourceMapping.page(source: source, verseID: through, catalog: catalog)
        learnedAnchors = Dictionary(uniqueKeysWithValues: (start...end).map { (String($0), state["memorizedAt"][String($0)].string ?? "") })
    }
    func applying(to state: JSONValue) -> JSONValue {
        guard (1...6236).contains(start), (start...6236).contains(end), (start...end).contains(through),
              state["reviewSettings"]["enabled"].bool != false,
              state["reviewCycle"]["index"].int == cycleIndex, state["reviewCycle"]["startDate"].string == cycleStart else { return state }
        let key = "revision:\(taskID)", previous = state["studyProgress"][key]
        guard previous == .null || (previous["start"].int == start && previous["end"].int == end) else { return state }
        let first = max(start, (previous["through"].int ?? (start - 1)) + 1)
        guard first <= through else { return state }
        let corpus = Set(state["reviewCycle"]["corpus"].array.compactMap(\.int))
        let zone = TimeZone(secondsFromGMT: 0)!
        guard let planned = state["reviewCycle"]["days"].array.enumerated().first(where: {
            ProgramProjection.addingDays($0.offset, to: cycleStart, timeZone: zone) == scheduledDate
        }), Set(planned.element.array.compactMap(\.int)).isSuperset(of: Set(first...through)) else { return state }
        for verse in first...through {
            let id = String(verse)
            guard corpus.contains(verse), ["perfect", "review"].contains(state["knowledge"][id].string ?? ""),
                  (state["memorizedAt"][id].string ?? "") == learnedAnchors[id] else { return state }
        }
        var history = state["reviewHistory"].array
        var reviewed = Set<Int>()
        for event in history where event["date"].string == completedDate {
            if let range = VerseRange(json: event) { reviewed.formUnion(range.start...range.end) }
        }
        let newIDs = (first...through).filter { !reviewed.contains($0) }
        var markers = state["difficultyMarkers"], due = state["reviewPriorityDue"], difficultyHistory = state["difficultyHistory"].array
        var completed = Set(state["reviewCycle"]["completed"].array.compactMap(\.int))
        var consolidations = state["reviewConsolidations"]
        let cycleDays = state["reviewSettings"]["cycleDays"].int ?? 7
        completed.formUnion(first...through)
        for verse in newIDs {
            let id = String(verse); completed.insert(verse)
            let marker = markers[id]
            if grade != .perfect {
                if marker["user"] == .null {
                    markers = markers.setting(id, marker.setting("user", .object(["createdAt": .string(completedDate)])))
                    difficultyHistory.append(.object(["verseId": .number(Double(verse)), "date": .string(completedDate), "origin": .string("user"), "action": .string("marked")]))
                }
                if let next = ProgramProjection.addingDays(grade == .rework ? 1 : 2, to: completedDate, timeZone: zone) { due = due.setting(id, .string(next)) }
            } else if marker["user"] != .null || marker["admin"] != .null {
                if let next = ProgramProjection.addingDays(cycleDays, to: completedDate, timeZone: zone) { due = due.setting(id, .string(next)) }
            } else { var fields = due.object; fields.removeValue(forKey: id); due = .object(fields) }
            let row = consolidations[id]
            if row["learnedAt"].string == state["memorizedAt"][id].string,
               let learned = row["learnedAt"].string,
               let offset = [1, 3, 7].first(where: { row["completed"][String($0)] == .null }),
               let planned = row["scheduledDates"][String(offset)].string ?? ProgramProjection.addingDays(offset, to: learned, timeZone: zone), planned <= completedDate {
                consolidations = consolidations.setting(id, row.setting("completed", row["completed"].setting(String(offset), .string(completedDate)))
                    .setting("completedAt", row["completedAt"].setting(String(offset), .string(completedAt))))
            }
        }
        // Record only new contiguous spans, never verses already credited by another device.
        var spans: [(Int, Int)] = []
        for verse in newIDs {
            if let last = spans.last, last.1 + 1 == verse { spans[spans.count - 1].1 = verse } else { spans.append((verse, verse)) }
        }
        for (a, b) in spans {
            history.append(.object(["id": .string("\(eventID)-\(a)-\(b)"), "date": .string(completedDate), "scheduledDate": .string(scheduledDate), "completedAt": .string(completedAt), "start": .number(Double(a)), "end": .number(Double(b)), "category": .string("habitual"), "grade": .string(grade.rawValue)]))
        }
        var validations = previous["validations"].array
        validations.append(.object(["start": .number(Double(first)), "end": .number(Double(through)), "date": .string(completedDate), "validatedAt": .string(completedAt)]))
        let progress: JSONValue = .object(["id": .string(taskID), "mode": .string("revision"), "category": .string("habitual"), "start": .number(Double(start)), "end": .number(Double(end)), "through": .number(Double(through)), "page": .number(Double(page)), "source": .string(source), "updatedAt": .string(completedAt), "scheduledDate": .string(scheduledDate), "status": .string(through == end ? "completed" : "partial"), "validations": .array(validations)])
        return state.setting("reviewCycle", state["reviewCycle"].setting("completed", .array(completed.sorted().map { .number(Double($0)) })))
            .setting("reviewHistory", .array(history)).setting("difficultyMarkers", markers).setting("reviewPriorityDue", due)
            .setting("difficultyHistory", .array(difficultyHistory)).setting("reviewConsolidations", consolidations)
            .setting("studyProgress", state["studyProgress"].setting(key, progress)).setting("updatedAt", .string(max(state["updatedAt"].string ?? "", completedAt)))
    }
    static func completedCount(context: QuranSessionContext, state: JSONValue) -> Int {
        let through = state["studyProgress"]["revision:\(context.id)"]["through"].int ?? (context.range.start - 1)
        return min(context.range.count, max(0, through - context.range.start + 1))
    }
}
