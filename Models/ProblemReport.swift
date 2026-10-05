import Foundation

enum ProblemType: String, Codable, CaseIterable, Identifiable {
    case bug = "Bug", display = "Affichage", audio = "Audio", notification = "Notification", other = "Autre"
    var id: String { rawValue }
    var icon: String {
        switch self { case .bug: return "ladybug"; case .display: return "display"; case .audio: return "speaker.wave.2"; case .notification: return "bell"; case .other: return "ellipsis" }
    }
}
struct ProblemReport: Codable, Equatable, Identifiable {
    let id: UUID
    let user_id: UUID
    let type: ProblemType
    let description: String
    let screenshot_path: String?
    let app_version: String
    let platform: String
    let created_at: String
    let status: String
    static func create(owner: UUID, type: ProblemType, description: String, screenshot: Bool, version: String, now: Date = .now) throws -> Self {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.count <= 500 else { throw CocoaError(.validationMissingMandatoryProperty) }
        let id = UUID()
        return Self(id: id, user_id: owner, type: type, description: text,
                    screenshot_path: screenshot ? owner.uuidString.lowercased() + "/" + id.uuidString.lowercased() + ".jpg" : nil,
                    app_version: String(version.prefix(32)), platform: "ios", created_at: ISO8601DateFormatter().string(from: now), status: "open")
    }
    var valid: Bool {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.unicodeScalars.count <= 500 && platform == "ios" && status == "open" && app_version.count <= 32 &&
            (screenshot_path == nil || screenshot_path == user_id.uuidString.lowercased() + "/" + id.uuidString.lowercased() + ".jpg")
    }
}
