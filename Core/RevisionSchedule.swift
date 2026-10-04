import Foundation

struct RevisionPreferences: Codable, Equatable, Sendable {
    var enabled = true
    var mode = "cycle"
    var cycleDays = 7
    var dailyQuantity = "hizb"
    init(state: JSONValue) {
        let row = state["reviewSettings"]
        enabled = row["enabled"].bool != false
        mode = row["mode"].string == "quantity" ? "quantity" : "cycle"
        cycleDays = [7, 14, 21, 30].contains(row["cycleDays"].int ?? 7) ? row["cycleDays"].int ?? 7 : 7
        dailyQuantity = ["nisf", "hizb", "juz", "juz2"].contains(row["dailyQuantity"].string ?? "hizb") ? row["dailyQuantity"].string ?? "hizb" : "hizb"
    }
    var valid: Bool { ["cycle", "quantity"].contains(mode) && [7, 14, 21, 30].contains(cycleDays) && ["nisf", "hizb", "juz", "juz2"].contains(dailyQuantity) }
    var title: String {
        guard enabled else { return "Révisions en pause" }
        if mode == "cycle" { return "Cycle de \(cycleDays) jours" }
        return ["nisf": "1 Nisf / jour", "hizb": "1 Hizb / jour", "juz": "1 Juz’ / jour", "juz2": "2 Juz’ / jour"][dailyQuantity] ?? ""
    }
}

