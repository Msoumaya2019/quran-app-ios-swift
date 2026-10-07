import SwiftUI
import UIKit

private struct VerseContent: Decodable {
    let text: String?
    let translation: String?
    static let arabic = load("verse-text")
    static let french = load("translation-fr-rashid")
    private static func load(_ name: String) -> [VerseContent] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([VerseContent].self, from: data)) ?? []
    }
}

struct VerseActionsSheet: View {
    let verseID: Int
    let source: QuranSource
    @ObservedObject var audio: QuranAudioService
    let listen: () -> Void
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var translation = false
    @State private var report = false
    @State private var notice: String?
    private var surah: Surah? { store.catalog.surah(for: verseID) }
    private var reference: String { "\(surah?.name ?? "Le Coran") \(surah?.number ?? 1):\(verseID - (surah?.start ?? 1) + 1)" }
    private var text: String { VerseContent.arabic.indices.contains(verseID - 1) ? VerseContent.arabic[verseID - 1].text ?? "" : "" }
    private var known: Bool { ["perfect", "review"].contains(store.snapshot.state["knowledge"][String(verseID)].string ?? "") }
    private var bookmark: Bool { let row = store.snapshot.state["bookmarks"][String(verseID)]; return row != .null && row["deletedAt"] == .null }
    private var difficult: Bool { DifficultyChange.isDifficult(store.snapshot.state, verseID: verseID) }
    private func operation(_ kind: ReaderOperation.Kind) -> ReaderOperation {
        ReaderOperation(kind: kind, verseID: verseID, page: QuranSourceMapping.page(source: source, verseID: verseID, catalog: store.catalog), source: source.id)
    }
    private func study(_ action: VerseStudyChange.Action) {
        var value = operation(.verseStudy); value.verseStudy = VerseStudyChange(verseID: verseID, action: action)
        notice = store.readerChange(value) ? "Enregistré" : "L’enregistrement a échoué. Réessaie."
    }
    private func play(count: Int, continuous: Bool = false) {
        var settings = audio.repeatSettings; settings.count = count; settings.mode = .eachVerse; settings.after = .stop
        audio.start(range: verseID...(continuous ? 6236 : verseID), settings: settings); listen(); dismiss()
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { play(count: 1) } label: { Label("Écouter ce verset", systemImage: "play.fill") }
                    Menu { ForEach([2, 3, 5], id: \.self) { count in Button("\(count)×") { play(count: count) } } } label: { Label("Répéter", systemImage: "repeat") }
                    Button {
                        var value = operation(.difficulty); value.difficulty = DifficultyChange(verseID: verseID, difficult: !difficult)
                        notice = store.readerChange(value) ? "Enregistré" : "L’enregistrement a échoué."
                    } label: { Label(difficult ? "Retirer des versets difficiles" : "Marquer comme difficile", systemImage: "exclamationmark.circle") }
                    Button { notice = store.readerChange(operation(bookmark ? .removeBookmark : .bookmark)) ? "Enregistré" : "L’enregistrement a échoué." } label: { Label(bookmark ? "Retirer des marque-pages" : "Ajouter aux marque-pages", systemImage: "bookmark") }
                    Button { study(.learned) } label: { Label(known ? "Verset déjà appris" : "Marquer comme appris", systemImage: "checkmark.circle") }.disabled(known)
                    Button { translation = true } label: { Label("Voir la traduction", systemImage: "text.bubble") }
                    Button { study(.nextRevision) } label: { Label("Ajouter à ma prochaine révision", systemImage: "calendar.badge.plus") }.disabled(!known)
                    if !known { Text("Marque d’abord ce verset comme appris pour le programmer en révision.").font(.caption).foregroundStyle(theme.muted) }
                }
                Section("Plus") {
                    ShareLink(item: text + "\n" + reference) { Label("Partager le verset", systemImage: "square.and.arrow.up") }.disabled(text.isEmpty)
                    Button("Copier le texte") { UIPasteboard.general.string = text; notice = "Texte copié" }.disabled(text.isEmpty)
                    Button("Copier la référence") { UIPasteboard.general.string = reference; notice = "Référence copiée" }
                    Button("Commencer la lecture à partir de ce verset") { play(count: 1, continuous: true) }
                    Button("Signaler une erreur") { report = true }
                }
                if let notice { Text(notice).font(.caption).foregroundStyle(theme.muted) }
            }.tint(theme.accent).navigationTitle(reference).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            .sheet(isPresented: $translation) {
                NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) {
                    Text(reference).font(.headline)
                    Text(VerseContent.french.indices.contains(verseID - 1) ? VerseContent.french[verseID - 1].translation ?? "Traduction indisponible" : "Traduction indisponible")
                    Text("Traduction française utilisée dans l’application existante (Rashid). ").font(.caption).foregroundStyle(theme.muted)
                }.padding() }.navigationTitle("Traduction").navigationBarTitleDisplayMode(.inline).toolbar { Button("Fermer") { translation = false } } }.presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $report) { ProblemReportSheet(initialDescription: "Erreur concernant le verset \(reference) : ") }
    }
}
