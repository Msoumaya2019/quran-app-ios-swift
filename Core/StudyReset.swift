import Foundation

/// A targeted reset replayed through the existing local queue and server compare-and-swap.
/// Unrelated preferences and social data never enter the reset payload.
enum StudyReset {
    static let objectKeys = ["knowledge", "memorizedAt", "studyProgress", "reviewConsolidations", "nativeManualReviewDue", "reviewPriorityDue", "nativeVerseActionAt"]
    static let arrayKeys = ["sessions", "revisions", "reviewHistory", "consolidationHistory", "reviewCycleHistory", "nativeProgramEdits"]
    static let nullableKeys = ["goal", "reviewCycle", "reviewModelStartedAt", "nativeProgramSettingsUpdatedAt", "nativeReviewSettingsUpdatedAt"]
    static func applying(to state: JSONValue, id: UUID, at: String) -> JSONValue {
        guard (state["nativeStudyResetAt"].string ?? "") < at else { return state }
        let keys = objectKeys + arrayKeys + nullableKeys
        let archived = JSONValue.object(Dictionary(uniqueKeysWithValues: keys.map { ($0, state[$0]) }))
        var history = state["nativeStudyResetHistory"].array
        history.append(.object(["id": .string(id.uuidString), "at": .string(at), "study": archived]))
        var result = state
        for key in objectKeys { result = result.setting(key, .object([:])) }
        for key in arrayKeys { result = result.setting(key, .array([])) }
        for key in nullableKeys { result = result.setting(key, .null) }
        return result.setting("nativeStudyResetHistory", .array(history))
            .setting("nativeStudyResetAt", .string(at))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
}
