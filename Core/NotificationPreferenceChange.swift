import Foundation

struct NotificationPreferenceChange: Codable, Equatable, Sendable {
    enum Field: String, Codable, CaseIterable, Identifiable {
        case messages, friendRequests, sharedProgress, corrections, adminMessages, messagePreview, quiz
        var id: String { rawValue }
        var title: String {
            switch self {
            case .messages: return "Messages entre amis"
            case .friendRequests: return "Demandes d’amis"
            case .sharedProgress: return "Progression de mes amis"
            case .corrections: return "Retours sur mes récitations"
            case .adminMessages: return "Messages de l’administrateur"
            case .messagePreview: return "Afficher le contenu des messages"
            case .quiz: return "Quiz et défis"
            }
        }
        var column: String {
            switch self {
            case .messages: return "messages_enabled"
            case .friendRequests: return "friend_requests_enabled"
            case .sharedProgress: return "shared_progress_enabled"
            case .corrections: return "corrections_enabled"
            case .adminMessages: return "admin_messages_enabled"
            case .messagePreview: return "message_preview_enabled"
            case .quiz: return "quiz_enabled"
            }
        }
        func value(in state: JSONValue) -> Bool { state["notifications"][rawValue].bool ?? (self != .sharedProgress) }
    }
    let field: Field
    let enabled: Bool
    func applying(to state: JSONValue, at: String) -> JSONValue {
        let preferences = state["notifications"], versions = preferences["nativePreferenceVersions"]
        guard (versions[field.rawValue].string ?? "") < at else { return state }
        return state.setting("notifications", preferences.setting(field.rawValue, .bool(enabled))
            .setting("nativePreferenceVersions", versions.setting(field.rawValue, .string(at))))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
    static func serverPatch(owner: UUID, state: JSONValue, operations: [ReaderOperation]) -> JSONValue? {
        let fields = Set(operations.filter { $0.kind == .notifications }.compactMap { $0.notification?.field })
        guard !fields.isEmpty else { return nil }
        var values: [String: JSONValue] = ["user_id": .string(owner.uuidString.lowercased())]
        for field in fields { values[field.column] = .bool(field.value(in: state)) }
        return .object(values)
    }
}
