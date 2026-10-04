import Foundation

struct ProgressProjection {
    let state: JSONValue
    var known: Set<Int> {
        Set(state["knowledge"].object.compactMap { key, value in
            guard ["perfect", "review"].contains(value.string ?? ""), let id = Int(key), (1...6236).contains(id) else { return nil }; return id
        })
    }
    var goalIDs: Set<Int> { state["goal"]["ranges"].array.reduce(into: Set<Int>()) { result, row in if let range = VerseRange(json: row) { result.formUnion(range.start...range.end) } } }
    var goalRatio: Double { let ids = goalIDs; return ids.isEmpty ? 0 : Double(known.intersection(ids).count) / Double(ids.count) }
    func completePages(catalog: QuranCatalog) -> Int {
        let starts = catalog.pageStarts
        let learned = known
        return starts.enumerated().filter { index, row in
            let end = index + 1 < starts.count ? starts[index + 1].1 - 1 : 6236
            return row.1 <= end && (row.1...end).allSatisfy { learned.contains($0) }
        }.count
    }
    func completeJuzs(catalog: QuranCatalog) -> Int { let learned = known; return catalog.juzs.filter { ($0.start...$0.end).allSatisfy { learned.contains($0) } }.count }
}
struct QuizStatistics {
    let data: JSONValue
    let owner: UUID?
    var dailyTotal: Int { data["responses"].array.count }
    var dailyCorrect: Int { data["responses"].array.filter { $0["isCorrect"].bool == true }.count }
    var successPercent: Int { dailyTotal == 0 ? 0 : Int(Double(dailyCorrect) / Double(dailyTotal) * 100) }
    var completed: [JSONValue] { data["challenges"].array.filter { $0["status"].string == "completed" } }
    private func scores(_ row: JSONValue) -> (Int, Int)? {
        guard let owner else { return nil }
        let p = QuizChallengeProjection(value: row, owner: owner)
        let other = row[row["creatorId"].string?.lowercased() == owner.uuidString.lowercased() ? "opponentId" : "creatorId"].string ?? ""
        guard let own = p.score(user: owner.uuidString), let theirs = p.score(user: other) else { return nil }; return (own, theirs)
    }
    var wins: Int { completed.filter { scores($0).map { $0.0 > $0.1 } == true }.count }
    var draws: Int { completed.filter { scores($0).map { $0.0 == $0.1 } == true }.count }
}
