import Foundation
import Supabase

@MainActor final class ProblemReportLibrary: ObservableObject {
    @Published private(set) var pending: [ProblemReport] = []
    @Published private(set) var sending = false
    @Published private(set) var notice: String?
    @Published private(set) var adminReports: [ProblemReport] = []
    @Published private(set) var adminLoading = false
    @Published private(set) var adminError: String?
    private(set) var owner: UUID?
    private let remote: ProblemReportRemote?
    private let repository: ProblemReportRepository?
    private let directory: URL
    private var generation = UUID()
    init(client: SupabaseClient? = nil, directory: URL? = nil, remote: ProblemReportRemote? = nil) {
        repository = client.map { ProblemReportRepository(client: $0) }
        self.remote = remote ?? client.map { ProblemReportRepository(client: $0) }
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/ProblemReports")
    }
    private func folder(_ owner: UUID) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased(), isDirectory: true) }
    private func save(_ values: [ProblemReport], owner: UUID) throws {
        try FileManager.default.createDirectory(at: folder(owner), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: folder(owner).appendingPathComponent("pending.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        pending = values
    }
    func select(_ user: UUID?) {
        guard user != owner else { return }
        generation = UUID(); owner = user; pending = []; sending = false; notice = nil
        adminReports = []; adminLoading = false; adminError = nil
        if let user, let bytes = try? Data(contentsOf: folder(user).appendingPathComponent("pending.json")),
           let rows = try? JSONDecoder().decode([ProblemReport].self, from: bytes) {
            pending = rows.filter { $0.user_id == user && $0.valid }
        }
    }
    func refreshAdmin() async {
        guard !adminLoading, let owner, let repository else { return }
        let token = generation; adminLoading = true
        defer { if token == generation { adminLoading = false } }
        do {
            let values = try await repository.list(owner: owner)
            guard token == generation else { return }; adminReports = values; adminError = nil
        } catch { if token == generation { adminError = "Les signalements n’ont pas pu être chargés. Vérifie la connexion et les droits administrateur." } }
    }
    func resolve(_ report: ProblemReport) async {
        guard let owner, let repository else { return }
        let token = generation
        do { try await repository.resolve(report, owner: owner); guard token == generation else { return }; await refreshAdmin() }
        catch { if token == generation { adminError = "La modification n’a pas été confirmée." } }
    }
    func adminScreenshot(_ report: ProblemReport) async -> URL? {
        guard let owner, let repository else { return nil }; let token = generation
        do { let url = try await repository.screenshot(report, owner: owner); return token == generation ? url : nil }
        catch { if token == generation { adminError = "La capture n’est pas disponible." }; return nil }
    }
    @discardableResult func enqueue(type: ProblemType, description: String, screenshot: Data?, version: String) throws -> UUID {
        guard let owner else { throw URLError(.userAuthenticationRequired) }
        if let screenshot, screenshot.count > 5 * 1024 * 1024 { throw CocoaError(.fileWriteOutOfSpace) }
        let report = try ProblemReport.create(owner: owner, type: type, description: description, screenshot: screenshot != nil, version: version)
        try FileManager.default.createDirectory(at: folder(owner), withIntermediateDirectories: true)
        if let screenshot { try screenshot.write(to: folder(owner).appendingPathComponent(report.id.uuidString.lowercased() + ".jpg"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        try save(pending + [report], owner: owner)
        notice = "Signalement enregistré. Il sera envoyé automatiquement dès que la connexion le permettra."
        return report.id
    }
    func synchronize() async {
        guard !sending, let owner, let remote, !pending.isEmpty else { return }
        let token = generation, batch = pending
        sending = true
        defer { if token == generation { sending = false } }
        for report in batch {
            guard token == generation else { return }
            let photo = report.screenshot_path == nil ? nil : folder(owner).appendingPathComponent(report.id.uuidString.lowercased() + ".jpg")
            do {
                try await remote.send(report, screenshot: photo)
                guard token == generation else { return }
                // Keep the outbox unless both the server and the local write confirmed success.
                try save(pending.filter { $0.id != report.id }, owner: owner)
                if let photo { try? FileManager.default.removeItem(at: photo) }
                notice = pending.isEmpty ? "Signalement envoyé à l’administrateur." : "Des signalements attendent encore leur envoi."
            } catch {
                guard token == generation else { return }
                notice = "Signalement conservé sur cet appareil. L’envoi sera réessayé automatiquement."
                if let error = error as? URLError, [.notConnectedToInternet, .networkConnectionLost, .timedOut, .userAuthenticationRequired].contains(error.code) { break }
            }
        }
    }
}
