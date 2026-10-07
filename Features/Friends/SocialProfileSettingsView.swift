import SwiftUI
import PhotosUI

struct SocialProfileSettingsView: View {
    @EnvironmentObject private var library: FriendsLibrary
    @EnvironmentObject private var theme: ThemeManager
    @State private var name = ""
    @State private var online = false
    @State private var progress = false
    @State private var initialized = false
    @State private var busy = false
    @State private var saved = false
    @State private var photo: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoMessage: String?
    @State private var preparingPhoto = false
    var body: some View {
        Form {
            Section("Photo de profil") {
                if let owner = library.snapshot?.owner {
                    HStack {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(Circle())
                        } else { FriendAvatarView(user: owner, name: name, size: 64) }
                        PhotosPicker("Choisir une photo", selection: $photo, matching: .images).disabled(busy || preparingPhoto)
                    }
                    if photoData != nil {
                        Button("Enregistrer la photo") {
                            Task { busy = true; let success = await library.saveAvatar(photoData); busy = false
                                if success { photoData = nil; photo = nil; photoMessage = "Photo enregistrÈe" }
                            }
                        }.disabled(busy || preparingPhoto)
                    }
                    if library.avatarPath(for: owner) != nil {
                        Button("Retirer ma photo", role: .destructive) {
                            Task { busy = true; let success = await library.saveAvatar(nil); busy = false
                                if success { photoData = nil; photo = nil; photoMessage = "Photo retirÈe" }
                            }
                        }.disabled(busy || preparingPhoto)
                    }
                }
                if preparingPhoto { ProgressView("PrÈparation de la photoÖ") }
                if let photoMessage { Text(photoMessage).font(.caption).foregroundStyle(theme.muted) }
            }
            Section("Mon profil ami") {
                TextField("Nom affich√©", text: $name).accessibilityIdentifier("social.profile.name")
                Text("Entre 2 et 40 caract√®res.").font(.caption).foregroundStyle(theme.muted)
            }
            Section("Partage avec mes amis") {
                Toggle("Partager mon statut en ligne", isOn: $online).accessibilityIdentifier("social.profile.online")
                Toggle("Partager ma progression", isOn: $progress).accessibilityIdentifier("social.profile.progress")
                Text("Ces pr√©f√©rences sont communes aux deux applications et seront appliqu√©es apr√®s confirmation du serveur.").font(.caption).foregroundStyle(theme.muted)
            }
            if let message = library.message { Text(message).font(.caption) }
            if saved { Label("Pr√©f√©rences enregistr√©es", systemImage: "checkmark.circle").foregroundStyle(theme.accent) }
            Button("Enregistrer") {
                Task { busy = true; saved = false; saved = await library.saveSocialProfile(name: name, online: online, progress: progress); busy = false }
            }.disabled(busy || !(2...40).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count))
                .accessibilityIdentifier("social.profile.save")
        }.navigationTitle("Profil et confidentialit√©").navigationBarTitleDisplayMode(.inline)
            .task(id: photo) {
                guard let photo else { return }
                let owner = library.snapshot?.owner; preparingPhoto = true
                defer { preparingPhoto = false }
                do {
                    guard let raw = try await photo.loadTransferable(type: Data.self) else { return }
                    let prepared = try await ProblemScreenshot.prepare(raw, maxPixelSize: 800, maxBytes: 2 * 1024 * 1024)
                    guard !Task.isCancelled, owner == library.snapshot?.owner else { return }
                    photoData = prepared; photoMessage = nil
                } catch { if !Task.isCancelled { photoMessage = "Cette photo ne peut pas Ítre prÈparÈe." } }
            }
            .onChange(of: library.snapshot?.owner) { _, _ in
                photo = nil; photoData = nil; photoMessage = nil; name = ""; initialized = false
            }
            .task {
                guard !initialized else { return }; initialized = true
                let profile = library.snapshot?.profile ?? .null
                name = profile["display_name"].string ?? ""
                online = profile["share_online"].bool == true
                progress = profile["share_progress"].bool == true
            }
    }
}
