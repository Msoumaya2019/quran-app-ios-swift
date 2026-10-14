import SwiftUI

struct QuranDownloadsView: View {
    var body: some View {
        Form {
            Section("Coran Tajweed · hors connexion") { TajweedDownloadProgress() }
            Section("Sources") {
                Text("Quran fonts provided by Quran Foundation")
                Text("Décorations QCF V4 : QUL / Tarteel").font(.caption)
            }
        }.navigationTitle("Téléchargements et sources").navigationBarTitleDisplayMode(.inline)
    }
}
