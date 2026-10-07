import SwiftUI
import AVFoundation

struct RecitationsView: View {
    @EnvironmentObject private var library: RecitationLibrary
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var player = RecitationPlaybackService()
    @State private var loading: String?
    @State private var error: String?
    @State private var selected: Recitation?
    @State private var visible = true
    var body: some View {
        List {
            if library.items.isEmpty { ContentUnavailableView("Aucune récitation", systemImage: "mic", description: Text("Enregistre ta voix depuis le lecteur du Coran.")) }
            ForEach(library.items) { item in
                Button { Task { await play(item) } } label: {
                    HStack(spacing: 12) {
                        Group { if loading == item.id { ProgressView() } else { Image(systemName: player.activeID == item.id ? "stop.circle" : "play.circle") } }.font(.title2).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.invocation?.title ?? (item.invocation != nil ? "Invocation" : store.catalog.reference(VerseRange(json: .object(["start": .number(Double(item.start)), "end": .number(Double(item.end))]))))).font(.subheadline)
                            Text("\(QuranAudioTimeline.timeLabel(Double(item.durationMs) / 1000)) · \(item.synced ? "Synchronisée" : "À synchroniser")").font(.caption).foregroundStyle(theme.muted)
                        }
                    }.frame(minHeight: 44)
                }.disabled(loading != nil).accessibilityIdentifier("recitation.item.\(item.id)")
                Button {
                    player.stop(); selected = item
                } label: {
                    Label("Retours et corrections\(library.reviews[item.id]?.isEmpty == false ? " · \(library.reviews[item.id]?.count ?? 0)" : "")", systemImage: "text.bubble")
                        .font(.subheadline).frame(minHeight: 44)
                }.disabled(loading != nil).accessibilityIdentifier("recitation.reviews.\(item.id)")
            }
            if let message = error ?? library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
        }.navigationTitle("Mes récitations").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
            .task { await library.synchronize() }
            .refreshable { await library.synchronize() }
            .onChange(of: store.identity?.id) { _, _ in player.stop() }
            .onAppear { visible = true }
            .onDisappear { visible = false; player.stop() }
            .sheet(item: $selected) { RecitationFeedbackView(item: $0) }
    }
    private func play(_ item: Recitation) async {
        if player.activeID == item.id { player.stop(); return }
        player.stop(); loading = item.id; error = nil
        defer { loading = nil }
        do {
            let file = try await library.playable(item)
            guard visible, store.identity?.id == item.userID, !Task.isCancelled else { return }
            try player.play(file: file, id: item.id)
        } catch { self.error = "Cette récitation n’est pas disponible hors connexion ou n’a pas pu être lue." }
    }
}

private struct RecitationFeedbackView: View {
    let item: Recitation
    @EnvironmentObject private var library: RecitationLibrary
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = RecitationPlaybackService()
    @State private var loading: String?
    @State private var error: String?
    @State private var refreshed = false
    @State private var visible = true
    private var rows: [RecitationFeedback] { library.reviews[item.id] ?? [] }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(item.invocation?.title ?? (item.invocation != nil ? "Invocation" : store.catalog.reference(VerseRange(json: .object(["start": .number(Double(item.start)), "end": .number(Double(item.end))]))))).font(.headline)
                }
                if rows.isEmpty {
                    if refreshed { Text("Aucun retour disponible pour cette récitation.").foregroundStyle(theme.muted) }
                    else { ProgressView("Chargement des retours…") }
                }
                ForEach(rows) { row in
                    Section {
                        if let verse = row.verse_id { Text(store.catalog.reference(VerseRange(json: .object(["start": .number(Double(verse)), "end": .number(Double(verse))])))).font(.subheadline.bold()) }
                        else { Text("Observation générale").font(.subheadline.bold()) }
                        if let comment = row.comment, !comment.isEmpty { Text(comment) }
                        Text(row.created_at.prefix(10)).font(.caption).foregroundStyle(theme.muted)
                        if row.resolved_at != nil { Label("Correction traitée", systemImage: "checkmark.circle").font(.caption).foregroundStyle(theme.muted) }
                        if row.voice_path != nil {
                            Button { Task { await play(row) } } label: {
                                HStack {
                                    if loading == row.id { ProgressView() }
                                    else { Image(systemName: player.activeID == row.id ? "stop.circle" : "play.circle") }
                                    Text(player.activeID == row.id ? "Arrêter" : "Écouter la correction")
                                }.frame(minHeight: 44)
                            }.disabled(loading != nil).accessibilityIdentifier("recitation.feedback.audio.\(row.id)")
                        }
                    }
                }
                if let message = error ?? library.reviewMessage { Text(message).font(.caption).foregroundStyle(theme.muted) }
            }.navigationTitle("Retours et corrections").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
                .toolbar { Button("Fermer") { dismiss() } }
                .task { await library.loadReviews(item); refreshed = true }
                .refreshable { await library.loadReviews(item) }
                .onChange(of: store.identity?.id) { _, _ in player.stop(); dismiss() }
                .onAppear { visible = true }
                .onDisappear { visible = false; player.stop() }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func play(_ row: RecitationFeedback) async {
        if player.activeID == row.id { player.stop(); return }
        player.stop(); loading = row.id; error = nil; defer { loading = nil }
        do {
            let file = try await library.feedbackPlayable(row, for: item)
            guard visible, store.identity?.id == item.userID, !Task.isCancelled else { return }
            try player.play(file: file, id: row.id)
        } catch { self.error = "Cette correction vocale n’est pas encore disponible hors connexion ou n’a pas pu être lue." }
    }
}
