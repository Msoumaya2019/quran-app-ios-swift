import SwiftUI

struct DifficultVersesView: View {
    let source: QuranSource
    let page: Int
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var error: String?
    private var ids: [Int] {
        Array(Set(QuranMarginGeometry.regions(source: source, page: page, catalog: store.catalog).map(\.id))).sorted()
    }
    var body: some View {
        Form {
            Section {
                Text("Les difficultés restent enregistrées jusqu’à leur retrait volontaire. Un repère rouge discret apparaît dans la marge, sans toucher au texte du Coran.").font(.caption)
                if let error { Text(error).foregroundStyle(.red) }
            }
            Section("Page \(page)") {
                ForEach(ids, id: \.self) { id in
                    let marker = store.snapshot.state["difficultyMarkers"][String(id)]
                    let surah = store.catalog.surah(for: id)
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("\(surah?.name ?? "Le Coran") · verset \(id - (surah?.start ?? 1) + 1)", isOn: Binding(get: {
                            store.snapshot.state["difficultyMarkers"][String(id)]["user"] != .null
                        }, set: { difficult in save(id, difficult: difficult) }))
                            .frame(minHeight: 44).accessibilityIdentifier("difficulty.verse.\(id)")
                        if marker["admin"] != .null { Text("Également signalé par l’administrateur.").font(.caption).foregroundStyle(theme.muted) }
                    }
                }
            }
        }.navigationTitle("Versets difficiles").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
    }
    private func save(_ id: Int, difficult: Bool) {
        var operation = ReaderOperation(kind: .difficulty, verseID: id, page: page, source: source.id)
        operation.difficulty = DifficultyChange(verseID: id, difficult: difficult)
        if !store.readerChange(operation) { error = "La modification n’a pas pu être enregistrée sur l’appareil." }
    }
}
