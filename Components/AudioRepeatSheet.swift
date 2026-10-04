import SwiftUI

struct AudioRepeatSheet: View {
    @ObservedObject var audio: QuranAudioService
    let catalog: QuranCatalog
    let pageRange: ClosedRange<Int>
    let sessionRange: ClosedRange<Int>?
    let save: (AudioRepeatSettings) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AudioRepeatSettings()
    @State private var selection = "verse"
    @State private var surahNumber = 1
    @State private var first = 1
    @State private var last = 1
    private var surah: Surah? { catalog.surahs.first { $0.number == surahNumber } }
    private var range: ClosedRange<Int>? {
        switch selection {
        case "page": return pageRange
        case "session": return sessionRange
        case "surah": return surah.map { $0.start...$0.end }
        case "custom":
            guard let surah, first >= 1, last >= first, last <= surah.count else { return nil }
            return (surah.start + first - 1)...(surah.start + last - 1)
        default: return audio.verseID...audio.verseID
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Passage à écouter") {
                    Picker("Sélection", selection: $selection) {
                        Text("Ce verset").tag("verse"); Text("Toute la page").tag("page")
                        if sessionRange != nil { Text("Ma séance").tag("session") }
                        Text("Toute la sourate").tag("surah"); Text("Passage personnalisé").tag("custom")
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
                    Picker("Nombre d’écoutes", selection: $settings.count) {
                        ForEach([1, 2, 3, 5, 10, 20], id: \.self) { Text("\($0) fois").tag($0) }
                        Text("En continu").tag(0)
                        if settings.count > 0 && ![1, 2, 3, 5, 10, 20].contains(settings.count) { Text("\(settings.count) fois").tag(settings.count) }
                    }.accessibilityIdentifier("quran.audio.repeat.count")
                    if settings.count > 0 { Stepper("Nombre personnalisé : \(settings.count)", value: $settings.count, in: 1...999) }
                    Picker("Pause entre les répétitions", selection: $settings.gap) { ForEach([0, 2, 5, 10], id: \.self) { Text($0 == 0 ? "Aucune" : "\($0) secondes").tag($0) } }
                    Picker("Vitesse", selection: $settings.speed) { ForEach([0.75, 1, 1.25], id: \.self) { Text("\($0, specifier: "%.2g")×").tag($0) } }
                    Toggle("Arrêter à la fin des écoutes", isOn: $settings.autoStop).disabled(settings.count == 0)
                }
                Section {
                    Button("Lancer ce passage") {
                        guard let range else { return }
                        save(settings); audio.start(range: range, settings: settings); dismiss()
                    }.frame(minHeight: 44).disabled(range == nil || !settings.valid).accessibilityIdentifier("quran.audio.repeat.start")
                    if range == nil { Text("Choisis une plage de versets valide.").foregroundStyle(.secondary) }
                }
            }.navigationTitle("Réglages audio").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
                .onAppear {
                    settings = audio.repeatSettings
                    if let chapter = catalog.surah(for: audio.verseID) { surahNumber = chapter.number; first = audio.verseID - chapter.start + 1; last = first }
                    selection = sessionRange == nil ? "verse" : "session"
                }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
