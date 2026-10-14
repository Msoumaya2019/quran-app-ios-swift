import SwiftUI

/// Reuses the existing social profile, secure avatars and canonical knowledge state.
struct MyProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var friends: FriendsLibrary
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    private var progress: ProgressProjection { ProgressProjection(state: store.snapshot.state) }
    private var name: String { friends.snapshot?.profile["display_name"].string ?? HomeProjection(snapshot: store.snapshot).name }
    private var completeSurahs: Int { progress.completeSurahs(catalog: store.catalog) }
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let owner = store.identity?.id { FriendAvatarView(user: owner, name: name, size: 64) }
                    VStack(alignment: .leading) { Text(name).font(theme.title()); Text(store.identity?.email ?? "").font(.caption).foregroundStyle(theme.muted) }
                }.padding(.vertical, 8)
                NavigationLink("Modifier mon profil et ma confidentialité") { SocialProfileSettingsView() }
            }
            Section("Ma mémorisation") {
                LabeledContent("Versets connus", value: "\(progress.known.count) / 6236")
                LabeledContent("Sourates complètes", value: "\(completeSurahs) / 114")
                ProgressView(value: Double(progress.known.count) / 6236).tint(theme.accent)
            }
            Section("Mon objectif") {
                Text(store.snapshot.state["goal"]["label"].string ?? "Aucun objectif défini")
                NavigationLink("Modifier mon programme") { ProgramEditorView(state: store.snapshot.state) }
            }
            Section("Mon espace") {
                NavigationLink("Mes récitations") { RecitationsView() }
                NavigationLink("Mes amis") { FriendsView() }
            }
        }.navigationTitle("Mon profil").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("profile.screen")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
    }
}
