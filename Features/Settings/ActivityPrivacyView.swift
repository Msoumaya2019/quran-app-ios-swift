import SwiftUI

struct ActivityPrivacyView: View {
    @EnvironmentObject private var usage: UserActivityService
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Form {
            Section("Statistiques d’utilisation facultatives") {
                Text("Si tu participes, le compte administrateur désigné pourra consulter ta dernière activité, ton temps actif au premier plan et le nombre de sessions. Aucun contenu lu, message ou identifiant d’appareil n’est enregistré. Les données de suivi sont conservées au maximum 30 jours. Tu peux retirer ta participation et effacer ces données ici.")
                if usage.available {
                    Toggle("Participer au suivi d’utilisation", isOn: Binding(get: { usage.consenting }, set: { value in Task { await usage.consent(value); usage.phase(active: phase == .active) } }))
                } else { Text("Le suivi est désactivé. Il nécessite la validation de l’information de confidentialité par le responsable de l’application.").foregroundStyle(.secondary) }
                if let message = usage.message { Text(message).font(.caption) }
            }
        }.navigationTitle("Confidentialité · utilisation").navigationBarTitleDisplayMode(.inline)
            .task { await usage.select(store.identity?.id) }
    }
}
