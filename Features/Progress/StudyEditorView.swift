import SwiftUI

struct PassageKnowledgeEditorView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var surahNumber = 1
    @State private var first = 1
    @State private var last = 1
    @State private var action = StudyCorrection.Action.learned
    @State private var date = Date.now
    @State private var message: String?
    private var surah: Surah? { store.catalog.surahs.first { $0.number == surahNumber } }
    var body: some View {
        Form {
            Section {
                Text("Corrige une sourate entière ou une plage de versets. Les modifications sont enregistrées sur cet appareil puis synchronisées avec ton compte.").font(.caption)
                NavigationLink("Modifier mes révisions effectuées") { ReviewHistoryEditorView() }
            }
            Section("Passage à modifier") {
                Picker("Sourate", selection: Binding(get: { surahNumber }, set: { first = 1; last = 1; surahNumber = $0 })) { ForEach(store.catalog.surahs, id: \.number) { Text($0.name).tag($0.number) } }
                if let surah {
                    let count = surah.end - surah.start + 1
                    Picker("Premier verset", selection: Binding(get: { first }, set: { first = $0; last = max(last, $0) })) { ForEach(1...count, id: \.self) { Text(String($0)).tag($0) } }
                    Picker("Dernier verset", selection: $last) { ForEach(first...count, id: \.self) { Text(String($0)).tag($0) } }
                    Button("Toute la sourate") { first = 1; last = count }
                    let ids = (surah.start + first - 1)...(surah.start + max(first, last) - 1)
                    Text("\(ids.filter { ["perfect", "review"].contains(store.snapshot.state["knowledge"][String($0)].string ?? "") }.count) / \(ids.count) versets actuellement connus").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Nouveau statut") {
                Picker("Connaissance", selection: $action) {
                    Text("Appris").tag(StudyCorrection.Action.learned)
                    Text("Connu, à réviser").tag(StudyCorrection.Action.review)
                    Text("Pas encore appris").tag(StudyCorrection.Action.unlearned)
                }
                if action != .unlearned { DatePicker("Date d’apprentissage", selection: $date, in: ...Date.now, displayedComponents: .date) }
                Text("Le programme conserve ses dates prévues. Un passage retiré des connaissances redevient à apprendre ; une nouvelle date d’apprentissage recalcule ses consolidations J+1, J+3 et J+7.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Enregistrer les modifications") { save() }.frame(minHeight: 44).accessibilityIdentifier("study.editor.save")
                if let message { Text(message).font(.caption).accessibilityIdentifier("study.editor.result") }
            }
        }.navigationTitle("Modifier mes connaissances").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
            .onChange(of: surahNumber) { _, _ in first = 1; last = 1; message = nil }
            .onChange(of: first) { _, value in if last < value { last = value } }
    }
    private func save() {
        guard let surah else { return }
        let change = StudyCorrection(action: action, start: surah.start + first - 1, end: surah.start + max(first, last) - 1, date: date)
        var operation = ReaderOperation(kind: .studyCorrection, verseID: change.start, page: store.catalog.page(for: change.start), source: "")
        operation.studyCorrection = change
        if store.readerChange(operation) { message = "Modifications enregistrées. Synchronisation automatique dès que possible."; Task { await store.refresh() } }
        else { message = "Modification non enregistrée. Les données ont peut-être changé : actualise puis réessaie." }
    }
}

