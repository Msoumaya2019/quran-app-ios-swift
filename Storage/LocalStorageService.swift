import Foundation

protocol HomeCache: Sendable {
    func load(userID: UUID) throws -> HomeSnapshot?
    func save(_ snapshot: HomeSnapshot, userID: UUID) throws
}
struct LocalStorageService: HomeCache {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative", isDirectory: true)
    }
    private func url(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString.lowercased() + ".json") }
    func load(userID: UUID) throws -> HomeSnapshot? {
        guard FileManager.default.fileExists(atPath: url(userID).path) else { return nil }
        return try JSONDecoder().decode(HomeSnapshot.self, from: Data(contentsOf: url(userID)))
    }
    func save(_ snapshot: HomeSnapshot, userID: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url(userID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
