import SwiftUI

struct ContentFavoritesView: View {
    @EnvironmentObject var favorites: ContentFavoritesLibrary
    @EnvironmentObject var theme: ThemeManager
    @State private var selected: DailyContent?
    var body: some View {
        List {
            let contents = favorites.cache?.contents ?? []
            if contents.isEmpty { ContentUnavailableView("Aucun favori", systemImage: "heart", description: Text("Ajoute un rappel ou une invocation à tes favoris.")) }
            ForEach(contents) { content in
                Button { selected = content } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.title ?? (content.type == "invocation" ? "Invocation" : "Rappel")).foregroundStyle(theme.text)
                        Text(content.french_text).font(.caption).lineLimit(2).foregroundStyle(theme.muted)
                    }.frame(minHeight: 44)
                }
            }
            if let message = favorites.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
        }.navigationTitle("Rappels et invocations favoris").navigationBarTitleDisplayMode(.inline)
            .task { await favorites.synchronize() }.refreshable { await favorites.synchronize() }
            .sheet(item: $selected) { DailyContentView(content: $0) }
    }
}
