import SwiftUI

struct ConversationView: View {
    let name: String
    @StateObject private var library: ConversationLibrary
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var phase
    @State private var draft = ""
    init(name: String, owner: UUID, link: UUID, remote: ChatRemote, group: Bool = false) {
        self.name = name
        // StateObject's autoclosure reads the cache when this destination mounts,
        // rather than capturing a library prepared before messages were saved.
        _library = StateObject(wrappedValue: ConversationLibrary(owner: owner, link: link, remote: remote, group: group))
    }
    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if library.hasOlder {
                        Button("Messages précédents") { Task { await library.refresh(older: true) } }.frame(minHeight: 44).disabled(library.loading)
                    }
                    ForEach(library.snapshot.visible) { message in
                        let own = message.senderID == library.snapshot.owner
                        HStack {
                            if own { Spacer(minLength: 32) }
                            VStack(alignment: .leading, spacing: 5) {
                                if message.kind == "recitation", message.deletedAt == nil { Label("Récitation partagée", systemImage: "waveform").font(.caption) }
                                Text(message.displayBody).font(.subheadline).textSelection(.enabled)
                                HStack(spacing: 6) {
                                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                    if library.snapshot.pending.contains(where: { $0.id == message.id }) { Text("À synchroniser") }
                                }.font(.caption2).foregroundStyle(theme.muted)
                            }.padding(12).background(own ? theme.accent.opacity(0.1) : theme.surface, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(theme.text)
                            if !own { Spacer(minLength: 32) }
                        }.id(message.id).accessibilityIdentifier("chat.message.\(message.id.uuidString)")
                    }
                    if library.snapshot.visible.isEmpty { Text("Commence votre conversation.").font(.subheadline).foregroundStyle(theme.muted).padding(24) }
                }.padding(16)
            }.scrollDismissesKeyboard(.interactively)
                .onChange(of: library.snapshot.visible.last?.id, initial: true) { _, id in if let id { reader.scrollTo(id, anchor: .bottom) } }
        }.background(theme.background)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let message = library.message { Text(message).font(.caption).foregroundStyle(theme.muted) }
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Ton message…", text: $draft, axis: .vertical).lineLimit(1...5).padding(10).background(theme.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("chat.composer")
                        Button {
                            if library.enqueue(draft) { draft = ""; Task { await library.refresh() } }
                        } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44).background(theme.accent, in: Circle()).foregroundStyle(.white) }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.unicodeScalars.count > 2000).accessibilityLabel("Envoyer le message").accessibilityIdentifier("chat.send")
                    }
                }.padding(12).background(theme.background)
            }
            .navigationTitle(name).navigationBarTitleDisplayMode(.inline)
            .task {
                while !Task.isCancelled {
                    guard store.identity?.id == library.snapshot.owner else { library.stop(); return }
                    if phase == .active { await library.refresh() }
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                }
            }
            .onChange(of: store.identity?.id) { _, _ in library.stop() }
            .onChange(of: phase) { _, value in if value == .active { Task { await library.refresh() } } }
            .onDisappear { library.stop() }
    }
}
