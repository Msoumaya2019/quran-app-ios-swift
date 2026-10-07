import Foundation

extension RevisionValidation {
    /// Recent and priority work uses the same progress/history and grading as habitual work.
    func applyingSupplemental(to state: JSONValue) -> JSONValue {
        guard let category, ["priority", "recent"].contains(category) else { return state }
        let zone = TimeZone(secondsFromGMT: 0)!
        guard ProgramProjection.addingDays(0, to: scheduledDate, timeZone: zone) != nil else { return state }
        let key = "revision:\(taskID)", previous = state["studyProgress"][key]
        guard previous == .null || (previous["start"].int == start && previous["end"].int == end && previous["category"].string == category) else { return state }
        let first = max(start, (previous["through"].int ?? (start - 1)) + 1)
        guard first <= through else { return state }
        var history = state["reviewHistory"].array
        let reviewed = Set(history.filter { $0["date"].string == completedDate }.flatMap { row -> [Int] in
            guard let range = VerseRange(json: row) else { return [] }; return Array(range.start...range.end)
        })
        let newIDs = Array(first...through).filter { !reviewed.contains($0) }
        for verse in first...through {
            let id = String(verse)
            guard ["perfect", "review"].contains(state["knowledge"][id].string ?? ""),
                  (state["memorizedAt"][id].string ?? "") == learnedAnchors[id] else { return state }
            if reviewed.contains(verse) { continue }
            if category == "priority" {
                guard (DifficultyChange.isDifficult(state, verseID: verse) || state["nativeManualReviewDue"][id].string != nil),
                      (state["reviewPriorityDue"][id].string ?? "") == priorityDueAnchors?[id],
                      (state["nativeDifficultyUpdatedAt"][id].string ?? "") <= completedAt else { return state }
            } else {
                let row = state["reviewConsolidations"][id]
                guard let offset = consolidationOffset, [1, 3, 7].first(where: { row["completed"][String($0)] == .null }) == offset,
                      row["learnedAt"].string == learnedAnchors[id], let learned = row["learnedAt"].string,
                      (row["scheduledDates"][String(offset)].string ?? ProgramProjection.addingDays(offset, to: learned, timeZone: zone)) == scheduledDate else { return state }
            }
        }
        var markers = state["difficultyMarkers"], due = state["reviewPriorityDue"], difficultyHistory = state["difficultyHistory"].array
        var consolidations = state["reviewConsolidations"], consolidationHistory = state["consolidationHistory"].array
        let cycle = state["reviewCycle"]
        var completed = Set(cycle["completed"].array.compactMap(\.int))
        let assignedIndex = cycle["assignments"][completedDate].int ?? -1
        let assigned = cycle["days"].array.indices.contains(assignedIndex) ? Set(cycle["days"].array[assignedIndex].array.compactMap(\.int)) : []
        for verse in newIDs {
            let id = String(verse)
            if assigned.contains(verse) { completed.insert(verse) }
            let hasLaterReview = history.contains { event in
                guard let range = VerseRange(json: event) else { return false }
                return (range.start...range.end).contains(verse) && (event["completedAt"].string ?? event["date"].string ?? "") > completedAt
            }
            if !hasLaterReview && (state["nativeDifficultyUpdatedAt"][id].string ?? "") <= completedAt {
                let marker = markers[id]
                if grade != .perfect {
                    if marker["user"] == .null {
                        markers = markers.setting(id, marker.setting("user", .object(["createdAt": .string(completedDate)])))
                        difficultyHistory.append(.object(["verseId": .number(Double(verse)), "date": .string(completedDate), "origin": .string("user"), "action": .string("marked")]))
                    }
                    if let next = ProgramProjection.addingDays(grade == .rework ? 1 : 2, to: completedDate, timeZone: zone) { due = due.setting(id, .string(next)) }
                } else if marker["user"] != .null || marker["admin"] != .null {
                    if let next = ProgramProjection.addingDays(RevisionPreferences(state: state).cycleDays, to: completedDate, timeZone: zone) { due = due.setting(id, .string(next)) }
                } else { var fields = due.object; fields.removeValue(forKey: id); due = .object(fields) }
            }
            let row = consolidations[id]
            if let learned = row["learnedAt"].string, learned == state["memorizedAt"][id].string,
               let offset = [1, 3, 7].first(where: { row["completed"][String($0)] == .null }),
               let planned = row["scheduledDates"][String(offset)].string ?? ProgramProjection.addingDays(offset, to: learned, timeZone: zone), (category == "recent" && offset == consolidationOffset) || planned <= completedDate {
                consolidations = consolidations.setting(id, row.setting("completed", row["completed"].setting(String(offset), .string(completedDate)))
                    .setting("completedAt", row["completedAt"].setting(String(offset), .string(completedAt))))
                let eventID = "\(verse)-\(learned)-\(offset)"
                if !consolidationHistory.contains(where: { $0["id"].string == eventID }) {
                    consolidationHistory.append(.object(["id": .string(eventID), "verseId": .number(Double(verse)), "offset": .number(Double(offset)), "learnedAt": .string(learned), "scheduledDate": .string(planned), "completedAt": .string(completedAt)]))
                }
            }
        }
        var spans: [(Int, Int)] = []
        for verse in newIDs {
            if let last = spans.last, last.1 + 1 == verse { spans[spans.count - 1].1 = verse } else { spans.append((verse, verse)) }
        }
        for (a, b) in spans { history.append(.object(["id": .string("\(eventID)-\(a)-\(b)"), "date": .string(completedDate), "scheduledDate": .string(scheduledDate), "completedAt": .string(completedAt), "start": .number(Double(a)), "end": .number(Double(b)), "category": .string(category), "grade": .string(grade.rawValue)])) }
        var validations = previous["validations"].array
        validations.append(.object(["start": .number(Double(first)), "end": .number(Double(through)), "date": .string(completedDate), "validatedAt": .string(completedAt)]))
        var progress: JSONValue = .object(["id": .string(taskID), "mode": .string("revision"), "category": .string(category), "start": .number(Double(start)), "end": .number(Double(end)), "through": .number(Double(through)), "page": .number(Double(page)), "source": .string(source), "updatedAt": .string(completedAt), "scheduledDate": .string(scheduledDate), "status": .string(through == end ? "completed" : "partial"), "validations": .array(validations)])
        if let consolidationOffset { progress = progress.setting("consolidationDay", .number(Double(consolidationOffset))) }
        var result = state
        var requested = state["nativeManualReviewDue"]
        for verse in newIDs where (state["nativeVerseActionAt"]["nextRevision"][String(verse)].string ?? "") <= completedAt { requested = requested.setting(String(verse), .null) }
        result = result.setting("nativeManualReviewDue", requested)
        if cycle != .null { result = result.setting("reviewCycle", cycle.setting("completed", .array(completed.sorted().map { .number(Double($0)) }))) }
        return result.setting("reviewHistory", .array(history)).setting("difficultyMarkers", markers).setting("reviewPriorityDue", due)
            .setting("difficultyHistory", .array(difficultyHistory)).setting("reviewConsolidations", consolidations).setting("consolidationHistory", .array(consolidationHistory))
            .setting("studyProgress", state["studyProgress"].setting(key, progress)).setting("updatedAt", .string(max(state["updatedAt"].string ?? "", completedAt)))
    }
}
