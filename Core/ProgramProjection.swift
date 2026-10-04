import Foundation

struct QuranSessionContext: Identifiable, Hashable, Sendable {
    let id: String
    let mode: ReadingMode
    let range: VerseRange
    let scheduledDate: String
    var consolidationDay: Int? = nil
    var learnedAt: String? = nil
    var title: String {
        switch mode {
        case .classic: return "Lecture"
        case .learning: return "Apprentissage du jour"
        case .revision: return "Révision du jour"
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
        snapshot.state["sessions"].array.compactMap { row in
            guard ["todo", "pending", "partial", "partiallyCompleted"].contains(row["status"].string ?? ""),
                  let range = VerseRange(json: row) else { return nil }
            let date = home.scheduled(row)
            guard Self.addingDays(0, to: date, timeZone: timeZone) != nil else { return nil }
            return QuranSessionContext(id: row["id"].string ?? "learning-\(date)-\(range.start)-\(range.end)", mode: .learning, range: range, scheduledDate: date)
        }.sorted { ($0.scheduledDate, $0.range.start, $0.id) < ($1.scheduledDate, $1.range.start, $1.id) }
    }
    var todayLearning: QuranSessionContext? { learning.first { $0.scheduledDate == today } }
    var overdue: [QuranSessionContext] { learning.filter { $0.scheduledDate < today } }
    var upcoming: [QuranSessionContext] {
        let end = Self.addingDays(10, to: today, timeZone: timeZone) ?? today
        return learning.filter { $0.scheduledDate >= today && $0.scheduledDate <= end }
    }
    var revision: QuranSessionContext? {
        home.revision.map { QuranSessionContext(id: "revision-\(today)-\($0.start)-\($0.end)", mode: .revision, range: $0, scheduledDate: today) }
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
