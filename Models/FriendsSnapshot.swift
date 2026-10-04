import Foundation

struct FriendItem: Identifiable, Equatable {
    let id: String
    let otherID: String
    let name: String
    let status: String
    let incoming: Bool
    let online: Bool
}
struct FriendsSnapshot: Codable, Equatable {
    var owner: UUID
    var profile: JSONValue = .null
    var links: JSONValue = .array([])
    var profiles: JSONValue = .array([])
    var inbox: JSONValue = .array([])
    var overviews: [String: JSONValue]? = nil
    func overview(for id: String) -> JSONValue {
        guard items().contains(where: { $0.otherID == id.lowercased() }),
              let profile = profiles.array.first(where: { $0["id"].string?.lowercased() == id.lowercased() }),
              profile["share_progress"].bool == true else { return .null }
        return overviews?[id.lowercased()] ?? .null
    }
    func items(search: String = "", filter: String = "all") -> [FriendItem] {
        let user = owner.uuidString.lowercased()
        let byID = Dictionary(profiles.array.compactMap { row -> (String, JSONValue)? in
            guard let id = row["id"].string else { return nil }; return (id.lowercased(), row)
        }, uniquingKeysWith: { _, last in last })
        let onlineIDs = Set(inbox.array.filter { $0["is_online"].bool == true }.compactMap { $0["other_id"].string?.lowercased() })
        return links.array.compactMap { row -> FriendItem? in
            guard let id = row["id"].string, let requester = row["requester_id"].string?.lowercased(),
                  let recipient = row["recipient_id"].string?.lowercased(), requester == user || recipient == user,
                  let status = row["status"].string, status == "accepted" || status == "pending" else { return nil }
            let other = requester == user ? recipient : requester
            let profile = byID[other] ?? .null
            let name = profile["display_name"].string ?? "Ami"
            let online = profile["share_online"].bool == true && onlineIDs.contains(other)
            guard search.isEmpty || name.localizedStandardContains(search) else { return nil }
            if filter == "requests" { guard status == "pending" else { return nil } }
            else { guard status == "accepted", filter != "online" || online else { return nil } }
            return FriendItem(id: id, otherID: other, name: name, status: status, incoming: recipient == user, online: online)
        }
    }
}
