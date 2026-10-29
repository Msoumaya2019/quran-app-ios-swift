import SwiftUI

struct RoqyaView: View {
    @EnvironmentObject private var library: RoqyaLibrary
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = "Tous"
    @State private var search = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Roqya").font(theme.title(.title))
                Text("Écoute et retrouve tes audios, même hors connexion après téléchargement.").font(.caption).foregroundStyle(theme.muted)
                Picker("Afficher", selection: $selection) {
                    Text("Tous").tag("Tous"); Text("Favoris").tag("Favoris"); Text("Récents").tag("Récents")
                }.pickerStyle(.segmented)
                if library.loading { ProgressView("Actualisation…") }
                if let message = library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
                ForEach(library.catalog.filter { row in
                    (search.isEmpty || (row["title"].string ?? "").localizedStandardContains(search)) &&
                    (selection != "Favoris" || library.favorites.contains(row["id"].string ?? "")) &&
                    (selection != "Récents" || RoqyaLibrary.audios(row).contains { library.listens[$0["id"].string ?? ""] != nil })
                }, id: \.roqyaID) { row in
                    RoqyaCard(row: row)
                }
                if library.catalog.isEmpty && !library.loading { ContentUnavailableView("Aucune Roqya disponible", systemImage: "waveform", description: Text("Le catalogue est publié par l’administrateur. Actualise pour réessayer.")) }
            }.padding(18)
        }.background(theme.background).navigationTitle("Roqya").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Rechercher une Roqya")
            .task { library.select(store.identity?.id); await library.refresh() }
            .refreshable { await library.refresh() }
            .onDisappear { library.closePlayback() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { library.checkpoint() }
                else if phase == .active { library.playback.checkSleepTimer() }
            }
    }
}

private struct RoqyaCard: View {
    let row: JSONValue
    @EnvironmentObject private var library: RoqyaLibrary
    @EnvironmentObject private var theme: ThemeManager
    @State private var speed = 1.0
    @State private var opening = false
    private var audios: [JSONValue] { RoqyaLibrary.audios(row) }
    private var audio: JSONValue { audios.first { $0["id"].string == library.selected[row.roqyaID] } ?? audios.first ?? .null }
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let url = RoqyaLibrary.validMediaURL(row["image_url"].string) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "waveform").foregroundStyle(theme.gold) }
                            .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(row["title"].string ?? "Roqya").font(theme.title(.headline))
                        if let text = row["description"].string, !text.isEmpty { Text(text).font(.caption).foregroundStyle(theme.muted) }
                    }
                    Spacer()
                    Button { library.toggleFavorite(row.roqyaID) } label: { Image(systemName: library.favorites.contains(row.roqyaID) ? "heart.fill" : "heart").frame(width: 44, height: 44) }.accessibilityLabel("Favori")
                }
                Picker("Récitateur", selection: Binding(get: { audio.roqyaID }, set: { library.selectAudio(roqya: row.roqyaID, audio: $0) })) {
                    ForEach(audios, id: \.roqyaID) { a in Text(a["roqya_reciters"]["name"].string ?? "Récitateur").tag(a.roqyaID) }
                }
                RoqyaPlaybackControls(player: library.playback, audioID: audio.roqyaID, opening: opening) {
                    opening = true; library.playback.setSpeed(speed)
                    Task { await library.play(audio); opening = false }
                }
                Picker("Vitesse", selection: $speed) { ForEach([0.75, 1, 1.25, 1.5, 2], id: \.self) { value in Text("\(value.formatted())×").tag(value) } }
                    .onChange(of: speed) { _, value in library.playback.setSpeed(value) }
                if let progress = library.downloads[audio.roqyaID] {
                    if progress >= 0 { ProgressView(value: progress); Text("Téléchargement · \(Int(progress * 100)) %").font(.caption) } else { ProgressView("Téléchargement…") }
                } else if library.localFile(audio) != nil {
                    HStack { Label("Téléchargée", systemImage: "checkmark.circle").font(.caption).foregroundStyle(theme.review); Spacer(); Button("Supprimer", role: .destructive) { library.removeDownload(audio) }.frame(minHeight: 44) }
                } else { Button { Task { await library.download(audio) } } label: { Label("Télécharger pour écouter hors connexion", systemImage: "arrow.down.circle").font(.caption).frame(minHeight: 44) } }
            }
        }
    }
}

private struct RoqyaPlaybackControls: View {
    @ObservedObject var player: RecitationPlaybackService
    let audioID: String
    let opening: Bool
    let play: () -> Void
    var body: some View {
        VStack {
            if let error = player.playbackError { Text(error).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button { if player.activeID == audioID { player.togglePause() } else { play() } } label: {
                    Label(player.activeID == audioID && !player.paused ? "Pause" : "Écouter", systemImage: player.activeID == audioID && !player.paused ? "pause.fill" : "play.fill").frame(minHeight: 44)
                }.disabled(opening).accessibilityIdentifier("roqya.play." + audioID)
                if opening { ProgressView() }
                Spacer()
                if player.activeID == audioID { Text("\(Int(player.elapsed) / 60):\(String(format: "%02d", Int(player.elapsed) % 60)) / \(Int(player.duration) / 60):\(String(format: "%02d", Int(player.duration) % 60))").font(.caption).monospacedDigit() }
            }
            if player.activeID == audioID && player.duration > 0 {
                HStack {
                    Button { player.handleRemote(.backward) } label: { Image(systemName: "gobackward.15").frame(width: 44, height: 44) }.accessibilityLabel("Reculer de 15 secondes")
                    Slider(value: Binding(get: { player.elapsed }, set: { player.seekStream($0) }), in: 0...max(1, player.duration)).accessibilityLabel("Position de lecture")
                    Button { player.handleRemote(.forward) } label: { Image(systemName: "goforward.15").frame(width: 44, height: 44) }.accessibilityLabel("Avancer de 15 secondes")
                }
            }
            if player.activeID == audioID {
                Picker("Minuterie", selection: Binding(get: { player.sleepTimer.option }, set: { player.setSleepTimer($0) })) {
                    ForEach(PlaybackSleepTimer.Option.allCases) { option in Text(option.title).tag(option) }
                }.accessibilityIdentifier("roqya.timer")
                if player.sleepTimer.deadline != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let remaining = player.sleepTimer.remaining(now: ProcessInfo.processInfo.systemUptime) ?? 0
                        Text("Arrêt dans \(remaining / 60):\(String(format: "%02d", remaining % 60))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

extension JSONValue { var roqyaID: String { self["id"].string ?? "" } }
