import Foundation

struct ReaderOperation: Codable, Sendable, Identifiable {
    enum Kind: String, Codable { case reading, bookmark, removeBookmark, source, reciter, consolidation, learning, revision, program, difficulty, reviewSchedule }
    let id: UUID
    let kind: Kind
    let verseID: Int
    let page: Int
    let source: String
    var consolidation: ConsolidationValidation? = nil
    var learning: LearningValidation? = nil
    var revision: RevisionValidation? = nil
    var program: ProgramEdit? = nil
    var difficulty: DifficultyChange? = nil
    var reviewSchedule: RevisionScheduleChange? = nil
    let at: String
    init(kind: Kind, verseID: Int, page: Int, source: String, date: Date = .now) {
        id = UUID(); self.kind = kind; self.verseID = verseID; self.page = page; self.source = source
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        at = formatter.string(from: date)
    }
    func applying(to state: JSONValue, catalog: QuranCatalog) -> JSONValue {
        var result = state
        switch kind {
        case .reviewSchedule:
            guard let reviewSchedule else { return state }
            return reviewSchedule.applying(to: state, catalog: catalog)
        case .difficulty:
            guard let difficulty else { return state }
            return difficulty.applying(to: state)
        case .program:
            guard let program else { return state }
            return program.applying(to: state, catalog: catalog)
        case .revision:
            guard let revision else { return state }
            return revision.applying(to: state)
        case .learning:
            guard let learning else { return state }
            return learning.applying(to: state)
        case .consolidation:
            guard let consolidation else { return state }
            return consolidation.applying(to: state)
        case .reciter:
            result = result.setting("audioPreferences", state["audioPreferences"].setting("reciterId", .string(source)))
        case .source:
            result = result.setting("reader", state["reader"].setting("mushaf", .string(source)))
        case .reading:
            let readPages = Set(state["readPages"].array.compactMap(\.int) + [page]).sorted().map { JSONValue.number(Double($0)) }
            result = result.setting("readPages", .array(readPages))
            if (state["lastRead"]["readAt"].string ?? "") <= at {
                result = result.setting("lastRead", .object(["page": .number(Double(page)), "verseId": .number(Double(verseID)), "readAt": .string(at)]))
            }
        case .bookmark, .removeBookmark:
            let key = String(verseID), previous = state["bookmarks"][key]
            guard (previous["updatedAt"].string ?? "") <= at, let surah = catalog.surah(for: verseID) else { return state }
            var value = previous.object
            value["verseId"] = .number(Double(verseID)); value["surah"] = .number(Double(surah.number))
            value["ayah"] = .number(Double(verseID - surah.start + 1)); value["page"] = .number(Double(catalog.page(for: verseID)))
            value["createdAt"] = previous["createdAt"].string.map(JSONValue.string) ?? .string(at)
            value["updatedAt"] = .string(at)
            value["sourcePages"] = previous["sourcePages"].setting(source, .number(Double(page)))
            if kind == .removeBookmark { value["deletedAt"] = .string(at) } else { value.removeValue(forKey: "deletedAt") }
            result = result.setting("bookmarks", state["bookmarks"].setting(key, .object(value)))
        }
        return result.setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}
extension JSONValue {
    func setting(_ key: String, _ value: JSONValue) -> JSONValue { var fields = object; fields[key] = value; return .object(fields) }
}
