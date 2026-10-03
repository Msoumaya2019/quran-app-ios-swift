import SwiftUI

struct QuranReaderView: View {
    var onHome: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var source = QuranSource.medina
    @State private var page = 1
    @State private var immersive = false
    @State private var options = false
    @State private var loading = false
    @State private var error: String?
    @State private var initialized = false
    @State private var jumpPage = 1
    @StateObject private var audio = QuranAudioService()
    @State private var showAudio = false
    private var verseID: Int {
        if source == .edition1441,
           let url = Bundle.main.url(forResource: "coran_1441-bounds", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let rows = try? JSONDecoder().decode([String: [[Int]]].self, from: data)[String(page)] {
            return rows.compactMap { row -> Int? in guard row.count >= 2, let surah = store.catalog.surahs.first(where: { $0.number == row[0] }) else { return nil }; return surah.start + row[1] - 1 }.min() ?? 1
        }
        return store.catalog.pageStarts.first { $0.0 == page }?.1 ?? 1
    }
    private var bookmarked: Bool { let value = store.snapshot.state["bookmarks"][String(verseID)]; return value != .null && value["deletedAt"] == .null }
    private func record(_ kind: ReaderOperation.Kind) { store.readerChange(ReaderOperation(kind: kind, verseID: verseID, page: page, source: source.id)) }
    var body: some View {
        VStack(spacing: 0) {
            if loading { HStack { ProgressView(); Text("Chargement du Coran…").font(.caption) }.padding(8) }
            QuranPager(source: source, page: $page, onTap: { withAnimation(.easeInOut(duration: 0.18)) { immersive.toggle() } })
                .accessibilityIdentifier("quran.viewport")
            if !immersive {
                if showAudio { QuranMiniPlayer(audio: audio, catalog: store.catalog, close: { showAudio = false }) }
                HStack(spacing: 0) {
                    action("Accueil", "house.fill") { if let onHome { onHome() } else { dismiss() } }
                    action("Écouter", "play.fill") { showAudio = true; audio.toggle(start: verseID) }
                    action("Enregistrer", "mic.fill") { error = "L’enregistrement vocal sera migré dans la prochaine étape." }
                    action("Marque-page", bookmarked ? "bookmark.fill" : "bookmark") { record(bookmarked ? .removeBookmark : .bookmark) }
                    action("Plus", "ellipsis") { jumpPage = page; options = true }
                }.padding(.vertical, 8).background(theme.surface)
            }
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar, .tabBar)
        .statusBarHidden(immersive)
        .onAppear {
            guard !initialized else { return }; initialized = true
            if store.snapshot.state["reader"]["mushaf"].string == QuranSource.edition1441.id, QuranResourceService.shared.isReady(.edition1441) { source = .edition1441 }
            page = source.validPage(store.snapshot.state["lastRead"]["page"].int ?? 1)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-test-reader-fixtures") { page = 1 }
            #endif
        }
        .onChange(of: page) { _, _ in if initialized { record(.reading) } }
        .onDisappear { audio.pause(); record(.reading); Task { await store.refresh() } }
        .sheet(isPresented: $options) {
            NavigationStack {
                Form {
                    Section("Affichage du Coran") {
                        ForEach(QuranSource.available) { value in
                            Button { Task { await changeSource(value) } } label: {
                                HStack { Text(value.displayName); Spacer(); if value == source { Image(systemName: "checkmark") } }
                            }.disabled(loading)
                        }
                        Text("Coran 1441 se télécharge uniquement à la sélection (environ 98 Mo). Il reste ensuite disponible hors connexion.").font(.caption)
                    }
                    Section("Aller à une page") {
                        Stepper("Page \(jumpPage)", value: $jumpPage, in: 1...604)
                        Button("Ouvrir la page") { page = jumpPage; options = false }
                    }
                    Section("Réciteur") {
                        Picker("Réciteur", selection: Binding(get: { audio.reciterID }, set: { audio.changeReciter($0) })) {
                            ForEach(QuranAudioService.Reciter.available) { reciter in Text(reciter.name).tag(reciter.id) }
                        }
                    }
                    Section("Marque-pages") {
                        ForEach(store.snapshot.state["bookmarks"].object.keys.sorted(), id: \.self) { key in
                            let bookmark = store.snapshot.state["bookmarks"][key]
                            if bookmark["deletedAt"] == .null, let id = bookmark["verseId"].int {
                                Button("\(store.catalog.surah(for: id)?.name ?? "Le Coran") · verset \(bookmark["ayah"].int ?? 1)") {
                                    page = source.validPage(bookmark["sourcePages"][source.id].int ?? bookmark["page"].int ?? 1); options = false
                                }
                            }
                        }
                    }
                }.navigationTitle("Le Coran").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { options = false } } }
            }.presentationDetents([.medium, .large])
        }
        .alert("Le Coran", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func action(_ title: String, _ icon: String, run: @escaping () -> Void) -> some View {
        Button(action: run) { VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 21)); Text(title).font(.system(size: 10)) }.frame(maxWidth: .infinity).frame(minHeight: 44) }.foregroundStyle(theme.accent).accessibilityIdentifier("quran.action.\(title)")
    }
    private func changeSource(_ next: QuranSource) async {
        guard next != source, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            try await QuranResourceService.shared.ensureReady(next)
            let nextPage = next.validPage(page)
            _ = try await QuranPageCache.shared.image(source: next, page: nextPage)
            source = next; page = nextPage; options = false
            record(.source)
            record(.reading)
        } catch { self.error = "Téléchargement indisponible. La source précédente reste affichée. Tu peux réessayer avec une connexion disponible." }
    }
}
