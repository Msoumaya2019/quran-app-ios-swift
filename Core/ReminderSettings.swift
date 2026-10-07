import Foundation

struct ReminderSettings: Codable, Equatable, Sendable {
    var learning = false
    var revision = false
    var learningHour = 19
    var learningMinute = 0
    var revisionHour = 20
    var revisionMinute = 0
    var valid: Bool { (0...23).contains(learningHour) && (0...59).contains(learningMinute) && (0...23).contains(revisionHour) && (0...59).contains(revisionMinute) }
    static func load(_ state: JSONValue) -> Self {
        let row = state["notifications"], times = row["nativeReminderTimes"]
        var settings = Self()
        settings.learning = row["learning"].bool == true; settings.revision = row["revision"].bool == true
        settings.learningHour = times["learningHour"].int ?? 19; settings.learningMinute = times["learningMinute"].int ?? 0
        settings.revisionHour = times["revisionHour"].int ?? 20; settings.revisionMinute = times["revisionMinute"].int ?? 0
        if !settings.valid { settings.learningHour = 19; settings.learningMinute = 0; settings.revisionHour = 20; settings.revisionMinute = 0 }
        return settings
    }
    func applying(to state: JSONValue, at: String) -> JSONValue {
        let row = state["notifications"]
        guard valid, (row["nativeRemindersUpdatedAt"].string ?? "") < at else { return state }
        let times = row["nativeReminderTimes"].setting("learningHour", .number(Double(learningHour))).setting("learningMinute", .number(Double(learningMinute))).setting("revisionHour", .number(Double(revisionHour))).setting("revisionMinute", .number(Double(revisionMinute)))
        return state.setting("notifications", row.setting("learning", .bool(learning)).setting("revision", .bool(revision)).setting("nativeReminderTimes", times).setting("nativeRemindersUpdatedAt", .string(at)))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}

struct NativeReminder: Equatable, Sendable {
    let id: String
    let owner: UUID
    let kind: String
    let hour: Int
    let minute: Int
    var title: String { kind == "learning-reminder" ? "Ton programme du Coran" : "Ta révision du Coran" }
    var body: String { kind == "learning-reminder" ? "Retrouve ton passage du jour et prends un moment pour apprendre." : "Prends un moment pour revoir tes passages connus." }
    static let prefix = "corannative.reminder."
    static func plan(owner: UUID, settings: ReminderSettings) -> [Self] {
        guard settings.valid else { return [] }
        let learning = Self(id: prefix + owner.uuidString.lowercased() + ".learning", owner: owner, kind: "learning-reminder", hour: settings.learningHour, minute: settings.learningMinute)
        let revision = Self(id: prefix + owner.uuidString.lowercased() + ".revision", owner: owner, kind: "revision-reminder", hour: settings.revisionHour, minute: settings.revisionMinute)
        return (settings.learning ? [learning] : []) + (settings.revision ? [revision] : [])
    }
}
