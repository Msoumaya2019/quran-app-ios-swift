import Foundation

struct Surah: Codable, Sendable {
    let number: Int
    let name: String
    let arabic: String
    let start: Int
    let end: Int
    let count: Int
    let meaning: String
    let isMeccan: Bool
}
struct QuranMetadata: Codable {
    let surahs: [Surah]
    let juzs: [QuranDivision]
    let quarters: [QuranDivision]
}
struct QuranDivision: Codable, Identifiable, Sendable {
    let number: Int
    let start: Int
    let end: Int
    var id: Int { number }
}
struct QuranPage: Codable {
    let page: Int
    let first: [Int]
    let last: [Int]
}
struct QuranCatalog: Sendable {
    let surahs: [Surah]
    let juzs: [QuranDivision]
    let hizbs: [QuranDivision]
    let quarters: [QuranDivision]
    let pageStarts: [(Int, Int)]
    init(bundle: Bundle = .main) {
        let meta = bundle.url(forResource: "quran-meta", withExtension: "json")
        let metadata = meta.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(QuranMetadata.self, from: $0) }
        let surahs = metadata?.surahs ?? []
        self.surahs = surahs
        juzs = metadata?.juzs ?? []
        let quarters = metadata?.quarters ?? []
        self.quarters = quarters
        hizbs = stride(from: 0, to: quarters.count, by: 4).compactMap { offset in
            guard offset + 3 < quarters.count else { return nil }
            return QuranDivision(number: offset / 4 + 1, start: quarters[offset].start, end: quarters[offset + 3].end)
        }
        let pages = bundle.url(forResource: "quran-pages", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([QuranPage].self, from: $0) } ?? []
        pageStarts = pages.compactMap { p in
            guard p.first.count == 2, let s = surahs.first(where: { $0.number == p.first[0] }) else { return nil }
            return (p.page, s.start + p.first[1] - 1)
        }
    }
    func surah(for id: Int) -> Surah? { surahs.first { $0.start <= id && id <= $0.end } }
    func page(for id: Int) -> Int { pageStarts.last(where: { $0.1 <= id })?.0 ?? 1 }
    func reference(_ range: VerseRange?) -> String {
        guard let r = range, let s = surah(for: r.start), let e = surah(for: r.end) else { return "Aucune séance prévue" }
        let a = r.start - s.start + 1, b = r.end - e.start + 1
        return s.number == e.number ? "\(s.name) \(a)–\(b)" : "\(s.name) \(a) → \(e.name) \(b)"
    }
}
struct WeekProgress: Equatable {
    let start: String
    let end: String
    let done: Int
    let total: Int
    var ratio: Double { total > 0 ? Double(done) / Double(total) : 0 }
}
enum LocalCalendar {
    static func key(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = timeZone; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func week(now: Date, timeZone: TimeZone = .current) -> (String, String) {
        var c = Calendar(identifier: .gregorian); c.timeZone = timeZone
        let day = c.startOfDay(for: now), offset = (c.component(.weekday, from: day) + 5) % 7
        let start = c.date(byAdding: .day, value: -offset, to: day)!
        return (key(start, timeZone: timeZone), key(c.date(byAdding: .day, value: 6, to: start)!, timeZone: timeZone))
    }
}
struct HomeProjection {
    let snapshot: HomeSnapshot
    let now: Date
    let timeZone: TimeZone
    init(snapshot: HomeSnapshot, now: Date = .now, timeZone: TimeZone = .current) { self.snapshot = snapshot; self.now = now; self.timeZone = timeZone }
    var state: JSONValue { snapshot.state }
    var today: String { LocalCalendar.key(now, timeZone: timeZone) }
    var name: String { state["profile"]["firstName"].string ?? snapshot.displayName ?? "Bienvenue" }
    var readID: Int { min(6236, max(1, state["lastRead"]["verseId"].int ?? learning?["start"].int ?? state["goal"]["ranges"].array.first?["start"].int ?? 1)) }
    var learning: JSONValue? {
        guard let task = ProgramProjection(snapshot: snapshot, now: now, timeZone: timeZone).todayLearning,
              let row = state["sessions"].array.first(where: { $0["id"].string == task.id }) else { return nil }
        return row.setting("start", .number(Double(task.range.start))).setting("end", .number(Double(task.range.end)))
    }
    func scheduled(_ session: JSONValue) -> String { session["scheduledDate"].string ?? session["date"].string ?? "" }
    var week: WeekProgress {
        let (start, end) = LocalCalendar.week(now: now, timeZone: timeZone)
        let sessions = state["sessions"].array.filter { scheduled($0) >= start && scheduled($0) <= end }
        return WeekProgress(start: start, end: end, done: sessions.filter { $0["status"].string == "done" }.count, total: sessions.count)
    }
    var weeklyVerseCounts: [Int] {
        var days: [String: Set<Int>] = [:]
        for s in state["sessions"].array where s["status"].string == "done" && state["studyProgress"]["learning:\(s["id"].string ?? "")"] == .null {
            let day = s["completedDate"].string ?? s["completedAt"].string.map { String($0.prefix(10)) } ?? s["date"].string ?? ""
            if let r = VerseRange(json: s) { days[day, default: []].formUnion(r.start...r.end) }
        }
        for p in state["studyProgress"].object.values where p["mode"].string == "learning" {
            for v in p["validations"].array {
                if let r = VerseRange(json: v), let day = v["date"].string { days[day, default: []].formUnion(r.start...r.end) }
            }
        }
        var c = Calendar(identifier: .gregorian); c.timeZone = timeZone
        let d = c.startOfDay(for: now), start = c.date(byAdding: .day, value: -((c.component(.weekday, from: d) + 5) % 7), to: d)!
        return (0..<7).map { days[LocalCalendar.key(c.date(byAdding: .day, value: $0, to: start)!, timeZone: timeZone)]?.count ?? 0 }
    }
    var streak: Int {
        let dates = Set(state["sessions"].array.filter { $0["status"].string == "done" }.compactMap { $0["completedDate"].string ?? $0["completedAt"].string.map { String($0.prefix(10)) } ?? $0["date"].string } + state["studyProgress"].object.values.filter { $0["mode"].string == "learning" }.flatMap { $0["validations"].array.compactMap { $0["date"].string } })
        var c = Calendar(identifier: .gregorian); c.timeZone = timeZone
        var day = c.startOfDay(for: now), count = 0
        if !dates.contains(LocalCalendar.key(day, timeZone: timeZone)) { day = c.date(byAdding: .day, value: -1, to: day)! }
        while dates.contains(LocalCalendar.key(day, timeZone: timeZone)) { count += 1; day = c.date(byAdding: .day, value: -1, to: day)! }
        return count
    }
    var revision: VerseRange? {
        ProgramProjection(snapshot: snapshot, now: now, timeZone: timeZone).revision?.range
    }
}
