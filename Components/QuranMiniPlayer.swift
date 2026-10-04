import SwiftUI

struct QuranMiniPlayer: View {
    @ObservedObject var audio: QuranAudioService
    @EnvironmentObject private var theme: ThemeManager
    let catalog: QuranCatalog
    let close: () -> Void
    let pageRange: ClosedRange<Int>
    let sessionRange: ClosedRange<Int>?
    let saveRepeat: (AudioRepeatSettings) -> Void
    @State private var repeatSheet = false
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(catalog.surah(for: audio.verseID)?.name ?? "Le Coran").font(.subheadline)
                    Text("Verset \(audio.verseID - (catalog.surah(for: audio.verseID)?.start ?? 1) + 1)").font(.caption).foregroundStyle(theme.muted)
                }
                Spacer()
                Button { audio.play(audio.verseID - 1) } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 44) }.disabled(audio.verseID <= audio.playbackRange.lowerBound).accessibilityLabel("Verset précédent")
                Button { audio.toggle(start: audio.verseID) } label: { Group { if audio.loading { ProgressView() } else { Image(systemName: audio.playing ? "pause.fill" : "play.fill") } }.frame(width: 44, height: 44) }.accessibilityLabel("Lecture ou pause").accessibilityIdentifier("quran.audio.toggle")
                Button { audio.play(audio.verseID + 1) } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 44) }.disabled(audio.verseID >= audio.playbackRange.upperBound).accessibilityLabel("Verset suivant")
                Button(action: close) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Réduire le lecteur audio").accessibilityIdentifier("quran.audio.close")
            }
            HStack {
                Button { repeatSheet = true } label: { Label("Répétition ×\(audio.repeatSettings.countLabel)", systemImage: "repeat").font(.caption).frame(minHeight: 44) }.accessibilityIdentifier("quran.audio.repeat.open")
                Spacer()
                Text("Écoute \(audio.repetition) / \(audio.repeatSettings.countLabel)").font(.caption).accessibilityIdentifier("quran.audio.repeat.progress")
            }
            AudioTimelineView(timeline: audio.timeline, seek: audio.seek)
            if let error = audio.error { Text(error).font(.caption).foregroundStyle(theme.muted) }
        }.padding(.horizontal, 12).background(theme.surface).foregroundStyle(theme.accent)
            .sheet(isPresented: $repeatSheet) { AudioRepeatSheet(audio: audio, catalog: catalog, pageRange: pageRange, sessionRange: sessionRange, save: saveRepeat) }
    }
}

private struct AudioTimelineView: View {
    @ObservedObject var timeline: QuranAudioTimeline
    let seek: (Double) -> Void
    @State private var scrubbing = false
    @State private var draft = 0.0
    var body: some View {
        HStack(spacing: 8) {
            Text(QuranAudioTimeline.timeLabel(scrubbing ? draft : timeline.elapsed)).accessibilityIdentifier("quran.audio.elapsed")
            Slider(value: Binding(get: { scrubbing ? draft : timeline.elapsed }, set: { value in
                draft = value
                // Accessibility changes do not always send drag begin/end events.
                if !scrubbing { seek(value) }
            }), in: 0...max(1, timeline.duration)) { editing in
                if editing { draft = timeline.elapsed } else { seek(draft) }
                scrubbing = editing
            }.disabled(timeline.duration <= 0).frame(minHeight: 44).accessibilityLabel("Position dans le verset").accessibilityIdentifier("quran.audio.timeline")
            Text(QuranAudioTimeline.timeLabel(timeline.duration))
        }.font(.caption.monospacedDigit())
    }
}
