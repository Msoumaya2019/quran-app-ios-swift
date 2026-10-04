import Foundation

actor RecitationStorage {
    private let root: URL
    init(directory: URL? = nil) {
        root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Recitations")
    }
    private func directory(_ owner: UUID) -> URL { root.appendingPathComponent(owner.uuidString.lowercased(), isDirectory: true) }
    func list(owner: UUID) throws -> [Recitation] {
        let file = directory(owner).appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let items = try JSONDecoder().decode([Recitation].self, from: Data(contentsOf: file))
        guard items.allSatisfy({ $0.userID == owner }) else { throw URLError(.cannotParseResponse) }
        return items.sorted { $0.createdAt > $1.createdAt }
    }
    private func write(_ items: [Recitation], owner: UUID) throws {
        try FileManager.default.createDirectory(at: directory(owner), withIntermediateDirectories: true)
        try JSONEncoder().encode(items).write(to: directory(owner).appendingPathComponent("index.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func save(source: URL, start: Int, end: Int, durationMs: Int, owner: UUID) throws -> Recitation {
        guard Recitation.validRange(start, end), durationMs > 0 else { throw URLError(.cannotEncodeContentData) }
        let size = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber
        guard let size, size.intValue > 0, size.intValue <= 52_428_800 else { throw URLError(.dataLengthExceedsMaximum) }
        var items = try list(owner: owner)
        let id = UUID().uuidString.lowercased(), filename = "\(id).m4a"
        let destination = directory(owner).appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory(owner), withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let item = Recitation(id: id, userID: owner, start: start, end: end, durationMs: durationMs, createdAt: formatter.string(from: .now), storagePath: "\(owner.uuidString.lowercased())/\(filename)", localFile: filename, synced: false)
        items.append(item)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
            try write(items, owner: owner)
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
        return item
    }
    func file(for item: Recitation) throws -> URL {
        guard let filename = item.localFile, Recitation.safeFilename(filename) else { throw URLError(.fileDoesNotExist) }
        let file = directory(item.userID).appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: file.path) else { throw URLError(.fileDoesNotExist) }
        return file
    }
    func confirm(_ item: Recitation) throws {
        var items = try list(owner: item.userID)
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index].synced = true }
        try write(items, owner: item.userID)
    }
    func merge(_ remote: [Recitation], owner: UUID) throws {
        var items = try list(owner: owner)
        for incoming in remote where incoming.userID == owner && incoming.synced {
            if let index = items.firstIndex(where: { $0.id == incoming.id }) { items[index].synced = true }
            else { items.append(incoming) }
        }
        try write(items, owner: owner)
    }
    func cacheAudio(_ data: Data, for item: Recitation) throws -> URL {
        guard item.synced, !data.isEmpty, data.count <= 52_428_800 else { throw URLError(.cannotDecodeContentData) }
        var items = try list(owner: item.userID)
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { throw URLError(.fileDoesNotExist) }
        let name = "\(UUID().uuidString.lowercased()).m4a"
        let file = directory(item.userID).appendingPathComponent(name)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        items[index].localFile = name
        do { try write(items, owner: item.userID) } catch { try? FileManager.default.removeItem(at: file); throw error }
        return file
    }
}