struct ReviewHistoryEditorView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section { NavigationLink("Ajouter une révision effectuée") { ReviewCorrectionView(original: nil) } }
            Section("Révisions effectuées") {
                let rows = store.snapshot.state["reviewHistory"].array
                if rows.isEmpty { Text("Aucune révision enregistrée.").foregroundStyle(.secondary) }
                ForEach(Array(rows.enumerated().reversed()), id: \.offset) { _, row in
                    if let range = VerseRange(json: row) {
                        NavigationLink { ReviewCorrectionView(original: row) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(store.catalog.surah(for: range.start)?.name ?? "Passage") · \(store.catalog.reference(range))")
                                Text(row["date"].string ?? "Date non renseignée").font(.caption).foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }
                    }
                }
            }
        }.navigationTitle("Mes révisions effectuées").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReviewCorrectionView: View {
    let original: JSONValue?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var surahNumber = 1
    @State private var first = 1
    @State private var last = 1
    @State private var date = Date.now
    @State private var message: String?
    @State private var removing = false
    @State private var loaded = false
    @State private var changePassage = false
    private var range: VerseRange? {
        if !changePassage, let original { return VerseRange(json: original) }
        guard let surah = store.catalog.surahs.first(where: { $0.number == surahNumber }) else { return nil }
        return VerseRange(json: .object(["start": .number(Double(surah.start + first - 1)), "end": .number(Double(surah.start + max(first, last) - 1))]))
    }
    var body: some View {
        Form {
            Section("Passage") {
                if let range { Text(store.catalog.reference(range)) }
                if original != nil { Toggle("Corriger le passage", isOn: $changePassage) }
                if original == nil || changePassage {
                    Picker("Sourate", selection: Binding(get: { surahNumber }, set: { first = 1; last = 1; surahNumber = $0 })) { ForEach(store.catalog.surahs, id: \.number) { Text($0.name).tag($0.number) } }
                    if let surah = store.catalog.surahs.first(where: { $0.number == surahNumber }) {
                        Picker("Premier verset", selection: Binding(get: { first }, set: { first = $0; last = max(last, $0) })) { ForEach(1...(surah.end - surah.start + 1), id: \.self) { Text(String($0)).tag($0) } }
                        Picker("Dernier verset", selection: $last) { ForEach(first...(surah.end - surah.start + 1), id: \.self) { Text(String($0)).tag($0) } }
                    }
                }
                DatePicker("Révision effectuée le", selection: $date, in: ...Date.now, displayedComponents: .date)
                Text("Seuls les versets déjà connus peuvent être enregistrés comme révisés. La date prévue d’une séance existante reste inchangée.").font(.caption)
            }
            Section {
                Button("Enregistrer") { save(remove: false) }.frame(minHeight: 44)
                if original != nil { Button("Annuler cette validation", role: .destructive) { removing = true }.frame(minHeight: 44) }
                if let message { Text(message).font(.caption) }
            }
        }.navigationTitle(original == nil ? "Ajouter une révision" : "Corriger une révision").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !loaded else { return }; loaded = true
                if let day = original?["date"].string {
                    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
                    date = min(f.date(from: day) ?? .now, .now)
                }
            }
            .onChange(of: surahNumber) { _, _ in first = 1; last = 1 }
            .onChange(of: first) { _, value in if last < value { last = value } }
            .confirmationDialog("Annuler cette validation ?", isPresented: $removing, titleVisibility: .visible) {
                Button("Annuler la validation", role: .destructive) { save(remove: true) }
                Button("Conserver", role: .cancel) {}
            } message: { Text("Cette révision sera retirée des statistiques et le passage pourra être revu. Les connaissances, les versets difficiles et les consolidations déjà validées seront conservés.") }
    }
    private func save(remove: Bool) {
        guard let range = remove ? original.flatMap({ VerseRange(json: $0) }) : range else { return }
        let change = StudyCorrection(action: remove ? .removeRevision : .revised, start: range.start, end: range.end, date: date, original: original)
        var operation = ReaderOperation(kind: .studyCorrection, verseID: range.start, page: store.catalog.page(for: range.start), source: "")
        operation.studyCorrection = change
        if store.readerChange(operation) { dismiss(); Task { await store.refresh() } }
        else { message = "Vérifie que le passage est connu et qu’il n’a pas déjà été révisé ce jour-là. Si l’historique a changé sur un autre appareil, actualise puis réessaie." }
    }
}
