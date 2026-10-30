import SwiftUI

/// The same checklist model as the existing Expo onboarding, backed by canonical verse ranges.
struct StudyEditorView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var section = "juz"
    @State private var message: String?
    @State private var changeID = 0
    private var known: Set<Int> { ProgressProjection(state: store.snapshot.state).known }
    var body: some View {
        let learned = known
        List {
            Section {
                Text("Coche les parties que tu connais déjà par cœur. Décoche une partie pour la remettre à apprendre. Les autres connaissances sont conservées.").font(.caption).foregroundStyle(.secondary)
                Picker("Sélection rapide", selection: $section) {
                    Text("Juz’").tag("juz"); Text("Hizb").tag("hizb"); Text("Sourates").tag("surah")
                }.pickerStyle(.segmented).accessibilityIdentifier("knowledge.sections")
                Text("\(learned.count) / 6236 versets connus").font(.subheadline.weight(.semibold)).accessibilityIdentifier("knowledge.total")
                if let message { Text(message).font(.caption).accessibilityIdentifier("knowledge.result") }
            }
            Section("Passages partiellement mémorisés") {
                NavigationLink("Modifier un passage ou sa date d’apprentissage") { PassageKnowledgeEditorView() }.accessibilityIdentifier("knowledge.partial.open")
                NavigationLink("Modifier mes révisions effectuées") { ReviewHistoryEditorView() }
            }
            Section(section == "juz" ? "Juz’ déjà connus" : section == "hizb" ? "Hizb déjà connus" : "Sourates connues par cœur") {
                if section == "surah" {
                    ForEach(store.catalog.surahs, id: \.number) { surah in
                        row(title: "\(surah.number). \(surah.name)", subtitle: surah.meaning, start: surah.start, end: surah.end, identifier: "surah.\(surah.number)", known: learned)
                    }
                } else {
                    ForEach(section == "juz" ? store.catalog.juzs : store.catalog.hizbs) { division in
                        row(title: "\(section == "juz" ? "Juz’" : "Hizb") \(division.number)", subtitle: "\(division.end - division.start + 1) versets", start: division.start, end: division.end, identifier: "\(section).\(division.number)", known: learned)
                    }
                }
            }
        }.navigationTitle("Modifier mes connaissances").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
            .task(id: changeID) {
                guard changeID > 0 else { return }
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                await store.refresh()
            }
    }
    private func row(title: String, subtitle: String, start: Int, end: Int, identifier: String, known: Set<Int>) -> some View {
        let count = (start...end).filter { known.contains($0) }.count
        let complete = count == end - start + 1
        return Button {
            let change = StudyCorrection(action: complete ? .unlearned : .learned, start: start, end: end, date: .now, preserveKnown: true)
            var operation = ReaderOperation(kind: .studyCorrection, verseID: start, page: store.catalog.page(for: start), source: "")
            operation.studyCorrection = change
            if store.readerChange(operation) {
                message = complete ? "\(title) remis à apprendre." : "\(title) enregistré comme connu."
                changeID += 1
            } else { message = "Modification non enregistrée. Actualise puis réessaie." }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: complete ? "checkmark.square.fill" : count > 0 ? "minus.square" : "square")
                    .foregroundStyle(complete || count > 0 ? theme.accent : theme.muted).font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(theme.text)
                    Text(count > 0 && !complete ? "\(count) / \(end - start + 1) versets connus" : subtitle).font(.caption).foregroundStyle(theme.muted)
                }
                Spacer(minLength: 0)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("knowledge.\(identifier)")
            .accessibilityValue(complete ? "Connu" : count > 0 ? "Partiellement connu" : "À apprendre")
            .accessibilityHint(complete ? "Décoche cette partie" : "Coche cette partie comme connue")
    }
}
