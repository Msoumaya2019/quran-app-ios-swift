import Foundation

/// One queue, ordered like the existing app: partial work, recent, priority, habitual.
struct ReviewQueueProjection {
    let program: ProgramProjection
    private var state: JSONValue { program.snapshot.state }
    private let catalog = QuranCatalog()
    private var reviewed: Set<Int> {
        Set(state["reviewHistory"].array.filter { $0["date"].string == program.today }.flatMap { row -> [Int] in
            guard let range = VerseRange(json: row) else { return [] }; return Array(range.start...range.end)
        })
    }
    private func known(_ id: Int) -> Bool { ["perfect", "review"].contains(state["knowledge"][String(id)].string ?? "") }
    private func groups(_ ids: [Int]) -> [VerseRange] {
        var ranges: [VerseRange] = []
        for id in Set(ids).sorted() {
            if let last = ranges.last, last.end + 1 == id, catalog.surah(for: last.start)?.number == catalog.surah(for: id)?.number,
               let merged = VerseRange(json: .object(["start": .number(Double(last.start)), "end": .number(Double(id))])) { ranges[ranges.count - 1] = merged }
            else if let range = VerseRange(json: .object(["start": .number(Double(id)), "end": .number(Double(id))])) { ranges.append(range) }
        }
        return ranges
    }
    var tasks: [QuranSessionContext] {
        guard state["reviewSettings"]["enabled"].bool != false else { return [] }
        let done = reviewed
        var priorityByDate: [String: [Int]] = [:]
        for id in 1...6236 where known(id) && (DifficultyChange.isDifficult(state, verseID: id) || state["nativeManualReviewDue"][String(id)].string != nil) && !done.contains(id) {
            var dates = [state["nativeManualReviewDue"][String(id)].string].compactMap { $0 }
            if DifficultyChange.isDifficult(state, verseID: id) { dates.append(state["reviewPriorityDue"][String(id)].string ?? program.today) }
            let date = dates.min() ?? program.today
            if date <= program.today, ProgramProjection.addingDays(0, to: date, timeZone: program.timeZone) != nil { priorityByDate[date, default: []].append(id) }
        }
        let priority = priorityByDate.keys.sorted().flatMap { day in groups(priorityByDate[day]!).map {
            QuranSessionContext(id: "native-priority-\(day)-\($0.start)-\($0.end)", mode: .revision, range: $0, scheduledDate: day, revisionCategory: "priority")
        } }
        let recent = program.consolidations.filter { $0.scheduledDate <= program.today }.flatMap { task in
            groups(Array(task.range.start...task.range.end).filter { !done.contains($0) }).map {
                QuranSessionContext(id: "native-recent-\(task.learnedAt ?? "")-\(task.consolidationDay ?? 1)-\($0.start)-\($0.end)", mode: .revision, range: $0, scheduledDate: task.scheduledDate,
                    consolidationDay: task.consolidationDay, learnedAt: task.learnedAt, revisionCategory: "recent")
            }
        }
        var partials: [QuranSessionContext] = []
        for row in state["studyProgress"].object.sorted(by: { $0.key < $1.key }).map(\.value) {
            guard row["mode"].string == "revision", row["status"].string == "partial", let category = row["category"].string,
                  ["priority", "recent"].contains(category), let range = VerseRange(json: row), let through = row["through"].int,
                  through >= range.start - 1, through < range.end, let id = row["id"].string else { continue }
            let candidates = category == "priority" ? priority : recent
            guard let current = candidates.first(where: { $0.range.start <= through + 1 && $0.range.end >= range.end }) else { continue }
            partials.append(QuranSessionContext(id: id, mode: .revision, range: range, scheduledDate: row["scheduledDate"].string ?? current.scheduledDate,
                consolidationDay: current.consolidationDay, learnedAt: current.learnedAt, revisionCategory: category))
        }
        if let habitual = program.habitualRevision, RevisionValidation.completedCount(context: habitual, state: state) > 0 { partials.append(habitual) }
        var seen = Set<Int>(), queue: [QuranSessionContext] = []
        for task in partials + recent + priority + (program.habitualRevision.map { [$0] } ?? []) {
            let first = task.range.start + RevisionValidation.completedCount(context: task, state: state)
            guard first <= task.range.end else { continue }
            let pending = Array(first...task.range.end).filter { known($0) && !done.contains($0) && !seen.contains($0) }
            guard !pending.isEmpty else { continue }
            seen.formUnion(pending)
            if pending.count == task.range.end - first + 1 { queue.append(task) }
            else {
                for range in groups(pending) {
                    var fragment = task
                    // New fragment identity avoids crediting holes in a partially overlapping range.
                    fragment = QuranSessionContext(id: "\(task.id)-part-\(range.start)-\(range.end)", mode: task.mode, range: range, scheduledDate: task.scheduledDate,
                        consolidationDay: task.consolidationDay, learnedAt: task.learnedAt, revisionCategory: task.revisionCategory,
                        revisionCycleIndex: task.revisionCycleIndex, revisionCycleStart: task.revisionCycleStart)
                    queue.append(fragment)
                }
            }
        }
        return queue
    }
}
