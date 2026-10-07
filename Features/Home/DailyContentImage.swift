import SwiftUI

struct DailyContentImage: View {
    @EnvironmentObject var media: DailyContentMediaService
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeManager
    let url: String?
    var mode: ContentMode = .fill
    @State private var bytes: Data?
    @State private var loadedOwner: UUID?
    @State private var loadedURL: String?
    var body: some View {
        Group {
            if loadedOwner == store.identity?.id, loadedURL == url, let bytes, let image = UIImage(data: bytes) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
            } else { RoundedRectangle(cornerRadius: 12).fill(theme.gold.opacity(0.12)).overlay { Image(systemName: "photo").foregroundStyle(theme.muted) } }
        }.task(id: (store.identity?.id.uuidString ?? "anonymous") + (url ?? "")) {
            bytes = nil; loadedURL = nil
            guard let url else { return }
            let owner = store.identity?.id
            do {
                let result = try await media.image(url, owner: owner)
                guard !Task.isCancelled, owner == store.identity?.id else { return }
                loadedOwner = owner; loadedURL = url; bytes = result
            } catch { /* Keep the compact placeholder; content remains readable offline. */ }
        }
    }
}
