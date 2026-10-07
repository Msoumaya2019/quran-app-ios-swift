import SwiftUI

struct VoiceRecorderView: View {
    let user: UUID
    let catalog: QuranCatalog
    let invocation: DailyContent?
    @EnvironmentObject private var library: RecitationLibrary
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var recorder = VoiceRecorderService()
    @State private var surahNumber: Int
    @State private var first: Int
    @State private var last: Int
    @State private var saving = false
    @State private var saveError: String?
    @State private var discardConfirmation = false
    init(user: UUID, catalog: QuranCatalog, firstVerse: Int, lastVerse: Int, invocation: DailyContent? = nil) {
        self.user = user; self.catalog = catalog; self.invocation = invocation
        let surah = catalog.surah(for: firstVerse) ?? catalog.surahs[0]
        _surahNumber = State(initialValue: surah.number)
        _first = State(initialValue: firstVerse - surah.start + 1)
        _last = State(initialValue: min(surah.end, max(firstVerse, lastVerse)) - surah.start + 1)
    }
    private var surah: Surah { catalog.surahs.first { $0.number == surahNumber } ?? catalog.surahs[0] }
    private var locked: Bool { recorder.recording || recorder.requesting || recorder.draft != nil || saving }
    var body: some View {
        NavigationStack {
            Form {
                if let invocation {
                    Section("Invocation récitée") {
                        Text(invocation.title ?? "Invocation")
                        if let arabic = invocation.arabic_text { Text(arabic).font(.title3).frame(maxWidth: .infinity, alignment: .trailing) }
                        Text(invocation.french_text); Text(invocation.source).font(.caption).foregroundStyle(theme.muted)
                    }
                } else {
                Section("Passage récité") {
                    Picker("Sourate", selection: $surahNumber) { ForEach(catalog.surahs, id: \.number) { Text($0.name).tag($0.number) } }
                    Stepper("Premier verset : \(first)", value: $first, in: 1...surah.count)
                    Stepper("Dernier verset : \(last)", value: $last, in: first...max(first, surah.count))
                }.disabled(locked)
                }
                Section {
                    Text(QuranAudioTimeline.timeLabel(recorder.elapsed)).font(.system(size: 32, weight: .medium, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    if recorder.recording {
                        Button { recorder.stop() } label: { Label("Terminer l’enregistrement", systemImage: "stop.circle.fill").frame(maxWidth: .infinity, minHeight: 44) }.accessibilityIdentifier("recitation.stop")
                    } else if recorder.draft == nil {
                        Button { Task { await recorder.start() } } label: { Label(recorder.requesting ? "Autorisation du microphone…" : "Commencer l’enregistrement", systemImage: "mic.fill").frame(maxWidth: .infinity, minHeight: 44) }.disabled(recorder.requesting).accessibilityIdentifier("recitation.start")
                    } else {
                        Button { recorder.togglePreview() } label: { Label(recorder.previewing ? "Arrêter la réécoute" : "Réécouter", systemImage: recorder.previewing ? "stop.fill" : "play.fill").frame(minHeight: 44) }
                        Button("Recommencer") { recorder.discard() }.frame(minHeight: 44).disabled(saving)
                        Button { Task { await save() } } label: { Label(saving ? "Enregistrement…" : "Conserver la récitation", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity, minHeight: 44) }.disabled(saving || recorder.elapsed <= 0).accessibilityIdentifier("recitation.save")
                    }
                } footer: {
                    Text("Ta récitation est conservée sur cet iPhone, puis synchronisée pour la correction lorsque la connexion est disponible. Durée maximale : 30 minutes.")
                }
                if let message = recorder.error ?? saveError { Section { Text(message).font(.footnote).foregroundStyle(theme.muted).accessibilityIdentifier("recitation.error") } }
            }.navigationTitle("Enregistrer ma voix").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { if recorder.draft != nil { discardConfirmation = true } else { dismiss() } }.disabled(recorder.recording || recorder.requesting || saving) } }
                .tint(theme.accent)
                .confirmationDialog("Supprimer cet essai non sauvegardé ?", isPresented: $discardConfirmation, titleVisibility: .visible) { Button("Supprimer l’essai", role: .destructive) { recorder.discard(); dismiss() }; Button("Garder l’essai", role: .cancel) {} }
        }
        .interactiveDismissDisabled(locked)
        .onChange(of: surahNumber) { _, _ in first = 1; last = surah.count }
        .onChange(of: first) { _, value in last = max(last, value) }
        .onChange(of: phase) { _, value in if value == .background { recorder.stop() } }
        .onChange(of: store.identity?.id) { _, value in if value != user { recorder.discard(); dismiss() } }
        .onDisappear { recorder.discard() }
    }
    private func save() async {
        guard let draft = recorder.draft, store.identity?.id == user else { return }
        saving = true; defer { saving = false }
        do {
            try await library.save(source: draft, start: invocation == nil ? surah.start + first - 1 : 0, end: invocation == nil ? surah.start + last - 1 : 0, durationMs: Int(recorder.elapsed * 1000), user: user, invocation: invocation)
            recorder.discard(); dismiss()
            Task { await library.synchronize() }
        } catch { saveError = "La récitation n’a pas pu être sauvegardée. Ton essai reste disponible ici pour réessayer." }
    }
}
