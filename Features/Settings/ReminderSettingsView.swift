import SwiftUI
import UIKit

struct ReminderSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var reminders: LocalReminderService
    @EnvironmentObject private var theme: ThemeManager
    @State private var error: String?
    private var preferences: ReminderSettings { ReminderSettings.load(store.snapshot.state) }
    private func save(_ value: ReminderSettings) {
        var operation = ReaderOperation(kind: .reminders, verseID: 1, page: 1, source: "native")
        operation.reminders = value
        error = store.readerChange(operation) ? nil : "Les préférences n’ont pas pu être enregistrées."
    }
    private func enabled(_ learning: Bool) -> Binding<Bool> {
        Binding(get: { learning ? preferences.learning : preferences.revision }, set: { enabled in
            var value = preferences; if learning { value.learning = enabled } else { value.revision = enabled }; save(value)
        })
    }
    private func time(_ learning: Bool) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: learning ? preferences.learningHour : preferences.revisionHour, minute: learning ? preferences.learningMinute : preferences.revisionMinute, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date); var value = preferences
            if learning { value.learningHour = parts.hour ?? 19; value.learningMinute = parts.minute ?? 0 }
            else { value.revisionHour = parts.hour ?? 20; value.revisionMinute = parts.minute ?? 0 }; save(value)
        })
    }
    var body: some View {
        Form {
            Section("Autorisation iOS") {
                Label(reminders.permission ? "Notifications autorisées" : "Notifications désactivées sur cet iPhone", systemImage: reminders.permission ? "bell.badge" : "bell.slash")
                Button("Autoriser les notifications") { Task { await reminders.authorize() } }.frame(minHeight: 44)
                Button("Ouvrir les réglages iOS") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.frame(minHeight: 44)
            }
            Section("Apprentissage") {
                Toggle("Rappel quotidien d’apprentissage", isOn: enabled(true)).accessibilityIdentifier("reminders.learning")
                DatePicker("Heure", selection: time(true), displayedComponents: .hourAndMinute).disabled(!preferences.learning)
            }
            Section("Révision") {
                Toggle("Rappel quotidien de révision", isOn: enabled(false)).accessibilityIdentifier("reminders.revision")
                DatePicker("Heure", selection: time(false), displayedComponents: .hourAndMinute).disabled(!preferences.revision)
            }
            Section {
                Text("Ces rappels quotidiens fonctionnent hors connexion. Un appui sur la notification ouvre Programme. Les horaires suivent l’heure locale de l’iPhone.").font(.caption).foregroundStyle(theme.muted)
                Text("Les notifications de messages, défis et corrections seront activées avec la configuration native APNs.").font(.caption).foregroundStyle(theme.muted)
            }
            if let message = error ?? reminders.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
        }.navigationTitle("Notifications et rappels").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
            .task { reminders.update(owner: store.identity?.id, settings: preferences, force: true) }
    }
}