/// Replayed against the latest server JSON by the existing compare-and-swap queue.
struct RevisionScheduleChange: Codable, Sendable {
    let day: String
    let at: String
    let preferences: RevisionPreferences?
    init(preferences: RevisionPreferences? = nil, now: Date = .now, timeZone: TimeZone = .current) {
        day = LocalCalendar.key(now, timeZone: timeZone); self.preferences = preferences
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        at = formatter.string(from: now)
    }
    func applying(to state: JSONValue, catalog: QuranCatalog) -> JSONValue {
        let zone = TimeZone(secondsFromGMT: 0)!
        guard ProgramProjection.addingDays(0, to: day, timeZone: zone) != nil else { return state }
        var result = state
        var reset = false
        if let preferences {
            guard preferences.valid, (state["nativeReviewSettingsUpdatedAt"].string ?? "") < at else { return state }
            let old = RevisionPreferences(state: state)
            reset = old.mode != preferences.mode || (preferences.mode == "cycle" ? old.cycleDays != preferences.cycleDays : old.dailyQuantity != preferences.dailyQuantity)
            var settings = state["reviewSettings"].object
            settings["enabled"] = .bool(preferences.enabled); settings["mode"] = .string(preferences.mode)
            settings["cycleDays"] = .number(Double(preferences.cycleDays)); settings["dailyQuantity"] = .string(preferences.dailyQuantity)
            if !old.enabled && preferences.enabled { settings["resumedAt"] = .string(day) }
            result = result.setting("reviewSettings", .object(settings)).setting("nativeReviewSettingsUpdatedAt", .string(at))
        }
        let settings = RevisionPreferences(state: result)
        if settings.enabled || reset {
            let known = result["knowledge"].object.compactMap { key, value -> Int? in
                guard let id = Int(key), (1...6236).contains(id), ["perfect", "review"].contains(value.string ?? "") else { return nil }; return id
            }.sorted()
            // Do not create empty programs for a new account before knowledge is entered.
            if !known.isEmpty || result["reviewCycle"] != .null {
                let old = result["reviewCycle"]
                var cycle = old
                let corpus = old["corpus"].array.compactMap(\.int), completed = Set(old["completed"].array.compactMap(\.int))
                let finished = corpus.allSatisfy { completed.contains($0) || !["perfect", "review"].contains(result["knowledge"][String($0)].string ?? "") }
                let expiry = old["startDate"].string.flatMap { ProgramProjection.addingDays(max(1, old["lengthDays"].int ?? settings.cycleDays), to: $0, timeZone: zone) }
                let rollover = finished && expiry.map { day >= $0 } == true
                if reset || old == .null || (settings.mode == "cycle" && old["lengthDays"].int != settings.cycleDays) || rollover {
                    if old != .null {
                        var history = result["reviewCycleHistory"].array
                        if !history.contains(where: { $0["index"] == old["index"] && $0["startDate"] == old["startDate"] }) { history.append(old) }
                        result = result.setting("reviewCycleHistory", .array(history))
                    }
                    cycle = RevisionSchedule.create(state: result, known: known, settings: settings, day: day, index: (old["index"].int ?? 0) + 1, catalog: catalog)
                }
                if settings.enabled, cycle["assignments"][day] == .null, let start = cycle["startDate"].string, start <= day {
                    let done = Set(cycle["completed"].array.compactMap(\.int))
                    let index = cycle["days"].array.enumerated().first { offset, row in
                        guard let planned = ProgramProjection.addingDays(offset, to: start, timeZone: zone), planned <= day else { return false }
                        return row.array.compactMap(\.int).contains { !done.contains($0) && ["perfect", "review"].contains(result["knowledge"][String($0)].string ?? "") }
                    }?.offset ?? -1
                    cycle = cycle.setting("assignments", cycle["assignments"].setting(day, .number(Double(index))))
                }
                result = result.setting("reviewCycle", cycle)
                if result["reviewModelStartedAt"] == .null { result = result.setting("reviewModelStartedAt", .string(day)) }
            }
        }
        if settings.enabled { result = ConsolidationRecovery.applying(to: result) }
        return result == state ? state : result.setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}

enum RevisionSchedule {
    static func halves(_ catalog: QuranCatalog) -> [QuranDivision] {
        stride(from: 0, to: catalog.quarters.count, by: 2).compactMap { i in
            guard i + 1 < catalog.quarters.count else { return nil }
            return QuranDivision(number: i / 2 + 1, start: catalog.quarters[i].start, end: catalog.quarters[i + 1].end)
        }
    }
    static func quantity(_ corpus: [Int], kind: String, catalog: QuranCatalog) -> [[Int]] {
        let units = kind == "nisf" ? halves(catalog) : kind == "hizb" ? catalog.hizbs : catalog.juzs
        let ids = Array(Set(corpus.filter { (1...6236).contains($0) })).sorted()
        let groups = units.map { unit in ids.filter { unit.start <= $0 && $0 <= unit.end } }.filter { !$0.isEmpty }
        guard kind == "juz2" else { return groups }
        var paired: [[Int]] = []
        for (index, row) in groups.enumerated() { if index % 2 == 0 { paired.append(row) } else { paired[paired.count - 1] += row } }
        return paired
    }
    private static let weights: [Double] = {
        let catalog = QuranCatalog(), raw = ProgramEdit.weights
        guard raw.count == 6236 else { return [] }
        var totals: [Int: Int] = [:], pages = [Int](repeating: 0, count: 6236)
        for id in 1...6236 { let page = catalog.page(for: id); pages[id - 1] = page; totals[page, default: 0] += raw[id - 1] }
        return (0..<6236).map { Double(raw[$0]) / Double(max(1, totals[pages[$0]] ?? 1)) }
    }()
    static func temporal(_ corpus: [Int], length: Int, catalog: QuranCatalog) -> [[Int]] {
        guard length > 0 else { return [] }
        let ordered = Array(Set(corpus.filter { (1...6236).contains($0) })).sorted(), set = Set(ordered)
        let divisions = [catalog.hizbs, halves(catalog), catalog.quarters]
        for units in divisions {
            let whole = units.filter { ($0.start...$0.end).allSatisfy { set.contains($0) } }
            if whole.count >= length, whole.count % length == 0, whole.reduce(0, { $0 + $1.end - $1.start + 1 }) == ordered.count {
                let count = whole.count / length
                return (0..<length).map { day in whole[(day * count)..<((day + 1) * count)].flatMap { Array($0.start...$0.end) } }
            }
        }
        var prefix = [0.0]
        for id in ordered { prefix.append(prefix.last! + (weights.indices.contains(id - 1) ? weights[id - 1] : 1)) }
        let total = prefix.last!, daily = total / Double(length)
        let boundaries = divisions.map { units -> [Int] in
            let ends = Set(units.map(\.end)); return ordered.enumerated().compactMap { ends.contains($0.element) ? $0.offset + 1 : nil }
        }
        var cursor = 0, days: [[Int]] = []
        for day in 1...length {
            var end = cursor; let target = daily * Double(day)
            if day == length { end = ordered.count }
            else {
                while end < ordered.count && prefix[end + 1] <= target { end += 1 }
                if end < ordered.count && abs(prefix[end + 1] - target) < abs(prefix[end] - target) { end += 1 }
                for indexes in boundaries {
                    let candidates = indexes.filter { $0 > cursor && abs(prefix[$0] - target) <= daily * 0.15 }
                    if let nearest = candidates.min(by: { abs(prefix[$0] - target) < abs(prefix[$1] - target) }) { end = nearest; break }
                }
            }
            days.append(Array(ordered[cursor..<end])); cursor = end
        }
        return days
    }
    static func create(state: JSONValue, known: [Int], settings: RevisionPreferences, day: String, index: Int, catalog: QuranCatalog) -> JSONValue {
        let modelStart = state["reviewModelStartedAt"].string ?? day
        let zone = TimeZone(secondsFromGMT: 0)!
        var establishedDates: [String: Bool] = [:]
        let corpus = known.filter { id in
            let key = String(id)
            guard let learned = state["memorizedAt"][key].string else { return true }
            let established: Bool
            if let cached = establishedDates[learned] { established = cached }
            else {
                established = learned < modelStart && ProgramProjection.addingDays(7, to: learned, timeZone: zone).map { $0 <= modelStart } == true
                establishedDates[learned] = established
            }
            let consolidation = state["reviewConsolidations"][key]
            return established || (consolidation["learnedAt"].string == learned && consolidation["completed"]["7"] != .null)
        }
        let days = settings.mode == "quantity" ? quantity(corpus, kind: settings.dailyQuantity, catalog: catalog) : temporal(corpus, length: settings.cycleDays, catalog: catalog)
        return .object(["index": .number(Double(index)), "startDate": .string(day), "lengthDays": .number(Double(settings.mode == "quantity" ? max(1, days.count) : settings.cycleDays)), "corpus": .array(corpus.map { .number(Double($0)) }), "days": .array(days.map { .array($0.map { .number(Double($0)) }) }), "completed": .array([]), "assignments": .object([:])])
    }
}
