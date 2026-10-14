import Foundation
import Combine
import Supabase

/// Disabled until both the server's privacy gate and the user's opt-in are enabled.
/// Stores no device ID, screen names, message content or IP addresses.
@MainActor final class UserActivityService: ObservableObject {
    @Published private(set) var available = false
    @Published private(set) var consenting = false
    @Published private(set) var message: String?
    private let client: SupabaseClient?
    private var owner: UUID?
    private var meter = ForegroundUsageMeter()
    private var session = UUID()
    private var current: UUID?
    private var chunks: [UserActivityChunk] = []
    private var tick: Task<Void, Never>?
    private var foreground = false
    private var syncing = false
    private var generation = UUID()
    init(client: SupabaseClient?) { self.client = client }
    private var file: URL? {
        guard let owner else { return nil }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("CoranNative/Usage/\(owner.uuidString.lowercased()).json")
    }
    private var preferencePrefix: String { "native.usage.\(owner?.uuidString.lowercased() ?? "none")." }
    private var revokeKey: String { "native.usage.revoke.\(owner?.uuidString.lowercased() ?? "none")" }
    func select(_ user: UUID?) async {
        if owner != user {
            phase(active: false); generation = UUID(); owner = user; available = false; consenting = false; chunks = []
            if let file, let data = try? Data(contentsOf: file) { chunks = (try? JSONDecoder().decode([UserActivityChunk].self, from: data)) ?? [] }
            let checked = UserDefaults.standard.double(forKey: preferencePrefix + "checked")
            available = Date().timeIntervalSince1970 - checked < 86400 && UserDefaults.standard.bool(forKey: preferencePrefix + "enabled")
            consenting = !UserDefaults.standard.bool(forKey: revokeKey) && UserDefaults.standard.bool(forKey: preferencePrefix + "consent")
            chunks.removeAll { $0.startedAt < Date().addingTimeInterval(-30 * 86400) }; persist()
        }
        let token = generation
        guard let user, let client, (try? await client.auth.session.user.id) == user else { return }
        do {
            if UserDefaults.standard.bool(forKey: revokeKey) {
                _ = try await client.rpc("native_activity_consent", params: ["p_consent": false]).execute()
                guard generation == token else { return }
                UserDefaults.standard.removeObject(forKey: revokeKey)
            }
            let status: JSONValue = try await client.rpc("native_activity_status").execute().value
            guard generation == token else { return }
            available = status["enabled"].bool == true
            consenting = status["consenting"].bool == true
            UserDefaults.standard.set(available, forKey: preferencePrefix + "enabled")
            UserDefaults.standard.set(consenting, forKey: preferencePrefix + "consent")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: preferencePrefix + "checked")
            if !available || !consenting { phase(active: false); chunks = []; persist() }
        } catch { if generation == token { message = "Suivi non activé ou connexion indisponible." } }
    }
    func consent(_ value: Bool) async {
        if !value {
            consenting = false; phase(active: false); chunks = []; persist()
            UserDefaults.standard.set(true, forKey: revokeKey)
            UserDefaults.standard.set(false, forKey: preferencePrefix + "consent")
            message = "Suivi désactivé sur cet appareil. Effacement serveur en attente de connexion."
        }
        guard let client, let owner, (try? await client.auth.session.user.id) == owner else { return }
        let token = generation
        do {
            _ = try await client.rpc("native_activity_consent", params: ["p_consent": value]).execute()
            guard generation == token else { return }
            consenting = value
            UserDefaults.standard.set(value, forKey: preferencePrefix + "consent")
            UserDefaults.standard.removeObject(forKey: revokeKey)
            if !value { phase(active: false); chunks = []; persist() }
            message = value ? "Participation enregistrée." : "Participation désactivée et données de suivi effacées."
        } catch { if generation == token { message = value ? "Modification non confirmée. Réessaie avec une connexion." : "Suivi désactivé sur cet appareil. Effacement serveur en attente de connexion." } }
    }
    func phase(active: Bool) {
        if active && foreground && tick != nil { return }
        foreground = active
        tick?.cancel(); tick = nil
        if !active { checkpoint(); meter.pause(); current = nil; Task { await synchronize() }; return }
        guard available, consenting, owner != nil else { return }
        session = UUID(); current = nil; meter.resume(uptime: ProcessInfo.processInfo.systemUptime)
        tick = Task { [weak self] in
            var count = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                checkpoint(); count += 1
                if count % 6 == 0 { await synchronize() }
            }
        }
    }
    private func checkpoint() {
        let seconds = meter.checkpoint(uptime: ProcessInfo.processInfo.systemUptime)
        guard seconds > 0, consenting, available else { return }
        if let current, let index = chunks.firstIndex(where: { $0.id == current }), chunks[index].seconds + seconds <= 60 {
            chunks[index].seconds += seconds
        } else {
            let id = UUID(); current = id
            chunks.append(UserActivityChunk(id: id, sessionID: session, startedAt: Date().addingTimeInterval(-Double(seconds)), seconds: seconds))
        }
        chunks.removeAll { $0.startedAt < Date().addingTimeInterval(-30 * 86400) }
        if chunks.count > 1000 { chunks.removeFirst(chunks.count - 1000) }
        persist()
    }
    private func persist() {
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(chunks) { try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    }
    func synchronize() async {
        guard !syncing, available, consenting, let owner, let client, !chunks.isEmpty else { return }
        syncing = true; defer { syncing = false }
        let token = generation, pending = Array(chunks.prefix(100))
        struct Item: Encodable { let id: UUID; let session_id: UUID; let started_at: String; let active_seconds: Int }
        struct Params: Encodable { let p_chunks: [Item] }
        do {
            guard try await client.auth.session.user.id == owner else { return }
            let payload = pending.map { Item(id: $0.id, session_id: $0.sessionID, started_at: ISO8601DateFormatter().string(from: $0.startedAt), active_seconds: $0.seconds) }
            _ = try await client.rpc("native_activity_ingest", params: Params(p_chunks: payload)).execute()
            guard generation == token else { return }
            // Remove only the exact acknowledged version; a growing foreground chunk is kept.
            chunks.removeAll { pending.contains($0) && $0.id != current }
            persist()
        } catch { /* Persist and retry on the next foreground checkpoint. */ }
    }
}
