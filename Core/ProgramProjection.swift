import Foundation

struct QuranSessionContext: Identifiable, Hashable, Sendable {
    let id: String
    let mode: ReadingMode
    let range: VerseRange
    let scheduledDate: String
    var learningSessionIDs: [String]? = nil
    var consolidationDay: Int? = nil
    var learnedAt: String? = nil
    var revisionCategory: String? = nil
    var revisionCycleIndex: Int? = nil
    var revisionCycleStart: String? = nil
    var title: String {
        switch mode {
        case .classic: return "Lecture"
        case .learning: return "Apprentissage du jour"
        case .revision: return revisionCategory == "priority" ? "Révision prioritaire" : revisionCategory == "recent" ? "Révision récente · J+\(consolidationDay ?? 1)" : "Révision du jour"
        case .consolidation: return "Consolidation · J+\(consolidationDay ?? 1)"
        }
    }
}

struct ProgramProjection {
    let snapshot: HomeSnapshot
    let now: Date
    let timeZone: TimeZone
    init(snapshot: HomeSnapshot, now: Date = .now, timeZone: TimeZone = .current) {
        self.snapshot = snapshot; self.now = now; self.timeZone = timeZone
    }
    var today: String { LocalCalendar.key(now, timeZone: timeZone) }
    private var home: HomeProjection { HomeProjection(snapshot: snapshot, now: now, timeZone: timeZone) }
    static func addingDays(_ number: Int, to key: String, timeZone: TimeZone) -> String? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        formatter.calendar = calendar; formatter.timeZone = timeZone; formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let date = formatter.date(from: key), formatter.string(from: date) == key,
              let result = calendar.date(byAdding: .day, value: number, to: date) else { return nil }
        return LocalCalendar.key(result, timeZone: timeZone)
    }
    var learning: [QuranSessionContext] {
        let tasks: [QuranSessionContext] = snapshot.state["sessions"].array.compactMap { row in
            guard ["todo", "pending", "partial", "partiallyCompleted"].contains(row["status"].string ?? ""),
                  let range = VerseRange(json: row) else { return nil }
            let date = home.scheduled(row)
            guard Self.addingDays(0, to: date, timeZone: timeZone) != nil else { return nil }
            return QuranSessionContext(id: row["id"].string ?? "learning-\(date)-\(range.start)-\(range.end)", mode: .learning, range: range, scheduledDate: date)
        }.sorted { ($0.scheduledDate, $0.range.start, $0.id) < ($1.scheduledDate, $1.range.start, $1.id) }
        let units = Set(["page", "page2", "halfPage", "quarter", "halfHizb", "hizb"])
        func unit(_ task: QuranSessionContext) -> String {
            snapshot.state["sessions"].array.first { $0["id"].string == task.id }?["unit"].string ?? snapshot.state["pace"].string ?? ""
        }
        var grouped: [QuranSessionContext] = []
        for task in tasks {
            if let last = grouped.last, units.contains(unit(task)), unit(last) == unit(task),
               last.scheduledDate == task.scheduledDate, last.range.end + 1 == task.range.start,
               let range = VerseRange(json: .object(["start": .number(Double(last.range.start)), "end": .number(Double(task.range.end))])) {
                grouped[grouped.count - 1] = QuranSessionContext(id: last.id, mode: .learning, range: range,
                    scheduledDate: last.scheduledDate, learningSessionIDs: (last.learningSessionIDs ?? [last.id]) + [task.id])
            } else { grouped.append(task) }
        }
        return grouped
    }
    var todayLearning: QuranSessionContext? { learning.first { $0.scheduledDate == today } }
    var overdue: [QuranSessionContext] { learning.filter { $0.scheduledDate < today } }
    var upcoming: [QuranSessionContext] {
        let end = Self.addingDays(10, to: today, timeZone: timeZone) ?? today
        return learning.filter { $0.scheduledDate >= today && $0.scheduledDate <= end }
    }
    var revision: QuranSessionContext? { ReviewQueueProjection(program: self).tasks.first }
    var habitualRevision: QuranSessionContext? {
        let state = snapshot.state, cycle = state["reviewCycle"]
        guard state["reviewSettings"]["enabled"].bool != false, let index = cycle["index"].int,
              let startDate = cycle["startDate"].string else { return nil }
        // A native task is scoped to its cycle: identical ranges in later cycles remain playable.
        let prefix = "native-revision-\(index)-\(startDate)-"
        if let entry = state["studyProgress"].object.sorted(by: { $0.key < $1.key }).first(where: {
            let row = $0.value
            guard row["mode"].string == "revision", row["status"].string == "partial",
                  let range = VerseRange(json: row), let through = row["through"].int, through >= range.start - 1, through < range.end else { return false }
            let id = row["id"].string ?? ""
            let belongs = id.hasPrefix(prefix) || (!id.hasPrefix("native-revision-") && (row["category"].string ?? "habitual") == "habitual"
                && String((row["updatedAt"].string ?? "").prefix(10)) >= startDate
                && cycle["days"].array.contains { Set($0.array.compactMap(\.int)).isSuperset(of: Set(range.start...range.end)) })
            guard belongs else { return false }
            let corpus = Set(cycle["corpus"].array.compactMap(\.int))
            return ((through + 1)...range.end).allSatisfy { corpus.contains($0) && ["perfect", "review"].contains(state["knowledge"][String($0)].string ?? "") }
        }), let range = VerseRange(json: entry.value) {
            let originalDay = cycle["days"].array.firstIndex { Set($0.array.compactMap(\.int)).isSuperset(of: Set(range.start...range.end)) }
            let planned = entry.value["scheduledDate"].string ?? originalDay.flatMap { Self.addingDays($0, to: startDate, timeZone: timeZone) } ?? today
            return QuranSessionContext(id: entry.value["id"].string ?? "", mode: .revision, range: range,
                scheduledDate: planned, revisionCycleIndex: index, revisionCycleStart: startDate)
        }
        guard let assigned = cycle["assignments"][today].int, assigned >= 0,
              cycle["days"].array.indices.contains(assigned),
              let due = Self.addingDays(assigned, to: startDate, timeZone: timeZone) else { return nil }
        var reviewed = Set<Int>()
        for event in state["reviewHistory"].array where event["date"].string == today {
            if let range = VerseRange(json: event) { reviewed.formUnion(range.start...range.end) }
        }
        let completed = Set(cycle["completed"].array.compactMap(\.int))
        let ids = cycle["days"].array[assigned].array.compactMap(\.int).filter {
            (1...6236).contains($0) && !completed.contains($0) && !reviewed.contains($0) && ["perfect", "review"].contains(state["knowledge"][String($0)].string ?? "")
        }.sorted()
        guard let first = ids.first else { return nil }
        var end = first
        for id in ids.dropFirst() {
            guard id == end + 1 else { break }
            end = id
        }
        guard let range = VerseRange(json: .object(["start": .number(Double(first)), "end": .number(Double(end))])) else { return nil }
        return QuranSessionContext(id: "\(prefix)\(first)-\(end)", mode: .revision, range: range, scheduledDate: due,
            revisionCycleIndex: index, revisionCycleStart: startDate)
    }
    var consolidations: [QuranSessionContext] {
        let state = snapshot.state
        var results: [QuranSessionContext] = []
        for key in state["reviewConsolidations"].object.keys.sorted(by: { (Int($0) ?? 0) < (Int($1) ?? 0) }) {
            guard let verse = Int(key), (1...6236).contains(verse),
                  ["perfect", "review"].contains(state["knowledge"][key].string ?? "") else { continue }
            let row = state["reviewConsolidations"][key]
            guard let learned = row["learnedAt"].string, learned == state["memorizedAt"][key].string,
                  row["completed"]["7"] == .null else { continue }
            guard let offset = [1, 3, 7].first(where: { row["completed"][String($0)] == .null }),
                  let due = row["scheduledDates"][String(offset)].string ?? Self.addingDays(offset, to: learned, timeZone: timeZone),
                  let range = VerseRange(json: .object(["start": .number(Double(verse)), "end": .number(Double(verse))])) else { continue }
            results.append(QuranSessionContext(id: "consolidation-\(verse)-\(learned)-\(offset)", mode: .consolidation, range: range, scheduledDate: due, consolidationDay: offset, learnedAt: learned))
        }
        let catalog = QuranCatalog()
        var grouped: [QuranSessionContext] = []
        for task in results.sorted(by: { ($0.scheduledDate, $0.range.start) < ($1.scheduledDate, $1.range.start) }) {
            if let last = grouped.last, last.range.end + 1 == task.range.start,
               last.scheduledDate == task.scheduledDate, last.learnedAt == task.learnedAt, last.consolidationDay == task.consolidationDay,
               catalog.surah(for: last.range.start)?.number == catalog.surah(for: task.range.start)?.number,
               let range = VerseRange(json: .object(["start": .number(Double(last.range.start)), "end": .number(Double(task.range.end))])) {
                grouped[grouped.count - 1] = QuranSessionContext(id: last.id, mode: .consolidation, range: range, scheduledDate: last.scheduledDate, consolidationDay: last.consolidationDay, learnedAt: last.learnedAt)
            } else { grouped.append(task) }
        }
        return grouped
    }
    func dateLabel(_ key: String) -> String {
        if key == today { return "Aujourd’hui" }
        if key == Self.addingDays(1, to: today, timeZone: timeZone) { return "Demain" }
        let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX"); parser.timeZone = timeZone; parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: key) else { return key }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "fr_FR"); formatter.timeZone = timeZone; formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date).capitalized
    }
}
