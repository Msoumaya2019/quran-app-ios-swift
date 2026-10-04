import SwiftUI

struct RevisionValidationView: View {
    let context: QuranSessionContext
    let source: QuranSource
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var through: Int
    @State private var confirm = false
    @State private var grade = RevisionGrade.perfect
    @State private var message: String?
    init(context: QuranSessionContext, source: QuranSource, firstPending: Int) {
        self.context = context; self.source = source
        _through = State(initialValue: min(context.range.end, max(context.range.start, firstPending)))
    }
    private var count: Int { RevisionValidation.completedCount(context: context, state: store.snapshot.state) }
    private var pending: Int { context.range.start + count }
    private func verseLabel(_ id: Int) -> String {
        guard let surah = store.catalog.surah(for: id) else { return "Verset \(id)" }
        return "\(surah.name) · verset \(id - surah.start + 1)"
    }
    var body: some View {
        Form {
            if let message { Section { Text(message).font(.subheadline).accessibilityIdentifier("revision.result") } }
            Section("Séance prévue") {
                Text(ProgramProjection(snapshot: store.snapshot).dateLabel(context.scheduledDate))
                Text("\(count) / \(context.range.count) versets validés")
                Text("\(verseLabel(context.range.start)) → \(verseLabel(context.range.end))").font(.caption)
            }
            if pending <= context.range.end {
                Section("J’ai révisé jusqu’ici") {
                    Stepper(verseLabel(through), value: $through, in: pending...context.range.end)
                        .accessibilityIdentifier("revision.through")
                    Text("Seuls les versets encore à réviser, jusqu’au verset choisi inclus, seront validés.").font(.caption)
                    Picker("Comment s’est passée la révision ?", selection: $grade) {
                        ForEach(RevisionGrade.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Button("Valider ma révision") { confirm = true }
                        .frame(minHeight: 44).foregroundStyle(theme.accent)
                        .accessibilityIdentifier("revision.validate")
                }
            } else {
                Section { Label("Séance terminée", systemImage: "checkmark.circle.fill").foregroundStyle(theme.accent) }
            }
        }
        .navigationTitle("Valider la révision").navigationBarTitleDisplayMode(.inline)
        .onChange(of: pending) { _, value in through = min(context.range.end, max(value, through)) }
        .confirmationDialog("Valider jusqu’à \(verseLabel(through)) ?", isPresented: $confirm, titleVisibility: .visible) {
            Button("J’ai révisé jusqu’ici") {
                guard let validation = RevisionValidation(context: context, through: through, grade: grade, state: store.snapshot.state, source: source, catalog: store.catalog) else { return }
                var operation = ReaderOperation(kind: .revision, verseID: through, page: validation.page, source: source.id)
                operation.revision = validation
                guard validation.applying(to: store.snapshot.state) != store.snapshot.state else {
                    message = "Cette séance a changé ou ce passage est déjà validé. Reviens au programme."; return
                }
                if store.readerChange(operation) {
                    message = "Révision enregistrée. La date prévue reste inchangée."
                    Task { await store.refresh() }
                } else { message = "Impossible d’enregistrer la validation sur cet appareil. Réessaie." }
            }
            Button("Annuler", role: .cancel) { }
        } message: { Text("Les validations précédentes et les prochaines séances seront conservées.") }
    }
}
