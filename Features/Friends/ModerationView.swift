import SwiftUI

struct ModerationView: View {
    let section: ModerationSection
    @EnvironmentObject private var library: ModerationLibrary
    @EnvironmentObject private var theme: ThemeManager
    private var title: String { section == .recitations ? "Récitations à écouter" : "Modération des messages" }
    var body: some View {
        List {
            if section == .messages {
                NavigationLink("Signalements de messages") { ModerationView(section: .reports) }.accessibilityIdentifier("moderation.reports")
            }
            if library.loading { ProgressView("Chargement…") }
            if let message = library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
            if !library.loading && library.items.isEmpty { Text("Aucun contenu disponible").foregroundStyle(theme.muted) }
            ForEach(Array(library.items.enumerated()), id: \.offset) { _, row in
                NavigationLink { ModerationDetail(row: row, section: section) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(library.name(row[section == .messages ? "sender_id" : section == .reports ? "reporter_id" : "user_id"].string)).font(.headline)
                        if section == .recitations {
                            Label(row["recording_type"].string == "invocation" ? "Invocation" : "Récitation du Coran", systemImage: "waveform")
                            Text(row["listened_at"] == .null ? "À écouter" : "Écoutée").font(.caption).foregroundStyle(theme.accent)
                        } else {
                            Text(section == .reports ? row["reason"].string ?? "Signalement" : row["deleted_at"] == .null ? row["body"].string ?? "Message" : "Message supprimé").lineLimit(3)
                            Text(section == .reports ? (row["status"].string == "reviewed" ? "Traité" : "À traiter") : row["group_id"] == .null ? "Conversation privée" : "Groupe").font(.caption).foregroundStyle(theme.muted)
                        }
                        Text(String((row["created_at"].string ?? "").prefix(10))).font(.caption2).foregroundStyle(theme.muted)
                    }.padding(.vertical, 4)
                }
            }
            if library.hasMore { Button("Charger la suite") { Task { await library.load(section, more: true) } }.disabled(library.loading) }
        }.navigationTitle(section == .reports ? "Signalements de messages" : title).navigationBarTitleDisplayMode(.inline)
            .task { await library.load(section) }.refreshable { await library.load(section) }
            .onDisappear { library.stopAudio() }
    }
}

