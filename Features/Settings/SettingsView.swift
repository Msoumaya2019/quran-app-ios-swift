import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var error: String?
    @State private var signingOut = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Mon compte") {
                    Text(store.identity?.email ?? "Compte connecté")
                    if let id = store.identity?.id { Text(id.uuidString).font(.caption).textSelection(.enabled) }
                    Button("Actualiser mes données") { Task { await store.refresh() } }.disabled(store.isRefreshing)
                }
                Section("Apparence") {
                    Picker("Thème de l’application", selection: $theme.name) {
                        Text("Thème blanc").tag("white"); Text("Thème vert").tag("classic"); Text("Thème rose").tag("feminine"); Text("Lilas & Perle").tag("lilac"); Text("Bleu Nuit & Or").tag("night")
                    }
                    Picker("Couleur d’accent", selection: $theme.accentName) { Text("Prune").tag("prune"); Text("Rose").tag("rose"); Text("Vert").tag("green"); Text("Doré").tag("gold") }
                    Picker("Police d’interface", selection: $theme.fontName) { Text("Système iOS").tag("system"); Text("Élégante").tag("elegant"); Text("Classique").tag("classic") }
                    Text("Les choix d’apparence de cette version de test sont conservés sur cet appareil. Ils ne modifient pas l’application React Native.").font(.caption).foregroundStyle(theme.muted)
                }
                Section("Version native") {
                    Text("Phase 1 • SwiftUI • iOS 17 et versions ultérieures")
                    Text("Le lecteur, les programmes interactifs, les amis et le quiz seront migrés après validation de cette phase.").font(.caption).foregroundStyle(theme.muted)
                }
                if let error { Text(error).foregroundStyle(.red) }
                Section { Button("Se déconnecter", role: .destructive) { Task { signingOut = true; defer { signingOut = false }; do { try await store.signOut(); dismiss() } catch { self.error = error.localizedDescription } } }.disabled(signingOut) }
            }.navigationTitle("Réglages").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() }.frame(minHeight: 44) } }
        }.presentationDragIndicator(.visible)
    }
}
