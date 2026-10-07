import SwiftUI

struct AudioRepeatSheet: View {
    @ObservedObject var audio: QuranAudioService
    let catalog: QuranCatalog
    let pageRange: ClosedRange<Int>
    let sessionRange: ClosedRange<Int>?
    let save: (AudioRepeatSettings) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var initialized = false
    @State private var settings = AudioRepeatSettings()
    @State private var selection = "verse"
    @State private var surahNumber = 1
    @State private var first = 1
    @State private var last = 1
    private var surah: Surah? { catalog.surahs.first { $0.number == surahNumber } }
    private var range: ClosedRange<Int>? {
        switch selection {
        case "remaining": return audio.verseID...6236
        case "page": return pageRange
        case "session": return sessionRange
        case "surah": return surah.map { $0.start...$0.end }
        case "custom":
            guard let surah, first >= 1, last >= first, last <= surah.count else { return nil }
            return (surah.start + first - 1)...(surah.start + last - 1)
        default: return audio.verseID...audio.verseID
        }
    }
    private func applyRange() {
        guard initialized, let range else { return }
        settings.rangeStart = range.lowerBound; settings.rangeEnd = range.upperBound; settings.selection = selection
        audio.updateRange(range)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Passage à écouter") {
                    Picker("Sélection", selection: $selection) {
                        Text("Ce verset").tag("verse"); Text("Toute la page").tag("page")
                        if sessionRange != nil { Text("Ma séance").tag("session") }
                        Text("Toute la sourate").tag("surah"); Text("Passage personnalisé").tag("custom")
                        Text("Continuer depuis ce verset").tag("remaining")
                    }
                    if selection == "surah" || selection == "custom" {
                        Picker("Sourate", selection: $surahNumber) { ForEach(catalog.surahs, id: \.number) { Text($0.name).tag($0.number) } }
                            .onChange(of: surahNumber) { _, _ in first = 1; last = surah?.count ?? 1 }
                        if selection == "custom" {
                            Stepper("Premier verset : \(first)", value: $first, in: 1...(surah?.count ?? 1))
                            Stepper("Dernier verset : \(last)", value: $last, in: 1...(surah?.count ?? 1))
                        }
                    }
                }
                Section("Répétitions") {
                    Picker("Mode", selection: $settings.mode) { Text("Chaque verset").tag(AudioRepeatSettings.Mode.eachVerse); Text("Passage complet").tag(AudioRepeatSettings.Mode.passage) }
                    Stepper("Nombre de répétitions : \(settings.countLabel)", value: $settings.count, in: 0...999).accessibilityIdentifier("quran.audio.repeat.count")
                    if settings.count == 0 { Text("Répétition en continu").font(.caption).foregroundStyle(.secondary) }
                    Picker("Pause entre répétitions", selection: $settings.gap) { ForEach([0, 1, 2, 3, 5, 10], id: \.self) { Text($0 == 0 ? "Aucune" : "\($0) secondes").tag($0) } }
                    Picker("Vitesse", selection: $settings.speed) { ForEach([0.75, 0.85, 1, 1.15, 1.25], id: \.self) { Text("\($0, specifier: "%.3g")×").tag($0) } }.pickerStyle(.segmented).accessibilityIdentifier("quran.audio.speed")
                    Picker("Après les répétitions", selection: Binding(get: { settings.ending }, set: { settings.after = $0 })) {
                        Text("Arrêter").tag(AudioRepeatSettings.After.stop)
                        Text("Passer au verset suivant").tag(AudioRepeatSettings.After.nextVerse)
                        Text("Continuer la lecture").tag(AudioRepeatSettings.After.continuous)
                    }
                    Picker("Pause pour réciter", selection: Binding(get: { settings.recitePause ?? 0 }, set: { settings.recitePause = $0 })) {
                        ForEach([0, 3, 5, 10, 15], id: \.self) { Text($0 == 0 ? "Désactivée" : "\($0) secondes").tag($0) }
                    }
                }
                Section {
                    if range == nil { Text("Choisis une plage de versets valide.").foregroundStyle(.secondary) }
                }
            }.navigationTitle("Réglages audio").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
                .onAppear {
                    settings = audio.repeatSettings
                    settings.after = settings.ending
                    if let chapter = catalog.surah(for: audio.verseID) { surahNumber = chapter.number; first = audio.verseID - chapter.start + 1; last = first }
                    selection = settings.selection ?? (audio.playbackRange == pageRange ? "page" : audio.playbackRange == sessionRange ? "session" : "verse")
                    if selection == "session" && sessionRange == nil { selection = "verse" }
                    if sessionRange == audio.playbackRange { selection = "session" }
                    if let start = settings.rangeStart, let end = settings.rangeEnd, let chapter = catalog.surah(for: start), catalog.surah(for: end)?.number == chapter.number {
                        surahNumber = chapter.number; first = start - chapter.start + 1; last = end - chapter.start + 1
                    }
                    initialized = true
                    applyRange()
                }
        }.onChange(of: settings) { _, value in if initialized { save(value); audio.configure(value) } }
            .onChange(of: selection) { _, _ in applyRange() }
            .onChange(of: surahNumber) { _, _ in applyRange() }
            .onChange(of: first) { _, _ in applyRange() }
            .onChange(of: last) { _, _ in applyRange() }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