private struct ModerationDetail: View {
    let row: JSONValue
    let section: ModerationSection
    @EnvironmentObject private var library: ModerationLibrary
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @State private var confirming = false
    @State private var comment = ""
    @State private var feedbackID = UUID()
    @State private var feedbackSent = false
    @State private var recording: JSONValue?
    @State private var openingOwner: UUID?
    @State private var attemptedComment: String?
    @State private var preciseVerse = false
    @State private var verseID = 0
    @StateObject private var recorder = VoiceRecorderService()
    private var current: JSONValue { library.items.first { $0["id"] == row["id"] } ?? row }
    private var verseRange: ClosedRange<Int>? {
        guard let start = row["start_verse_id"].int, let end = row["end_verse_id"].int, ModerationRepository.validVerse(start, in: row) else { return nil }
        return start...end
    }
    private var verseReference: String {
        guard let surah = store.catalog.surah(for: verseID) else { return "Verset" }
        return "\(surah.name) · verset \(verseID - surah.start + 1)"
    }
    private var passage: String {
        guard row["recording_type"].string != "invocation" else { return "Invocation" }
        guard let start = row["start_verse_id"].int, let end = row["end_verse_id"].int,
              let first = store.catalog.surah(for: start), let last = store.catalog.surah(for: end) else { return "Récitation du Coran" }
        if first.start == last.start { return "\(first.name) · versets \(start - first.start + 1) → \(end - first.start + 1)" }
        return "\(first.name) \(start - first.start + 1) → \(last.name) \(end - last.start + 1)"
    }
    var body: some View {
        Group {
        if openingOwner != nil && openingOwner == library.account { Form {
            Section("Contenu") {
                Text(library.name(row[section == .messages ? "sender_id" : section == .reports ? "reporter_id" : "user_id"].string)).font(.headline)
                Text(row["created_at"].string ?? "").font(.caption)
                if section == .recitations {
                    Text(passage)
                    AdminRecitationPlayer(row: row)
                        .disabled(recorder.recording || recorder.requesting || recorder.previewing)
                    Button(current["listened_at"] == .null ? "Marquer comme écoutée" : "Écoutée") { Task { await library.moderate(row, section: .recitations) } }
                        .disabled(library.busy || current["listened_at"] != .null)
                } else {
                    Text(section == .reports ? row["excerpt"].string ?? "" : current["deleted_at"] == .null ? row["body"].string ?? "" : "Message supprimé").textSelection(.enabled)
                    if section == .reports { Text(row["reason"].string ?? "") }
                    if let recording { AdminRecitationPlayer(row: recording) }
                }
            }
            if section == .recitations {
                Section("Retour à l’utilisateur") {
                    if let verseRange {
                        Toggle("Corriger un verset précis", isOn: $preciseVerse).accessibilityIdentifier("moderation.verse.scope")
                            .disabled(library.busy || recorder.recording || recorder.requesting)
                        if preciseVerse {
                            Stepper(value: $verseID, in: verseRange) { Text(verseReference).accessibilityIdentifier("moderation.verse.reference") }
                                .disabled(library.busy || recorder.recording || recorder.requesting).accessibilityIdentifier("moderation.verse.stepper")
                        }
                    }
                    TextEditor(text: Binding(get: { comment }, set: { comment = $0; feedbackSent = false })).frame(minHeight: 100).accessibilityIdentifier("moderation.feedback")
                        .disabled(library.busy)
                    if recorder.recording {
                        Button("Arrêter l’enregistrement") { recorder.stop() }.accessibilityIdentifier("moderation.voice.stop")
                    } else if recorder.draft != nil {
                        Button(recorder.previewing ? "Arrêter la préécoute" : "Écouter ma correction") { library.stopAudio(); recorder.togglePreview() }.disabled(library.busy)
                        Button("Supprimer l’enregistrement", role: .destructive) { recorder.discard(); feedbackID = UUID(); attemptedComment = nil }.disabled(library.busy)
                    } else {
                        Button("Enregistrer une correction vocale") { library.stopAudio(); feedbackID = UUID(); attemptedComment = nil; Task { await recorder.start() } }
                            .disabled(library.busy || recorder.requesting).accessibilityIdentifier("moderation.voice.record")
                    }
                    if let error = recorder.error { Text(error).font(.caption).foregroundStyle(theme.muted) }
                    Button("Envoyer le retour") { Task {
                        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                        if attemptedComment != text { feedbackID = UUID(); attemptedComment = text }
                        if recorder.previewing { recorder.togglePreview() }
                        if await library.feedback(row, id: feedbackID, comment: comment, voice: recorder.draft, verseID: preciseVerse ? verseID : nil) { comment = ""; recorder.discard(); feedbackID = UUID(); feedbackSent = true }
                    } }.disabled(library.busy || recorder.recording || recorder.requesting || (comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recorder.draft == nil) || comment.count > 2000)
                    if feedbackSent { Label("Retour envoyé", systemImage: "checkmark.circle").foregroundStyle(theme.accent) }
                }
            } else if section == .messages {
                Button("Supprimer le message", role: .destructive) { confirming = true }.disabled(library.busy || current["deleted_at"] != .null).accessibilityIdentifier("moderation.delete")
            } else {
                Button(current["status"].string == "reviewed" ? "Signalement traité" : "Marquer comme traité") { Task { await library.moderate(row, section: .reports) } }.disabled(library.busy || current["status"].string == "reviewed")
            }
            if let message = library.message { Text(message).font(.caption) }
        } } else { ContentUnavailableView("Accès indisponible", systemImage: "lock", description: Text("Reconnecte-toi avec ton compte administrateur.")) }
        }.navigationTitle(section == .recitations ? "Écouter la récitation" : "Modérer").navigationBarTitleDisplayMode(.inline)
            .onAppear { if openingOwner == nil { openingOwner = library.account }; if verseID == 0 { verseID = verseRange?.lowerBound ?? 0 } }
            .onChange(of: preciseVerse) { _, _ in feedbackID = UUID(); attemptedComment = nil; feedbackSent = false }
            .onChange(of: verseID) { _, _ in feedbackID = UUID(); attemptedComment = nil; feedbackSent = false }
            .confirmationDialog("Supprimer ce message pour tous les participants ?", isPresented: $confirming) {
                Button("Supprimer le message", role: .destructive) { Task { await library.moderate(row, section: .messages) } }
            }.onDisappear { library.stopAudio(); recorder.discard() }
            .onChange(of: library.account) { _, _ in recorder.discard(); comment = ""; feedbackSent = false }
            .task { if section == .messages, current["deleted_at"] == .null, let id = row["recitation_id"].string { recording = await library.recording(id) } }
    }
}

private struct AdminRecitationPlayer: View {
    let row: JSONValue
    @EnvironmentObject private var library: ModerationLibrary
    var body: some View { AdminPlayerControl(row: row, playback: library.playback) }
}
private struct AdminPlayerControl: View {
    let row: JSONValue
    @EnvironmentObject private var library: ModerationLibrary
    @ObservedObject var playback: RecitationPlaybackService
    var body: some View {
        Button { Task { await library.play(row) } } label: {
            HStack {
                if library.loadingAudio == row["id"].string { ProgressView() }
                else { Image(systemName: playback.activeID == row["id"].string ? "stop.fill" : "play.fill") }
                Text(playback.activeID == row["id"].string ? "Arrêter l’écoute" : "Écouter")
            }.frame(minHeight: 44)
        }.disabled(library.loadingAudio != nil).accessibilityIdentifier("moderation.listen")
    }
}
