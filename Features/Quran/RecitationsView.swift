import SwiftUI
import AVFoundation

struct RecitationsView: View {
    @EnvironmentObject private var library: RecitationLibrary
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var player = RecitationPlaybackService()
    @State private var loading: String?
    @State private var error: String?
    var body: some View {
        List {
            if library.items.isEmpty { ContentUnavailableView("Aucune récitation", systemImage: "mic", description: Text("Enregistre ta voix depuis le lecteur du Coran.")) }
            ForEach(library.items) { item in
                Button { Task { await play(item) } } label: {
                    HStack(spacing: 12) {
                        Group { if loading == item.id { ProgressView() } else { Image(systemName: player.activeID == item.id ? "stop.circle" : "play.circle") } }.font(.title2).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.catalog.reference(VerseRange(json: .object(["start": .number(Double(item.start)), "end": .number(Double(item.end))])))).font(.subheadline)
                            Text("\(QuranAudioTimeline.timeLabel(Double(item.durationMs) / 1000)) · \(item.synced ? "Synchronisée" : "À synchroniser")").font(.caption).foregroundStyle(theme.muted)
                        }
                    }.frame(minHeight: 44)
                }.disabled(loading != nil).accessibilityIdentifier("recitation.item.\(item.id)")
            }
            if let message = error ?? library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
        }.navigationTitle("Mes récitations").navigationBarTitleDisplayMode(.inline).tint(theme.accent)
            .task { await library.synchronize() }
            .refreshable { await library.synchronize() }
            .onChange(of: store.identity?.id) { _, _ in player.stop() }
            .onDisappear { player.stop() }
    }
    private func play(_ item: Recitation) async {
        if player.activeID == item.id { player.stop(); return }
        player.stop(); loading = item.id; error = nil
        defer { loading = nil }
        do {
            let file = try await library.playable(item)
            guard store.identity?.id == item.userID, !Task.isCancelled else { return }
            try player.play(file: file, id: item.id)
        } catch { self.error = "Cette récitation n’est pas disponible hors connexion ou n’a pas pu être lue." }
    }
}
