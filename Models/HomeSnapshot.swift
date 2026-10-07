import Foundation

struct AccountIdentity: Codable, Equatable, Sendable {
    let id: UUID
    let email: String?
}
struct DailyContent: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String
    let title: String?
    let arabic_text: String?
    let phonetic_text: String?
    let french_text: String
    let source: String
    let reference: String?
    let explanation: String?
    let image_url: String?
    var audio_url: String? = nil
}
struct HomeSnapshot: Codable, Sendable {
    var readerOperations: [ReaderOperation]?
    var state: JSONValue = .object([:])
    var displayName: String?
    var contents: [DailyContent] = []
    var contentDate: String?
    var quizAvailable = false
    var quizDone = false
    var quizDate: String?
    var fetchedAt: Date?
}
struct VerseRange: Hashable, Sendable {
    let start: Int
    let end: Int
    var count: Int { max(0, end - start + 1) }
    init?(json: JSONValue) {
        guard let s = json["start"].int, let e = json["end"].int, (1...6236).contains(s), (s...6236).contains(e) else { return nil }
        start = s; end = e
    }
}
