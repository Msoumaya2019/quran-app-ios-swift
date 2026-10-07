import Foundation
import Combine

@MainActor final class EditorialLibrary: ObservableObject {
    @Published private(set) var categories: [JSONValue] = []
    @Published private(set) var contents: [JSONValue] = []
    @Published private(set) var schedules: [JSONValue] = []
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published private(set) var hasMore = false
    @Published private(set) var message: String?
    private let remote: EditorialRemote
    private var owner: UUID?
    private var generation = UUID()
    private var kind: EditorialKind = .reminder
    private var offset = 0
    init(remote: EditorialRemote) { self.remote = remote }
    func select(_ owner: UUID?) {
        guard self.owner != owner else { return }
        self.owner = owner; generation = UUID(); categories = []; contents = []; schedules = []
        loading = false; busy = false; hasMore = false; offset = 0; message = nil
    }
    func load(_ kind: EditorialKind, more: Bool = false) async {
        guard let owner, !busy, !loading, !more || (hasMore && self.kind == kind) else { return }
        if !more { generation = UUID(); self.kind = kind; contents = []; schedules = []; offset = 0 }
        let token = generation; loading = true; message = nil
        defer { if generation == token { loading = false } }
        do {
            let snapshot = try await remote.load(owner: owner, kind: kind, offset: offset)
            guard generation == token else { return }
            categories = snapshot.categories; schedules = snapshot.schedules
            for row in snapshot.contents where !contents.contains(where: { $0["id"] == row["id"] }) { contents.append(row) }
            offset += snapshot.contents.count; hasMore = snapshot.contents.count == 30
        } catch {
            guard generation == token else { return }
            categories = []; contents = []; schedules = []; hasMore = false
            message = "Accès administrateur ou connexion indisponible. Réessaie après connexion."
        }
    }
    func save(_ draft: EditorialDraft) async -> Bool {
        guard let owner, !busy, !loading else { return false }
        if let error = draft.validation(categories: categories) { message = error; return false }
        let token = generation; busy = true; message = nil
        defer { if generation == token { busy = false } }
        do {
            let confirmed = try await remote.save(owner: owner, draft: draft)
            guard generation == token else { return false }
            contents.removeAll { $0["id"] == confirmed["id"] }
            if confirmed["type"].string == kind.rawValue { contents.insert(confirmed, at: 0) }
            if !draft.date.isEmpty {
                schedules.removeAll { $0["type"] == confirmed["type"] && $0["display_date"].string == draft.date }
                schedules.append(.object(["content_id": confirmed["id"], "type": confirmed["type"], "display_date": .string(draft.date)]))
            }
            return true
        } catch { if generation == token { message = "L’enregistrement n’a pas été confirmé. Réessaie après connexion." }; return false }
    }
    func saveCategory(_ row: JSONValue) async -> Bool {
        guard let owner, !busy, !loading, EditorialDraft.validCategory(row) else { return false }
        let token = generation; busy = true; message = nil
        defer { if generation == token { busy = false } }
        do {
            let confirmed = try await remote.saveCategory(owner: owner, row: row)
            guard generation == token else { return false }
            categories.removeAll { $0["id"] == confirmed["id"] }; categories.append(confirmed)
            return true
        } catch { if generation == token { message = "La catégorie n’a pas été enregistrée." }; return false }
    }
    func delete(_ row: JSONValue, category: Bool = false) async {
        guard let owner, !busy, !loading, let id = row["id"].string else { return }
        let token = generation; busy = true; message = nil
        defer { if generation == token { busy = false } }
        do {
            try await remote.delete(owner: owner, id: id, category: category)
            guard generation == token else { return }
            if category { categories.removeAll { $0["id"].string == id } }
            else {
                if contents.contains(where: { $0["id"].string == id }) { offset = max(0, offset - 1) }
                contents.removeAll { $0["id"].string == id }; schedules.removeAll { $0["content_id"].string == id }
            }
        } catch { if generation == token { message = category ? "Suppression impossible. Désactive une catégorie encore utilisée." : "La suppression n’a pas été confirmée." } }
    }
    func unschedule(_ row: JSONValue) async {
        guard let owner, !busy, !loading else { return }
        let token = generation; busy = true; message = nil
        defer { if generation == token { busy = false } }
        do {
            try await remote.unschedule(owner: owner, row: row)
            guard generation == token else { return }
            schedules.removeAll { $0 == row }
        } catch { if generation == token { message = "La déprogrammation n’a pas été confirmée." } }
    }
}
