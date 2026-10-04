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
                    let personal = marker["user"] != .null
                    VStack(alignment: .leading, spacing: 4) {
                        Button { save(id, difficult: !personal) } label: {
                            HStack {
                                Text("\(surah?.name ?? "Le Coran") · verset \(id - (surah?.start ?? 1) + 1)")
                                Spacer()
                                Image(systemName: personal ? "checkmark.circle.fill" : "circle").font(.title3)
                                    .foregroundStyle(personal ? Color.red : theme.muted)
                            }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("difficulty.verse.\(id)")
                            .accessibilityValue(personal ? "Difficile" : "Normal")
                        if marker["admin"] != .null { Text("Également signalé par l’administrateur.").font(.caption).foregroundStyle(theme.muted) }
                    }
                }
            }
        }.navigationTitle("Versets difficiles").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
    }
    private func save(_ id: Int, difficult: Bool) {
        var operation = ReaderOperation(kind: .difficulty, verseID: id, page: page, source: source.id)
        operation.difficulty = DifficultyChange(verseID: id, difficult: difficult)
        if store.readerChange(operation) { error = nil }
        else { error = "La modification n’a pas pu être enregistrée sur l’appareil." }
    }
}
