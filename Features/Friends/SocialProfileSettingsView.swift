import SwiftUI

struct SocialProfileSettingsView: View {
    @EnvironmentObject private var library: FriendsLibrary
    @EnvironmentObject private var theme: ThemeManager
    @State private var name = ""
    @State private var online = false
    @State private var progress = false
    @State private var initialized = false
    @State private var busy = false
    @State private var saved = false
    var body: some View {
        Form {
            Section("Mon profil ami") {
                TextField("Nom affiché", text: $name).accessibilityIdentifier("social.profile.name")
                Text("Entre 2 et 40 caractères.").font(.caption).foregroundStyle(theme.muted)
            }
            Section("Partage avec mes amis") {
                Toggle("Partager mon statut en ligne", isOn: $online).accessibilityIdentifier("social.profile.online")
                Toggle("Partager ma progression", isOn: $progress).accessibilityIdentifier("social.profile.progress")
                Text("Ces préférences sont communes aux deux applications et seront appliquées après confirmation du serveur.").font(.caption).foregroundStyle(theme.muted)
            }
            if let message = library.message { Text(message).font(.caption) }
            if saved { Label("Préférences enregistrées", systemImage: "checkmark.circle").foregroundStyle(theme.accent) }
            Button("Enregistrer") {
                Task { busy = true; saved = false; saved = await library.saveSocialProfile(name: name, online: online, progress: progress); busy = false }
            }.disabled(busy || !(2...40).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count))
                .accessibilityIdentifier("social.profile.save")
        }.navigationTitle("Profil et confidentialité").navigationBarTitleDisplayMode(.inline)
            .task {
                guard !initialized else { return }; initialized = true
                let profile = library.snapshot?.profile ?? .null
                name = profile["display_name"].string ?? ""
                online = profile["share_online"].bool == true
                progress = profile["share_progress"].bool == true
            }
    }
}
