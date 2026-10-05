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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var library: FriendsLibrary
    let id: String
    let title: String
    @State private var members: [JSONValue] = []
    @State private var removal: String?
    @State private var confirming = false
    @State private var deleting = false
    @State private var busy = false
    private var own: JSONValue { members.first { $0["user_id"].string?.lowercased() == library.snapshot?.owner.uuidString.lowercased() } ?? .null }
    var body: some View {
        List {
            if own["accepted_at"] != .null, own != .null, let room = library.groupConversation(id) {
                NavigationLink("Conversation du groupe") { ConversationView(name: title, owner: room.owner, link: room.link, remote: room.remote, group: true) }
            }
            if own != .null && own["accepted_at"] == .null {
                Button("Accepter l’invitation") { perform("accept_group_invite") }
                Button("Refuser l’invitation", role: .destructive) { perform("decline_group_invite") }
            }
            Section("Membres") {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    VStack(alignment: .leading) {
                        Text(member["name"].string ?? "Membre")
                        Text(member["accepted_at"] == .null ? "Invitation en attente" : member["role"].string == "owner" ? "Créateur" : member["role"].string == "moderator" ? "Modérateur" : "Membre").font(.caption)
                        if own["role"].string == "owner", member["role"].string != "owner", member["accepted_at"] != .null, let user = member["user_id"].string {
                            Button(member["role"].string == "moderator" ? "Retirer le rôle de modérateur" : "Nommer modérateur") { Task { busy = true; _ = await library.groupMemberAction("set_group_moderator", group: id, member: user, enabled: member["role"].string != "moderator"); members = await library.groupMembers(id); busy = false } }
                        }
                        if ["owner", "moderator"].contains(own["role"].string ?? ""), member["role"].string != "owner", let user = member["user_id"].string {
                            Button("Retirer du groupe", role: .destructive) { removal = user; confirming = true }
                        }
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
            if own["role"].string == "owner" { Button("Supprimer le groupe", role: .destructive) { deleting = true } }
            else if own["accepted_at"] != .null, let user = own["user_id"].string { Button("Quitter le groupe", role: .destructive) { removal = user; confirming = true } }
        }.disabled(busy).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .task { members = await library.groupMembers(id) }.refreshable { members = await library.groupMembers(id) }
            .confirmationDialog("Retirer ce membre du groupe ?", isPresented: $confirming) {
                Button("Confirmer", role: .destructive) { Task { busy = true; let ok = await library.groupMemberAction("remove_group_member", group: id, member: removal); if ok && removal?.lowercased() == library.snapshot?.owner.uuidString.lowercased() { dismiss() }; members = await library.groupMembers(id); busy = false } }
            }
            .confirmationDialog("Supprimer définitivement ce groupe ?", isPresented: $deleting) {
                Button("Supprimer", role: .destructive) { Task { busy = true; if await library.groupMemberAction("delete_friend_group", group: id, member: nil) { await library.refreshGroups(); dismiss() }; busy = false } }
            }
    }
    private func perform(_ action: String, friend: String? = nil) {
        Task { busy = true; _ = await library.groupAction(action, id: id, friend: friend); members = await library.groupMembers(id); busy = false }
    }
}
