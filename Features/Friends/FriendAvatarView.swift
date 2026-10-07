import SwiftUI

struct FriendAvatarView: View {
    @EnvironmentObject private var library: FriendsLibrary
    @EnvironmentObject private var theme: ThemeManager
    let user: UUID
    let name: String
    var size: CGFloat = 44
    @State private var data: Data?
    @State private var loadedOwner: UUID?
    var body: some View {
        Group {
            if loadedOwner == library.snapshot?.owner, library.avatarPath(for: user) != nil,
               let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { Text(String(name.prefix(1))).font(.headline).foregroundStyle(theme.accent) }
        }.frame(width: size, height: size).background(theme.accent.opacity(0.08)).clipShape(Circle())
            .task(id: "\(library.snapshot?.owner.uuidString ?? "")-\(library.avatarPath(for: user) ?? "")-\(library.avatarRevision)") {
                data = nil; loadedOwner = nil
                let owner = library.snapshot?.owner
                let bytes = await library.avatarData(for: user)
                guard !Task.isCancelled, owner == library.snapshot?.owner else { return }
                loadedOwner = owner; data = bytes
            }
    }
}
