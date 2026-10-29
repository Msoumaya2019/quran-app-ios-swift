import Foundation
import Supabase
import AVFoundation

/// Uses the Expo catalogue and private storage bucket; downloads reuse the Mushaf transfer engine.
@MainActor final class RoqyaLibrary: ObservableObject {
    @Published private(set) var catalog: [JSONValue] = []
    @Published private(set) var message: String?
    @Published private(set) var loading = false
    @Published private(set) var downloads: [String: Double] = [:]
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var selected: [String: String] = [:]
    @Published private(set) var listens: [String: JSONValue] = [:]
    let playback = RecitationPlaybackService()
    @Published private(set) var adminRows: [String: [JSONValue]] = [:]
    @Published private(set) var adminBusy = false
    private let client: SupabaseClient?
    private let directory: URL
    private var owner: UUID?
    private var generation = UUID()
    private var opening = UUID()
    private var running: Set<String> = []
    init(client: SupabaseClient?, directory: URL? = nil) {
        self.client = client
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Roqya")
        if let data = try? Data(contentsOf: self.directory.appendingPathComponent("catalog.json")), let cached = try? JSONDecoder().decode([JSONValue].self, from: data) { catalog = cached }
        playback.onCheckpoint = { [weak self] id, position, duration in
            guard let self, self.owner != nil, position > 0 else { return }
            let previous = Double(self.listens[id]?["position"].int ?? 0)
            guard abs(position - previous) >= 10 || duration > 0 && position >= duration - 1 else { return }
            self.listens[id] = .object(["position": .number(position), "duration": .number(duration)]); self.save()
        }
    }
    func select(_ owner: UUID?) {
        guard self.owner != owner else { return }
        checkpoint(); playback.stop(); self.owner = owner; generation = UUID(); opening = UUID()
        favorites = []; listens = [:]; selected = [:]; adminRows = [:]; message = nil
        if let file = preferencesFile, let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(JSONValue.self, from: data) {
            favorites = Set(value["favorites"].array.compactMap(\.string)); listens = value["listens"].object; selected = value["selected"].object.compactMapValues(\.string)
        }
    }
    private var preferencesFile: URL? { owner.map { directory.appendingPathComponent("\($0.uuidString.lowercased()).json") } }
    private func write<T: Encodable>(_ value: T, to file: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    private func save() {
        guard let file = preferencesFile else { return }
        do { try write(JSONValue.object(["favorites": .array(favorites.sorted().map(JSONValue.string)), "listens": .object(listens), "selected": .object(selected.mapValues(JSONValue.string))]), to: file) }
        catch { message = "Les préférences Roqya n’ont pas pu être enregistrées." }
    }
    func toggleFavorite(_ id: String) { if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }; save() }
    func selectAudio(roqya: String, audio: String) { selected[roqya] = audio; save() }
    func closePlayback() { opening = UUID(); checkpoint(); playback.stop() }
    func checkpoint() {
        guard let id = playback.activeID, playback.elapsed > 0 else { return }
        listens[id] = .object(["position": .number(playback.elapsed), "duration": .number(playback.duration)])
        save()
    }
    static func validMediaURL(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }; return url
    }
    static func audios(_ row: JSONValue) -> [JSONValue] {
        row["roqya_audios"].array.filter { $0["enabled"].bool == true && $0["roqya_reciters"]["enabled"].bool == true && ($0["storage_path"].string?.isEmpty == false || validMediaURL($0["audio_url"].string) != nil) }
            .sorted { ($0["sort_order"].int ?? 0) < ($1["sort_order"].int ?? 0) }
    }
    func refresh() async {
        guard !loading, let client else { return }
        loading = true; defer { loading = false }
        do {
            let rows: [JSONValue] = try await client.from("roqyas").select("*,roqya_audios(*,roqya_reciters(*))").eq("enabled", value: true).order("sort_order").execute().value
            let enabled = rows.filter { $0["enabled"].bool == true && !Self.audios($0).isEmpty }
            try write(enabled, to: directory.appendingPathComponent("catalog.json")); catalog = enabled; message = nil
        } catch { message = "Catalogue indisponible. Les Roqyas déjà enregistrées restent accessibles. Vérifie la connexion et les migrations Roqya." }
    }
    private func filename(_ audio: JSONValue) -> URL? {
        guard let id = audio["id"].string, UUID(uuidString: id) != nil else { return nil }
        let ext = URL(fileURLWithPath: audio["storage_path"].string ?? URL(string: audio["audio_url"].string ?? "")?.path ?? "audio.mp3").pathExtension.lowercased()
        return directory.appendingPathComponent(id.lowercased() + (["mp3", "m4a"].contains(ext) ? "." + ext : ".mp3"))
    }
    private func source(_ audio: JSONValue) -> String { "\(audio["storage_path"].string ?? audio["audio_url"].string ?? ""):\(audio["file_size"].int ?? 0)" }
    func localFile(_ audio: JSONValue) -> URL? {
        guard let file = filename(audio), let data = try? Data(contentsOf: file.appendingPathExtension("json")),
              let manifest = try? JSONDecoder().decode(JSONValue.self, from: data), manifest["source"].string == source(audio),
              let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0,
              size == manifest["size"].int, audio["file_size"].int == nil || audio["file_size"].int == size else { return nil }
        return file
    }
    private func remoteURL(_ audio: JSONValue) async throws -> URL {
        if let path = audio["storage_path"].string, !path.isEmpty {
            guard let client, !path.contains(".."), !path.hasPrefix("/") else { throw URLError(.badURL) }
            return try await client.storage.from("roqya-audio").createSignedURL(path: path, expiresIn: 21600)
        }
        guard let url = Self.validMediaURL(audio["audio_url"].string) else { throw URLError(.badURL) }; return url
    }
    func play(_ audio: JSONValue) async {
        checkpoint(); playback.stop(); opening = UUID(); let token = opening, account = generation
        playback.reserveFocus { [weak self] in self?.opening = UUID() }
        do {
            let url: URL
            if let file = localFile(audio) { url = file } else { url = try await remoteURL(audio) }
            guard token == opening, account == generation else { return }
            let id = audio["id"].string ?? ""
            let saved = listens[id], position = Double(saved?["position"].int ?? 0), duration = Double(saved?["duration"].int ?? 0)
            try playback.playStream(url: url, id: id, position: duration > 0 && position >= duration - 2 ? 0 : position); message = nil
        } catch { if token == opening && account == generation { message = "Audio indisponible. Réessaie ou choisis une Roqya téléchargée." } }
    }
    func download(_ audio: JSONValue) async {
        guard let id = audio["id"].string, let file = filename(audio), !running.contains(id), localFile(audio) == nil else { return }
        running.insert(id); downloads[id] = 0
        defer { running.remove(id); downloads.removeValue(forKey: id) }
        do {
            let url = try await remoteURL(audio)
            let transfer = QuranDownloadTransfer { [weak self] written, total in
                Task { @MainActor in self?.downloads[id] = total > 0 ? min(1, Double(written) / Double(total)) : -1 }
            }
            let (temporary, response) = try await transfer.download(url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let size = (try temporary.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, size > 0,
                  audio["file_size"].int == nil || audio["file_size"].int == size else { throw URLError(.badServerResponse) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let staged = directory.appendingPathComponent(UUID().uuidString + "." + file.pathExtension)
            try FileManager.default.moveItem(at: temporary, to: staged)
            defer { try? FileManager.default.removeItem(at: staged) }
            guard try await AVURLAsset(url: staged).load(.isPlayable) else { throw URLError(.cannotDecodeContentData) }
            try? FileManager.default.removeItem(at: file.appendingPathExtension("json"))
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            try FileManager.default.moveItem(at: staged, to: file)
            try write(JSONValue.object(["source": .string(source(audio)), "size": .number(Double(size))]), to: file.appendingPathExtension("json"))
            message = nil
        } catch { message = "Le téléchargement a échoué. Vérifie la connexion et l’espace disponible, puis réessaie." }
    }
    func removeDownload(_ audio: JSONValue) {
        guard let id = audio["id"].string, !running.contains(id), let file = filename(audio) else { return }
        if playback.activeID == id { checkpoint(); playback.stop() }
        do {
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            if FileManager.default.fileExists(atPath: file.appendingPathExtension("json").path) { try FileManager.default.removeItem(at: file.appendingPathExtension("json")) }
            objectWillChange.send()
        } catch { message = "Le fichier n’a pas pu être supprimé." }
    }
    private func adminClient() async throws -> SupabaseClient {
        guard let client, let owner, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        let rows: [JSONValue] = try await client.from("app_admins").select("user_id").eq("user_id", value: owner.uuidString).limit(1).execute().value
        guard rows.contains(where: { $0["user_id"].string?.lowercased() == owner.uuidString.lowercased() }) else { throw URLError(.userAuthenticationRequired) }
        guard self.owner == owner, try await client.auth.session.user.id == owner else { throw CancellationError() }
        return client
    }
    func refreshAdmin() async {
        guard !adminBusy else { return }
        adminBusy = true; let account = generation
        defer { adminBusy = false }
        do {
            let client = try await adminClient()
            async let roqyas: [JSONValue] = client.from("roqyas").select().order("sort_order").execute().value
            async let reciters: [JSONValue] = client.from("roqya_reciters").select().order("sort_order").execute().value
            async let audios: [JSONValue] = client.from("roqya_audios").select().order("sort_order").execute().value
            let result = try await (roqyas, reciters, audios)
            guard account == generation else { return }
            adminRows = ["roqyas": result.0, "roqya_reciters": result.1, "roqya_audios": result.2]; message = nil
        } catch { if account == generation { message = "Administration Roqya indisponible. Vérifie les droits et les migrations roqya / roqya-admin." } }
    }
    func saveAdmin(table: String, row: JSONValue) async -> Bool {
        guard !adminBusy, ["roqyas", "roqya_reciters", "roqya_audios"].contains(table), Self.validAdminRow(table: table, row: row) else { message = "Vérifie les champs obligatoires et les adresses HTTPS."; return false }
        adminBusy = true; let account = generation
        defer { adminBusy = false }
        do {
            let client = try await adminClient()
            let fields = ["enabled", "sort_order"] + (table == "roqyas" ? ["title", "description", "category", "image_url"] : table == "roqya_reciters" ? ["name", "description", "photo_url"] : ["roqya_id", "reciter_id", "storage_path", "audio_url", "duration_seconds", "file_size"])
            let value = JSONValue.object(Dictionary(uniqueKeysWithValues: fields.map { ($0, row[$0]) }))
            if let id = row["id"].string {
                let _: [JSONValue] = try await client.from(table).update(value).eq("id", value: id).select("id").execute().value
            } else {
                let _: [JSONValue] = try await client.from(table).insert(value).select("id").execute().value
            }
            guard account == generation else { return false }; message = nil; return true
        } catch { if account == generation { message = "Enregistrement Roqya non confirmé. Réessaie après avoir vérifié la connexion et les droits." }; return false }
    }
    static func validAdminRow(table: String, row: JSONValue) -> Bool {
        guard row["sort_order"].int != nil, row["enabled"].bool != nil else { return false }
        for field in ["image_url", "photo_url", "audio_url"] { if let url = row[field].string, !url.isEmpty, validMediaURL(url) == nil { return false } }
        if table == "roqyas" { return row["title"].string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        if table == "roqya_reciters" { return row["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        guard UUID(uuidString: row["roqya_id"].string ?? "") != nil, UUID(uuidString: row["reciter_id"].string ?? "") != nil, (row["duration_seconds"].int ?? 0) > 0 else { return false }
        if let path = row["storage_path"].string, !path.isEmpty { return !path.hasPrefix("/") && !path.contains("..") && ["mp3", "m4a"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) }
        return validMediaURL(row["audio_url"].string) != nil
    }
    func uploadAdmin(file: URL, audio: Bool) async throws -> JSONValue {
        let account = generation, client = try await adminClient()
        guard let owner else { throw URLError(.userAuthenticationRequired) }
        let ext = file.pathExtension.lowercased()
        guard (audio ? ["mp3", "m4a"] : ["png", "jpg", "jpeg", "webp"]).contains(ext) else { throw URLError(.cannotDecodeContentData) }
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= (audio ? 200 : 10) * 1024 * 1024, account == generation else { throw URLError(.dataLengthExceedsMaximum) }
        let bucket = audio ? "roqya-audio" : "roqya-images", path = "\(owner.uuidString.lowercased())/\(UUID().uuidString.lowercased()).\(ext)"
        let mime = audio ? (ext == "mp3" ? "audio/mpeg" : "audio/mp4") : (ext == "png" ? "image/png" : ext == "webp" ? "image/webp" : "image/jpeg")
        try await client.storage.from(bucket).upload(path, fileURL: file, options: FileOptions(contentType: mime, upsert: false))
        guard account == generation else { throw CancellationError() }
        if audio { return .object(["storage_path": .string(path), "file_size": .number(Double(size))]) }
        let url = try client.storage.from(bucket).getPublicURL(path: path)
        return .object(["url": .string(url.absoluteString)])
    }

}
