import SwiftUI

struct QuranReaderView: View {
    var onHome: (() -> Void)? = nil
    let mode: ReadingMode
    let session: QuranSessionContext?
    init(initialPage: Int = 1, sourceID: String? = nil, mode: ReadingMode = .classic, session: QuranSessionContext? = nil, onHome: (() -> Void)? = nil) {
        self.onHome = onHome
        self.mode = mode
        self.session = session
        let preferred = QuranSource.available.first { $0.id == sourceID } ?? .medina
        let ready = QuranResourceService.shared.isReady(preferred) ? preferred : .medina
        _source = State(initialValue: ready)
        var firstPage = session.map { QuranSourceMapping.page(source: ready, verseID: $0.range.start, catalog: QuranCatalog()) } ?? ready.validPage(initialPage)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reader-fixtures") { firstPage = 1 }
        #endif
        _page = State(initialValue: firstPage)
    }
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var source = QuranSource.medina
    @State private var page = 1
    @State private var immersive = false
    @State private var options = false
    @State private var optionsDetent = PresentationDetent.medium
    @State private var loading = false
    @State private var error: String?
    @State private var initialized = false
    @State private var jumpPage = 1
    @StateObject private var audio = QuranAudioService()
    @State private var showAudio = false
    @State private var recording = false
    @State private var confirmConsolidation = false
    @State private var selectedVerse: SelectedVerse?
    private struct SelectedVerse: Identifiable { let id: Int }
    private var verseID: Int {
        QuranSourceMapping.firstVerse(source: source, page: page, catalog: store.catalog)
    }
    private var bookmarked: Bool { let value = store.snapshot.state["bookmarks"][String(verseID)]; return value != .null && value["deletedAt"] == .null }
    private func record(_ kind: ReaderOperation.Kind) { store.readerChange(ReaderOperation(kind: kind, verseID: verseID, page: page, source: source.id)) }
    private var pageAnnotations: QuranPageAnnotations {
        let difficult = Set(store.snapshot.state["difficultyMarkers"].object.keys.compactMap(Int.init).filter { DifficultyChange.isDifficult(store.snapshot.state, verseID: $0) })
        var through = 0
        if let session {
            if session.mode == .learning { through = session.range.start + LearningValidation.completedCount(context: session, state: store.snapshot.state) - 1 }
            else if session.mode == .revision { through = session.range.start + RevisionValidation.completedCount(context: session, state: store.snapshot.state) - 1 }
        }
        return QuranPageAnnotations(range: session?.range, through: through, difficultIDs: difficult, color: UIColor(session?.mode == .learning ? theme.accent : theme.review),
            audioVerseID: audio.playing || audio.loading || audio.timeline.duration > 0 ? audio.verseID : nil, audioColor: UIColor(theme.accent))
    }
    var body: some View {
        VStack(spacing: 0) {
            if let session { QuranSessionHeader(context: session, source: source, catalog: store.catalog, completedCount: session.mode == .learning ? LearningValidation.completedCount(context: session, state: store.snapshot.state) : session.mode == .revision ? RevisionValidation.completedCount(context: session, state: store.snapshot.state) : nil) }
            if loading { HStack { ProgressView(); Text("Chargement du Coran…").font(.caption) }.padding(8) }
            QuranPager(source: source, page: $page, onTap: { withAnimation(.easeInOut(duration: 0.18)) { immersive.toggle() } }, onVerse: { selectedVerse = SelectedVerse(id: $0) }, annotations: pageAnnotations)
                .accessibilityIdentifier("quran.viewport")
            if !immersive {
                if showAudio { QuranMiniPlayer(audio: audio, catalog: store.catalog, close: { showAudio = false }, pageRange: verseID...max(verseID, page < source.pageCount ? QuranSourceMapping.firstVerse(source: source, page: page + 1, catalog: store.catalog) - 1 : 6236), sessionRange: session.map { $0.range.start...$0.range.end }, saveRepeat: { settings in
                    var operation = ReaderOperation(kind: .audioRepeat, verseID: audio.verseID, page: page, source: source.id)
                    operation.audioRepeat = settings; store.readerChange(operation)
                }) }
                HStack(spacing: 0) {
                    action("Accueil", "house.fill") { if let onHome { onHome() } else { dismiss() } }
                    action("Écouter", "play.fill") { showAudio = true; audio.toggle(start: audio.timeline.duration > 0 ? audio.verseID : audio.playbackRange.contains(verseID) ? verseID : audio.playbackRange.lowerBound) }
                    action("Enregistrer", "mic.fill") { audio.pause(); recording = true }
                    action("Marque-page", bookmarked ? "bookmark.fill" : "bookmark") { record(bookmarked ? .removeBookmark : .bookmark) }
                    action("Plus", "ellipsis") { jumpPage = page; options = true }
                }.padding(.vertical, 8).background(theme.surface)
            }
        }
        .background(.white)
        .navigationTitle(source.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(immersive ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.white, for: .navigationBar)
        .statusBarHidden(immersive)
        .onAppear {
            guard !initialized else { return }; initialized = true
            audio.configure(AudioRepeatSettings.load(store.snapshot.state))
            if let session { audio.updateRange(session.range.start...session.range.end) }
            if let reciter = store.snapshot.state["audioPreferences"]["reciterId"].string,
               QuranAudioService.Reciter.available.contains(where: { $0.id == reciter }) { audio.changeReciter(reciter) }
            if let session, session.mode == .learning || session.mode == .revision {
                let count = session.mode == .learning ? LearningValidation.completedCount(context: session, state: store.snapshot.state) : RevisionValidation.completedCount(context: session, state: store.snapshot.state)
                let pending = session.range.start + count
                if pending <= session.range.end { page = QuranSourceMapping.page(source: source, verseID: pending, catalog: store.catalog) }
            }
            record(.reading)
        }
        .onChange(of: page) { _, _ in if initialized { record(.reading) } }
        .onChange(of: audio.verseID) { _, current in
            if (audio.playing || audio.loading || audio.timeline.duration > 0), store.snapshot.state["reader"]["followAudio"].bool != false {
                page = QuranSourceMapping.page(source: source, verseID: current, catalog: store.catalog)
            }
        }
        .onDisappear { audio.pause(); record(.reading); Task { await store.refresh() } }
        .sheet(isPresented: $options) {
            NavigationStack {
                Form {
                    Section("Navigation") { NavigationLink("Sourates, Juz’ et Hizb") { QuranIndexView(source: source) { target in page = source.validPage(target); options = false } }.accessibilityIdentifier("quran.index.open") }
                    Section("Mes versets") {
                        NavigationLink("Versets difficiles de cette page") {
                            DifficultVersesView(source: source, page: page).onAppear { optionsDetent = .large }
                        }.accessibilityIdentifier("difficulty.open")
                    }
                    if let session, session.mode == .learning {
                        Section("Apprentissage") {
                            NavigationLink("J’ai appris jusqu’ici") {
                                LearningValidationView(context: session, source: source, firstPending: session.range.start + LearningValidation.completedCount(context: session, state: store.snapshot.state))
                                    .onAppear { optionsDetent = .large }
                            }.accessibilityIdentifier("learning.open")
                        }
                    }
                    if let session, session.mode == .revision {
                        Section("Révision") {
                            NavigationLink("Valider ma révision") {
                                RevisionValidationView(context: session, source: source, firstPending: session.range.start + RevisionValidation.completedCount(context: session, state: store.snapshot.state))
                                    .onAppear { optionsDetent = .large }
                            }.accessibilityIdentifier("revision.open")
                        }
                    }
                    if let session, session.mode == .consolidation {
                        Section("Séance") {
                            Button("Valider la consolidation") { confirmConsolidation = true }
                                .disabled(!canConsolidate(session))
                            Text("Valide uniquement lorsque tu as consolidé tout le passage prévu.").font(.caption)
                        }
                    }
                    Section("Ma voix") { NavigationLink("Mes récitations") { RecitationsView().onAppear { audio.pause() } }.accessibilityIdentifier("recitations.open") }
                    Section("Affichage du Coran") {
                        if loading { HStack { ProgressView(); Text("Téléchargement et préparation du Coran…").font(.caption) } }
                        ForEach(QuranSource.available) { value in
                            Button { Task { await changeSource(value) } } label: {
                                HStack { Text(value.displayName); Spacer(); if value == source { Image(systemName: "checkmark") } }
                            }.disabled(loading)
                        }
                        Text("Coran 1441 se télécharge uniquement à la sélection (environ 98 Mo). Il reste ensuite disponible hors connexion.").font(.caption)
                        QuranDownloadProgress(retry: { Task { await changeSource(.edition1441) } })
                    }
                    Section("Aller à une page") {
                        TextField("Numéro de page", value: $jumpPage, format: .number).keyboardType(.numberPad).frame(minHeight: 44)
                        Stepper("Page \(jumpPage)", value: $jumpPage, in: 1...604)
                        Button("Ouvrir la page") { page = source.validPage(jumpPage); options = false }
                    }
                    Section("Réciteur") {
                        Picker("Réciteur", selection: Binding(get: { audio.reciterID }, set: { id in
                            audio.changeReciter(id)
                            store.readerChange(ReaderOperation(kind: .reciter, verseID: verseID, page: page, source: id))
                        })) {
                            ForEach(QuranAudioService.Reciter.available) { reciter in Text(reciter.name).tag(reciter.id) }
                        }
                    }
                    Section("Marque-pages") {
                        ForEach(store.snapshot.state["bookmarks"].object.keys.sorted(), id: \.self) { key in
                            let bookmark = store.snapshot.state["bookmarks"][key]
                            if bookmark["deletedAt"] == .null, let id = bookmark["verseId"].int {
                                Button("\(store.catalog.surah(for: id)?.name ?? "Le Coran") · verset \(bookmark["ayah"].int ?? 1)") {
                                    page = source.validPage(bookmark["sourcePages"][source.id].int ?? QuranSourceMapping.page(source: source, verseID: id, catalog: store.catalog)); options = false
                                }
                            }
                        }
                    }
                }.navigationTitle("Le Coran").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { options = false } } }
            }
        .confirmationDialog("Valider tout le passage de consolidation ?", isPresented: $confirmConsolidation, titleVisibility: .visible) {
            Button("J’ai consolidé") {
                if let session, let validation = ConsolidationValidation(context: session) {
                    var operation = ReaderOperation(kind: .consolidation, verseID: session.range.start, page: page, source: source.id)
                    operation.consolidation = validation
                    if store.readerChange(operation) {
                        options = false
                        Task { await store.refresh() }
                    } else { error = "La validation n’a pas pu être enregistrée sur l’appareil. Réessaie." }
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: { Text("La date prévue reste inchangée. Cette validation est conservée sur l’appareil et synchronisée lorsque la connexion est disponible.") }
            .presentationDetents([.medium, .large], selection: $optionsDetent)
        }
        .sheet(isPresented: $recording) {
            if let user = store.identity?.id {
                VoiceRecorderView(user: user, catalog: store.catalog, firstVerse: verseID, lastVerse: page < 604 ? max(verseID, QuranSourceMapping.firstVerse(source: source, page: page + 1, catalog: store.catalog) - 1) : 6236)
            }
        }
        .sheet(item: $selectedVerse) { selected in VerseActionsSheet(verseID: selected.id, source: source, audio: audio, listen: { showAudio = true }) }
        .alert("Le Coran", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func canConsolidate(_ context: QuranSessionContext) -> Bool {
        guard let validation = ConsolidationValidation(context: context) else { return false }
        return validation.applying(to: store.snapshot.state) != store.snapshot.state
    }
    private func action(_ title: String, _ icon: String, run: @escaping () -> Void) -> some View {
        Button(action: run) { VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 21)); Text(title).font(.system(size: 10)) }.frame(maxWidth: .infinity).frame(minHeight: 44) }.foregroundStyle(theme.accent).accessibilityIdentifier("quran.action.\(title)")
    }
    private func changeSource(_ next: QuranSource) async {
        guard next != source, !loading else { return }
        loading = true
        let owner = store.identity?.id
        defer { loading = false }
        do {
            try await QuranResourceService.shared.ensureReady(next)
            for _ in 0..<3 {
                let nextPage = next.validPage(page)
                await QuranPageCache.shared.setWindow(source: next, page: nextPage)
                _ = try await QuranPageCache.shared.image(source: next, page: nextPage)
                guard store.identity?.id == owner else { return }
                guard next.validPage(page) == nextPage else { continue }
                source = next; page = nextPage; options = false
                record(.source); record(.reading)
                return
            }
            self.error = "La page a changé pendant la préparation. Sélectionne de nouveau le Coran pour continuer sur la page actuelle."
        } catch { self.error = "Téléchargement indisponible. La source précédente reste affichée. Tu peux réessayer avec une connexion disponible." }
    }
}
