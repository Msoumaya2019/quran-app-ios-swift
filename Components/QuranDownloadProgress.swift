import SwiftUI

struct QuranDownloadProgress: View {
    let retry: () -> Void
    @ObservedObject private var status = QuranDownloadStatus.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch status.phase {
            case "downloading":
                Text("Téléchargement en cours").font(.caption)
                if let progress = status.progress { ProgressView(value: progress); Text("\(Int(progress * 100)) %").font(.caption.monospacedDigit()) }
                else { ProgressView() }
                Text(ByteCountFormatter.string(fromByteCount: status.written, countStyle: .file) + (status.expected > 0 ? " / " + ByteCountFormatter.string(fromByteCount: status.expected, countStyle: .file) : " téléchargés")).font(.caption)
            case "installing":
                Text("Préparation des pages…").font(.caption)
                ProgressView(value: status.preparationProgress)
                Text("\(Int(status.preparationProgress * 100)) % · \(status.preparedLines / 15) / 604 pages").font(.caption.monospacedDigit())
            case "error": Text("Le téléchargement a échoué").font(.caption); Button("Réessayer", action: retry).frame(minHeight: 44)
            case "ready": Label("Téléchargé", systemImage: "checkmark.circle").font(.caption)
            default:
                if QuranResourceService.shared.isReady(.edition1441) { Label("Téléchargé", systemImage: "checkmark.circle").font(.caption) }
                else { Button("Télécharger", action: retry).frame(minHeight: 44) }
            }
        }.accessibilityIdentifier("quran.download.progress")
    }
}
