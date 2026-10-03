import SwiftUI

struct QuranMiniPlayer: View {
    @ObservedObject var audio: QuranAudioService
    @EnvironmentObject private var theme: ThemeManager
    let catalog: QuranCatalog
    let close: () -> Void
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(catalog.surah(for: audio.verseID)?.name ?? "Le Coran").font(.subheadline)
                    Text("Verset \(audio.verseID - (catalog.surah(for: audio.verseID)?.start ?? 1) + 1)").font(.caption).foregroundStyle(theme.muted)
                }
                Spacer()
                Button { audio.play(audio.verseID - 1) } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 44) }.accessibilityLabel("Verset précédent")
                Button { audio.toggle(start: audio.verseID) } label: { Group { if audio.loading { ProgressView() } else { Image(systemName: audio.playing ? "pause.fill" : "play.fill") } }.frame(width: 44, height: 44) }.accessibilityLabel("Lecture ou pause")
                Button { audio.play(audio.verseID + 1) } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }.accessibilityLabel("Verset suivant")
                Button(action: close) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Réduire le lecteur audio")
            }
            if let error = audio.error { Text(error).font(.caption).foregroundStyle(theme.muted) }
        }.padding(.horizontal, 12).background(theme.surface).foregroundStyle(theme.accent)
    }
}
