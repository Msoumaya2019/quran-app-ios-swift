import Foundation

enum EditorialKind: String, CaseIterable, Identifiable {
    case reminder, invocation
    var id: String { rawValue }
    var title: String { self == .reminder ? "Rappels" : "Invocations" }
}

struct EditorialDraft {
    var value: JSONValue
    var date = ""
    init(row: JSONValue = .null, kind: EditorialKind, categories: [JSONValue]) {
        value = row == .null ? .object(["id": .string(UUID().uuidString.lowercased()), "type": .string(kind.rawValue), "is_active": .bool(true), "category_id": .string(categories.first { $0["type"].string == kind.rawValue && $0["is_active"].bool == true }?["id"].string ?? "")]) : row
    }
    var payload: JSONValue {
        var fields: [String: JSONValue] = [:]
        for key in ["id", "type", "category_id", "french_text", "source"] { fields[key] = .string(value[key].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines)) }
        for key in ["title", "arabic_text", "phonetic_text", "explanation", "reference", "image_url", "audio_url"] {
            let text = value[key].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines)
            fields[key] = text.isEmpty ? .null : .string(text)
        }
        fields["is_active"] = .bool(value["is_active"].bool ?? true)
        return .object(fields)
    }
    static func validDate(_ text: String) -> Bool {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard text.count == 10, let date = formatter.date(from: text) else { return false }
        return formatter.string(from: date) == text
    }
    static func validMedia(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return true }
        guard let url = URL(string: text), url.scheme?.lowercased() == "https", url.host?.isEmpty == false, url.user == nil, url.password == nil else { return false }
        return true
    }
    func validation(categories: [JSONValue]) -> String? {
        let row = payload
        guard UUID(uuidString: row["id"].string.orEmpty) != nil, let kind = EditorialKind(rawValue: row["type"].string.orEmpty) else { return "Ce contenu n’est pas valide." }
        guard categories.contains(where: { $0["id"] == row["category_id"] && $0["type"].string == kind.rawValue }) else { return "Choisis une catégorie du même type que le contenu." }
        guard !row["french_text"].string.orEmpty.isEmpty, !row["source"].string.orEmpty.isEmpty else { return "Le texte français et la source sont obligatoires." }
        if kind == .invocation && (row["arabic_text"].string.orEmpty.isEmpty || row["phonetic_text"].string.orEmpty.isEmpty) { return "Ajoute le texte arabe et la phonétique de l’invocation." }
        guard Self.validMedia(row["image_url"].string), Self.validMedia(row["audio_url"].string) else { return "Les liens d’image et d’audio doivent être des adresses HTTPS valides." }
        guard date.isEmpty || Self.validDate(date) else { return "La date doit être valide, au format AAAA-MM-JJ." }
        return nil
    }
    static func validCategory(_ row: JSONValue) -> Bool {
        guard case .number(let order) = row["display_order"], order.isFinite, order.rounded() == order, order >= Double(Int32.min), order <= Double(Int32.max) else { return false }
        return UUID(uuidString: row["id"].string.orEmpty) != nil && EditorialKind(rawValue: row["type"].string.orEmpty) != nil && (1...100).contains(row["name"].string.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count) && row["is_active"].bool != nil
    }
}

struct EditorialSnapshot {
    let categories: [JSONValue]
    let contents: [JSONValue]
    let schedules: [JSONValue]
}

private extension Optional where Wrapped == String { var orEmpty: String { self ?? "" } }
