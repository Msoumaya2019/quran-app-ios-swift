import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var quiz: QuizLibrary
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
                    NavigationLink("Profil ami et confidentialité") { SocialProfileSettingsView() }.accessibilityIdentifier("settings.social.open")
                }
                Section("Mes contenus") {
                    NavigationLink("Rappels et invocations favoris") { ContentFavoritesView() }.accessibilityIdentifier("settings.content.favorites")
                }
                Section("Corans") {
                    Picker("Coran sélectionné", selection: Binding(get: { store.snapshot.state["reader"]["mushaf"].string ?? QuranSource.medina.id }, set: { source in
                        let page = store.snapshot.state["lastRead"]["page"].int ?? 1
                        _ = store.readerChange(ReaderOperation(kind: .source, verseID: 1, page: page, source: source))
                    })) { ForEach(QuranSource.available) { source in Text(source.displayName).tag(source.id) } }
                    Text("Coran Tajweed").font(.headline)
                    TajweedDownloadProgress()
                    Text("Les ressources Tajweed ne sont pas incluses dans l’application. En ligne, les pages se chargent à la demande.").font(.caption).foregroundStyle(theme.muted)
                }
                Section("Mon programme") {
                    NavigationLink { ProgramEditorView(state: store.snapshot.state) } label: {
                        Label("Modifier mon programme", systemImage: "calendar.badge.clock").frame(minHeight: 44)
                    }.accessibilityIdentifier("settings.program.open")
                    NavigationLink { RevisionSettingsView(state: store.snapshot.state) } label: {
                        Label("Modifier mes révisions", systemImage: "arrow.triangle.2.circlepath").frame(minHeight: 44)
                    }.accessibilityIdentifier("settings.revision.open")
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
                    Text("Lecteur natif • SwiftUI et UIKit • iOS 17 et versions ultérieures")
                    Text("Coran de Médine, Coran 1441, apprentissage, révisions, amis, messagerie et Quiz natif.").font(.caption).foregroundStyle(theme.muted)
                }
                Section("Notifications") {
                    NavigationLink("Notifications et rappels") { ReminderSettingsView() }.accessibilityIdentifier("settings.reminders.open")
                }
                if quiz.isAdmin { Section("Administration") {
                    NavigationLink("Rappels et invocations") { EditorialAdminView() }.accessibilityIdentifier("settings.admin.contents")
                    NavigationLink("Récitations à écouter") { ModerationView(section: .recitations) }.accessibilityIdentifier("settings.admin.recitations")
                    NavigationLink("Comptes · espace amis") { SocialAccountsAdminView() }
                    NavigationLink("Modération des messages") { ModerationView(section: .messages) }.accessibilityIdentifier("settings.admin.messages")
                    NavigationLink("Quiz · Questions et thèmes") { QuizAdminView() }
                    NavigationLink("Signalements") { ProblemReportsAdminView() }
                } }
                if let error { Text(error).foregroundStyle(.red) }
                Section { Button("Se déconnecter", role: .destructive) { Task { signingOut = true; defer { signingOut = false }; do { try await store.signOut(); dismiss() } catch { self.error = error.localizedDescription } } }.disabled(signingOut) }
            }.navigationTitle("Réglages").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() }.frame(minHeight: 44) } }
        }.presentationDragIndicator(.visible).task { await quiz.checkAdmin() }
    }
}
