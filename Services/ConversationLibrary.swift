import Foundation

@MainActor final class ConversationLibrary: ObservableObject {
    @Published private(set) var snapshot: ChatSnapshot
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    @Published private(set) var hasOlder = true
    private let remote: ChatRemote
    private let cache: ChatCache
    private var generation = UUID()
    private var refreshRequested = false
    init(owner: UUID, link: UUID, remote: ChatRemote, cache: ChatCache = ChatCache(), group: Bool = false) {
        self.remote = remote; self.cache = cache
        snapshot = (try? cache.load(owner: owner, link: link, group: group)) ?? ChatSnapshot(owner: owner, linkID: link, groupRoom: group ? true : nil)
    }
    func enqueue(_ body: String) -> Bool {
        do { var next = snapshot; _ = try next.enqueue(body); try cache.save(next); snapshot = next; message = nil; return true }
        catch { message = error.localizedDescription; return false }
    }
    func startUpdates() async {
        let token = generation
        await remote.startUpdates(owner: snapshot.owner, link: snapshot.linkID) { [weak self] in
            guard let self, token == self.generation else { return }
            if self.loading { self.refreshRequested = true }
            else { Task { guard token == self.generation else { return }; await self.refresh() } }
        }
    }
    func stopUpdates() { remote.stopUpdates() }
    func stop() { generation = UUID(); loading = false; refreshRequested = false; remote.stopUpdates() }
    func refresh(older: Bool = false) async {
        guard !loading else { return }
        let token = generation; loading = true
        defer {
            if token == generation {
                loading = false
                if refreshRequested {
                    refreshRequested = false
                    Task { guard token == self.generation else { return }; await self.refresh() }
                }
            }
        }
        let owner = snapshot.owner, link = snapshot.linkID
        do {
            while let pending = snapshot.pending.first {
                let confirmed = try await remote.send(owner: owner, message: pending)
                guard token == generation, !Task.isCancelled else { return }
                guard confirmed.acknowledges(pending) else { throw ChatError.mismatch }
                var next = snapshot; next.merge([confirmed]); try cache.save(next); snapshot = next
            }
            let cursor = older ? snapshot.messages.min(by: { $0.timestamp == $1.timestamp ? $0.id.uuidString < $1.id.uuidString : $0.timestamp < $1.timestamp }) : nil
            let page = try await remote.load(owner: owner, link: link, before: cursor)
            guard token == generation, !Task.isCancelled else { return }
            var next = snapshot; next.merge(page.messages, hiddenIDs: page.hidden); try cache.save(next); snapshot = next
            if older || cursor == nil { hasOlder = page.messages.count == 50 }
            message = nil
            if let latest = snapshot.messages.max(by: { $0.timestamp < $1.timestamp }) { try? await remote.markRead(owner: owner, link: link, through: latest.createdAt) }
        } catch {
            guard token == generation, !Task.isCancelled else { return }
            message = "Connexion indisponible. Tes messages restent conservés ; les envois non confirmés seront réessayés."
        }
    }
}
