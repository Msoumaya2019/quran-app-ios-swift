import Foundation

struct ProgramEdit: Codable, Sendable {
    static let paces: [(String, String)] = [("verse1", "1 verset"), ("verse2", "2 versets"), ("verse3", "3 versets"), ("verse4", "4 versets"), ("verse5", "5 versets"), ("halfPage", "½ page"), ("page", "1 page"), ("page2", "2 pages"), ("quarter", "1 rubu‘"), ("halfHizb", "1 nisf"), ("hizb", "1 hizb")]
    static let weights: [Int] = {
        guard let url = Bundle.main.url(forResource: "quran-weights", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
    }()
    let id: String
    let goal: JSONValue
    let pace: String
    let days: [Int]
    let from: String
    let at: String
    let timeZoneID: String
    init(goal: JSONValue, pace: String, days: [Int], now: Date = .now, timeZone: TimeZone = .current) {
        id = UUID().uuidString; self.goal = goal; self.pace = pace; self.days = Array(Set(days)).sorted()
        from = LocalCalendar.key(now, timeZone: timeZone); timeZoneID = timeZone.identifier
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        at = formatter.string(from: now)
    }
    func applying(to state: JSONValue, catalog: QuranCatalog) -> JSONValue {
        guard !state["nativeProgramEdits"].array.contains(where: { $0["id"].string == id }),
              (state["nativeProgramSettingsUpdatedAt"].string ?? "") <= at,
              !days.isEmpty, days.allSatisfy({ (0...6).contains($0) }), Self.paces.contains(where: { $0.0 == pace }),
              let generated = generatedSessions(state: state, catalog: catalog) else { return state }
        var fields = state["goal"].object
        for (key, value) in goal.object { fields[key] = value }
        if goal["deadline"] == .null { fields.removeValue(forKey: "deadline") }
        var history = state["nativeProgramEdits"].array
        history.append(.object(["id": .string(id), "at": .string(at), "from": .string(from), "pace": .string(pace), "goal": .object(fields), "learningDays": .array(days.map { .number(Double($0)) })]))
        return state.setting("goal", .object(fields)).setting("pace", .string(pace))
            .setting("learningDays", .array(days.map { .number(Double($0)) })).setting("sessions", .array(generated))
            .setting("nativeProgramEdits", .array(history)).setting("nativeProgramSettingsUpdatedAt", .string(at))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
    func generatedSessions(state: JSONValue, catalog: QuranCatalog, preview: Bool = false) -> [JSONValue]? {
        let ranges = goal["ranges"].array.compactMap { VerseRange(json: $0) }
        guard !ranges.isEmpty, ranges.count == goal["ranges"].array.count, !days.isEmpty, days.allSatisfy({ (0...6).contains($0) }),
              Self.paces.contains(where: { $0.0 == pace }), let zone = TimeZone(identifier: timeZoneID), !catalog.surahs.isEmpty else { return nil }
        var old = state["sessions"].array, covered = Set<Int>()
        for index in old.indices {
            let row = old[index], progress = state["studyProgress"]["learning:\(row["id"].string ?? "")"]
            let partial = progress["status"].string == "partial" || ["partial", "partiallyCompleted"].contains(row["status"].string ?? "")
            if row["status"].string == "done" || partial {
                if let range = VerseRange(json: row) { covered.formUnion(range.start...range.end) }
            } else if ["todo", "pending", "partiallyCompleted"].contains(row["status"].string ?? "") {
                // Retain the original row, dates and ID as history instead of deleting it.
                old[index] = row.setting("status", .string("postponed"))
            }
        }
        var selected = Set<Int>()
        for range in ranges { selected.formUnion(range.start...range.end) }
        var remaining = selected.filter { !covered.contains($0) && !["perfect", "review"].contains(state["knowledge"][String($0)].string ?? "") }.sorted()
        if goal["direction"].string == "fromNas" {
            let surahNumber = Dictionary(uniqueKeysWithValues: catalog.surahs.flatMap { surah in (surah.start...surah.end).map { ($0, surah.number) } })
            remaining.sort { let a = surahNumber[$0] ?? 0, b = surahNumber[$1] ?? 0; return a == b ? $0 < $1 : a > b }
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = calendar; formatter.timeZone = zone; formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard var date = formatter.date(from: from), formatter.string(from: date) == from else { return nil }
        var serial = 0, offset = 0, cursor = 0
        while cursor < remaining.count && offset < 6236 * 7 + 7 {
            let key = formatter.string(from: date)
            if days.contains(calendar.component(.weekday, from: date) - 1) {
                guard let count = chunkSize(remaining, cursor: cursor, catalog: catalog), count > 0 else { return nil }
                var spans: [(Int, Int)] = []
                for verse in remaining[cursor..<(cursor + count)].sorted() {
                    if let last = spans.last, last.1 + 1 == verse, (!pace.hasPrefix("verse") || catalog.surah(for: last.0)?.number == catalog.surah(for: verse)?.number) { spans[spans.count - 1].1 = verse }
                    else { spans.append((verse, verse)) }
                }
                for (a, b) in spans {
                    old.append(.object(["id": .string("\(key)-\(a)-native-\(id)-\(serial)"), "date": .string(key), "scheduledDate": .string(key), "start": .number(Double(a)), "end": .number(Double(b)), "unit": .string(pace), "status": .string("todo")]))
                    serial += 1
                }
                cursor += count
                if preview { return old }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            date = next; offset += 1
        }
        guard cursor == remaining.count else { return nil }
        return old.sorted { ($0["scheduledDate"].string ?? $0["date"].string ?? "") < ($1["scheduledDate"].string ?? $1["date"].string ?? "") }
    }
    private func chunkSize(_ ids: [Int], cursor: Int, catalog: QuranCatalog) -> Int? {
        if pace.hasPrefix("verse"), let count = Int(pace.dropFirst(5)) { return min(count, ids.count - cursor) }
        let first = ids[cursor]
        if ["page", "page2", "halfPage"].contains(pace) {
            let limit = pace == "page2" ? 2 : 1
            var pages = Set<Int>(), size = 0, volume = 0
            let page = catalog.page(for: first)
            let a = catalog.pageStarts.first { $0.0 == page }?.1 ?? first
            let b = (catalog.pageStarts.first { $0.0 == page + 1 }?.1 ?? 6237) - 1
            guard pace != "halfPage" || Self.weights.count == 6236 else { return nil }
            let target = pace == "halfPage" ? Double(Self.weights[(a - 1)..<b].reduce(0, +)) / 2 : .infinity
            for verse in ids[cursor...] {
                let p = catalog.page(for: verse)
                if !pages.contains(p), pages.count == limit { break }
                pages.insert(p); size += 1
                if pace == "halfPage" { volume += Self.weights[verse - 1]; if Double(volume) >= target { break } }
            }
            return size
        }
        let divisions: [QuranDivision]
        if pace == "quarter" { divisions = catalog.quarters }
        else if pace == "halfHizb" {
            divisions = stride(from: 0, to: catalog.quarters.count, by: 2).compactMap { i in
                guard i + 1 < catalog.quarters.count else { return nil }
                return QuranDivision(number: i / 2 + 1, start: catalog.quarters[i].start, end: catalog.quarters[i + 1].end)
            }
        } else { divisions = catalog.hizbs }
        guard let boundary = divisions.first(where: { $0.start <= first && first <= $0.end }) else { return nil }
        return ids[cursor...].prefix { boundary.start <= $0 && $0 <= boundary.end }.count
    }
}
