import SwiftUI

struct QuranDownloadProgress: View {
    @ObservedObject private var status = QuranDownloadStatus.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch status.phase {
            case "downloading":
                Text("Téléchargement en cours").font(.caption)
                if let progress = status.progress { ProgressView(value: progress); Text("\(Int(progress * 100)) %").font(.caption.monospacedDigit()) }
                else { ProgressView() }
                Text(ByteCountFormatter.string(fromByteCount: status.written, countStyle: .file) + (status.expected > 0 ? " / " + ByteCountFormatter.string(fromByteCount: status.expected, countStyle: .file) : " téléchargés")).font(.caption)
            case "installing": ProgressView("Préparation des pages…")
            case "error": Text("Le téléchargement a échoué · Réessayer en sélectionnant le Coran").font(.caption)
            case "ready": Label("Téléchargé", systemImage: "checkmark.circle").font(.caption)
            default: Text(QuranResourceService.shared.isReady(.edition1441) ? "✓ Téléchargé" : "Télécharger à la sélection").font(.caption)
            }
        }.accessibilityIdentifier("quran.download.progress")
    }
}
