import SwiftUI

struct TajweedDownloadProgress: View {
    @ObservedObject private var status = TajweedDownloadStatus.shared
    private var busy: Bool { status.phase == "sync" || status.phase == "downloading" }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mushaf de Médine • Règles de Tajweed").font(.caption)
            if status.phase == "sync" { ProgressView("Préparation des données du Mushaf…") }
            else if status.phase == "downloading" {
                Text("Téléchargement du Coran Tajweed").font(.caption)
                ProgressView(value: status.progress)
                Text("\(Int(status.progress * 100)) % · \(status.completed) / 604 pages").font(.caption.monospacedDigit())
                if status.expected > 0 { Text("Fichier actuel : " + ByteCountFormatter.string(fromByteCount: status.written, countStyle: .file) + " / " + ByteCountFormatter.string(fromByteCount: status.expected, countStyle: .file)).font(.caption2) }
            } else if TajweedMushafResourceService.installed { Label("Téléchargé · disponible hors connexion", systemImage: "checkmark.circle").font(.caption) }
            if let error = status.error { Text(error).font(.caption).foregroundStyle(.secondary) }
            if !busy && !TajweedMushafResourceService.installed {
                Button(status.phase == "error" ? "Reprendre le téléchargement" : "Télécharger pour lire hors connexion") {
                    Task {
                        do { try await TajweedMushafResourceService.shared.download() }
                        catch { status.phase = "error"; status.error = "Téléchargement indisponible. Vérifie ta connexion puis réessaie." }
                    }
                }.frame(minHeight: 44)
            }
            Text("Quran fonts provided by Quran Foundation").font(.caption2).foregroundStyle(.secondary)
        }.accessibilityIdentifier("quran.tajweed.download")
    }
}
