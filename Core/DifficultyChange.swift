import Foundation

struct DifficultyChange: Codable, Sendable {
    let id: String
    let verseID: Int
    let difficult: Bool
    let day: String
    let at: String
    init(verseID: Int, difficult: Bool, now: Date = .now, timeZone: TimeZone = .current) {
        id = UUID().uuidString; self.verseID = verseID; self.difficult = difficult
        day = LocalCalendar.key(now, timeZone: timeZone)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        at = formatter.string(from: now)
    }
    func applying(to state: JSONValue) -> JSONValue {
        let key = String(verseID)
        guard (1...6236).contains(verseID),
              (state["nativeDifficultyUpdatedAt"][key].string ?? "") <= at,
              !state["difficultyHistory"].array.contains(where: { $0["id"].string == id }) else { return state }
        var marker = state["difficultyMarkers"][key].object
        var markers = state["difficultyMarkers"].object, due = state["reviewPriorityDue"].object
        if difficult {
            if marker["user"] == nil || marker["user"] == .null { marker["user"] = .object(["createdAt": .string(day)]) }
            due[key] = .string(day)
        } else {
            marker.removeValue(forKey: "user")
            if marker["admin"] == nil || marker["admin"] == .null { due.removeValue(forKey: key) }
        }
        if marker.isEmpty { markers.removeValue(forKey: key) } else { markers[key] = .object(marker) }
        var history = state["difficultyHistory"].array
        history.append(.object(["id": .string(id), "verseId": .number(Double(verseID)), "date": .string(day), "at": .string(at), "origin": .string("user"), "action": .string(difficult ? "marked" : "resolved")]))
        return state.setting("difficultyMarkers", .object(markers)).setting("reviewPriorityDue", .object(due))
            .setting("difficultyHistory", .array(history))
            .setting("nativeDifficultyUpdatedAt", state["nativeDifficultyUpdatedAt"].setting(key, .string(at)))
            .setting("updatedAt", .string(max(state["updatedAt"].string ?? "", at)))
    }
    static func isDifficult(_ state: JSONValue, verseID: Int) -> Bool {
        let row = state["difficultyMarkers"][String(verseID)]
        return row["user"] != .null || row["admin"] != .null
    }
}
