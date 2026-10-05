import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var library: FriendsLibrary
    @EnvironmentObject var theme: ThemeManager
    @State private var name = ""
    @State private var busy = false
    var body: some View {
        List {
            Section("Nouveau groupe") {
                TextField("Nom du groupe", text: $name)
                Button("Créer le groupe") { Task { busy = true; if await library.createGroup(name) { name = "" }; busy = false } }.disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }
            if let message = library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            Section("Mes groupes") {
                ForEach(Array(library.groups.enumerated()), id: \.offset) { _, group in
                    if let id = group["id"].string {
                        NavigationLink(group["name"].string ?? "Groupe") { GroupDetailView(id: id, title: group["name"].string ?? "Groupe") }
                    }
                }
                if library.groups.isEmpty { Text("Aucun groupe synchronisé").foregroundStyle(theme.muted) }
            }
        }.navigationTitle("Mes groupes").navigationBarTitleDisplayMode(.inline).task { await library.refreshGroups() }.refreshable { await library.refreshGroups() }
    }
}
private struct GroupDetailView: View {
    @EnvironmentObject var library: FriendsLibrary
    let id: String
    let title: String
    @State private var members: [JSONValue] = []
    @State private var busy = false
    private var own: JSONValue { members.first { $0["user_id"].string?.lowercased() == library.snapshot?.owner.uuidString.lowercased() } ?? .null }
    var body: some View {
        List {
            if own != .null && own["accepted_at"] == .null {
                Button("Accepter l’invitation") { perform("accept_group_invite") }
                Button("Refuser l’invitation", role: .destructive) { perform("decline_group_invite") }
            }
            Section("Membres") {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    VStack(alignment: .leading) {
                        Text(member["name"].string ?? "Membre")
                        Text(member["accepted_at"] == .null ? "Invitation en attente" : member["role"].string == "owner" ? "Créateur" : member["role"].string == "moderator" ? "Modérateur" : "Membre").font(.caption)
                    }
                }
            }
            if ["owner", "moderator"].contains(own["role"].string ?? "") && own["accepted_at"] != .null {
                Section("Inviter un ami") {
                    ForEach(library.snapshot?.items() ?? []) { friend in
                        Button(friend.name) { perform("invite_group_member", friend: friend.otherID) }
                    }
                }
            }
            if let message = library.message { Text(message).font(.caption) }
        }.disabled(busy).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .task { members = await library.groupMembers(id) }.refreshable { members = await library.groupMembers(id) }
    }
    private func perform(_ action: String, friend: String? = nil) {
        Task { busy = true; _ = await library.groupAction(action, id: id, friend: friend); members = await library.groupMembers(id); busy = false }
    }
}
