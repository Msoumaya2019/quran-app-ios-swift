import Foundation

struct QuizPendingAnswer: Codable, Equatable {
    let question: JSONValue
    let answerID: String
    let day: String
    let answeredAt: String
}
struct QuizCache: Codable {
    let owner: UUID
    var data: JSONValue = .null
    var pending: [QuizPendingAnswer] = []
    func response(day: String) -> JSONValue? {
        if let row = data["responses"].array.first(where: { $0["day"].string == day }) { return row }
        return pending.first(where: { $0.day == day }).map { .object(["day": .string($0.day), "question": $0.question, "selectedAnswerId": .string($0.answerID), "pending": .bool(true)]) }
    }
    mutating func answer(_ question: JSONValue, answerID: String, day: String, now: Date = .now) throws {
        guard response(day: day) == nil, question["publicationDate"].string == day,
              UUID(uuidString: question["id"].string ?? "") != nil,
              question["answers"].array.contains(where: { $0["id"].string == answerID }) else { throw URLError(.badServerResponse) }
        pending.append(QuizPendingAnswer(question: question, answerID: answerID, day: day, answeredAt: ISO8601DateFormatter().string(from: now)))
    }
}
