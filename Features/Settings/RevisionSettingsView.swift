import SwiftUI

struct RevisionSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var preferences: RevisionPreferences
    @State private var result: String?
    init(state: JSONValue) { _preferences = State(initialValue: RevisionPreferences(state: state)) }
    var body: some View {
        Form {
            Section {
                Toggle("Activer les révisions", isOn: $preferences.enabled).accessibilityIdentifier("revision.settings.enabled")
                Text("Seules les parties déjà connues sont programmées. Les nouveaux versets restent en consolidation avant d’entrer dans un cycle.").font(.caption).foregroundStyle(theme.muted)
            }
            Section("Mon rythme") {
                Picker("Programme", selection: $preferences.mode) {
                    Text("Cycle temporel").tag("cycle"); Text("Quantité quotidienne").tag("quantity")
                }.pickerStyle(.segmented).accessibilityIdentifier("revision.settings.mode")
                if preferences.mode == "cycle" {
                    Picker("Durée du cycle", selection: $preferences.cycleDays) {
                        ForEach([7, 14, 21, 30], id: \.self) { Text("\($0) jours").tag($0) }
                    }.accessibilityIdentifier("revision.settings.days")
                } else {
                    Picker("Quantité par jour", selection: $preferences.dailyQuantity) {
                        Text("1 Nisf").tag("nisf"); Text("1 Hizb").tag("hizb"); Text("1 Juz’").tag("juz"); Text("2 Juz’").tag("juz2")
                    }.accessibilityIdentifier("revision.settings.quantity")
                }
                Text("Un changement de rythme crée un nouveau cycle et conserve le précédent dans l’historique. Les dates des séances déjà effectuées restent inchangées.").font(.caption).foregroundStyle(theme.muted)
            }
            Section {
                Button("Enregistrer mes révisions") { save() }.frame(minHeight: 44).accessibilityIdentifier("revision.settings.save")
                if let result { Text(result).font(.subheadline).accessibilityIdentifier("revision.settings.result") }
            }
        }.navigationTitle("Mes révisions").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
    }
    private func save() {
        guard preferences != RevisionPreferences(state: store.snapshot.state) else { result = "Tes réglages sont déjà enregistrés."; return }
        var operation = ReaderOperation(kind: .reviewSchedule, verseID: 1, page: 1, source: "")
        operation.reviewSchedule = RevisionScheduleChange(preferences: preferences)
        if store.readerChange(operation) {
            result = "Révisions enregistrées. \(preferences.title)."
            Task { await store.refresh() }
        } else { result = "Les réglages n’ont pas pu être enregistrés sur l’appareil." }
    }
}
