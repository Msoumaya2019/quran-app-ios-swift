import Foundation

struct QuizChallengeProjection {
    let value: JSONValue
    let owner: UUID
    var id: String { value["id"].string ?? "" }
    var completed: Bool { value["status"].string == "completed" }
    var expired: Bool { value["status"].string == "expired" || (!completed && ChatMessage.date(value["expiresAt"].string ?? "").map { $0 <= .now } == true) }
    var ownAnswers: [JSONValue] { value["answers"].array.filter { $0["userId"].string?.lowercased() == owner.uuidString.lowercased() } }
    var next: JSONValue? { value["questions"].array.first { question in !ownAnswers.contains { $0["questionId"].string == question["id"].string } } }
    var otherName: String { value[value["creatorId"].string?.lowercased() == owner.uuidString.lowercased() ? "opponentName" : "creatorName"].string ?? "Ami" }
    var status: String { completed ? "Terminé" : expired ? "Expiré" : next == nil ? "En attente de l’ami" : "À toi de jouer" }
    func score(user: String) -> Int? {
        guard completed else { return nil }
        return value["answers"].array.filter { $0["userId"].string?.lowercased() == user.lowercased() && $0["isCorrect"].bool == true }.count
    }
}
