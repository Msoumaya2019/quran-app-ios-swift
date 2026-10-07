import Foundation
import Combine

@MainActor final class ModerationLibrary: ObservableObject {
    @Published private(set) var items: [JSONValue] = []
    @Published private(set) var names: [String: String] = [:]
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published private(set) var loadingAudio: String?
    @Published private(set) var message: String?
    @Published private(set) var hasMore = false
    let playback = RecitationPlaybackService()
    private let remote: ModerationRemote
    private var owner: UUID?
    var account: UUID? { owner }
    private var section: ModerationSection = .recitations
    private var generation = UUID()
    private var audioGeneration = UUID()
    private var offset = 0
    init(remote: ModerationRemote) { self.remote = remote }
    func select(_ owner: UUID?) {
        guard self.owner != owner else { return }; self.owner = owner; clear()
    }
    func clear() {
        generation = UUID(); stopAudio(); items = []; names = [:]; offset = 0; hasMore = false; loading = false; busy = false; message = nil
    }
    func stopAudio() { audioGeneration = UUID(); loadingAudio = nil; playback.stop() }
    func load(_ section: ModerationSection, more: Bool = false) async {
        guard let owner else { return }
        if !more { clear(); self.section = section }
        guard !loading, self.section == section, !more || hasMore else { return }
        let token = generation; loading = true
        defer { if generation == token { loading = false } }
        do {
            let rows = try await remote.rows(owner: owner, section: section, offset: offset)
            guard generation == token else { return }
            let ids = rows.compactMap { $0[section == .messages ? "sender_id" : section == .reports ? "reporter_id" : "user_id"].string }
            let profiles = try await remote.profiles(owner: owner, ids: ids)
            guard generation == token else { return }
            for row in profiles { if let id = row["id"].string, let name = row["display_name"].string { names[id.lowercased()] = name } }
            for row in rows where !items.contains(where: { $0["id"] == row["id"] }) { items.append(row) }
            offset += rows.count; hasMore = rows.count == 50
        } catch { guard generation == token else { return }; items = []; names = [:]; hasMore = false; stopAudio(); message = "Accès administrateur ou connexion indisponible. Réessaie après connexion." }
    }
    func name(_ id: String?) -> String { id.flatMap { names[$0.lowercased()] } ?? "Utilisateur" }
    func recording(_ id: String) async -> JSONValue? {
        guard let owner else { return nil }; let token = generation
        do { let row = try await remote.recording(owner: owner, id: id); return generation == token ? row : nil }
        catch { if generation == token { message = "La récitation associée n’est pas disponible." }; return nil }
    }
    func play(_ row: JSONValue) async {
        guard let owner, let id = row["id"].string else { return }
        if playback.activeID == id { stopAudio(); return }
        stopAudio(); let token = generation, audioToken = audioGeneration; loadingAudio = id; message = nil
        defer { if audioGeneration == audioToken { loadingAudio = nil } }
        do {
            let data = try await remote.audio(owner: owner, row: row)
            guard generation == token, audioGeneration == audioToken else { return }
            try playback.play(data: data, id: id)
        } catch { guard generation == token, audioGeneration == audioToken else { return }; message = "La récitation n’a pas pu être écoutée. Vérifie ta connexion et tes droits administrateur." }
    }
    func moderate(_ row: JSONValue, section: ModerationSection) async {
        guard let owner, !busy, self.section == section, let id = row["id"].string else { return }
        let token = generation; busy = true; message = nil
        defer { if generation == token { busy = false } }
        do {
            let confirmed: JSONValue
            switch section {
            case .messages: confirmed = try await remote.deleteMessage(owner: owner, id: id)
            case .reports: confirmed = try await remote.resolveReport(owner: owner, id: id)
            case .recitations: confirmed = try await remote.listened(owner: owner, id: id)
            }
            guard generation == token, let index = items.firstIndex(where: { $0["id"].string == id }) else { return }
            items[index] = confirmed
        } catch { if generation == token { message = "L’action n’a pas été confirmée. Réessaie après connexion." } }
    }
    func feedback(_ row: JSONValue, id: UUID, comment: String, voice: URL? = nil) async -> Bool {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let owner, !busy, let recitation = row["id"].string, (!text.isEmpty || voice != nil), text.count <= 2000 else { return false }
        let token = generation; busy = true; message = nil
        defer { if generation == token { busy = false } }
        do {
            if let voice {
                let data = try Data(contentsOf: voice, options: .mappedIfSafe)
                guard !data.isEmpty, data.count <= 52_428_800 else { throw URLError(.cannotDecodeContentData) }
                try await remote.voiceFeedback(owner: owner, recitation: recitation, id: id, comment: text, data: data)
            } else { try await remote.feedback(owner: owner, recitation: recitation, id: id, comment: text) }
            return generation == token
        }
        catch { if generation == token { message = "Le retour n’a pas été confirmé. Le texte reste disponible pour réessayer." }; return false }
    }
}
