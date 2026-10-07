import Foundation
import AVFoundation

struct EditorialAttachment: Sendable {
    enum Kind: String, Sendable { case image, audio }
    let id = UUID()
    let kind: Kind
    let data: Data
    let fileExtension: String
    var mime: String { kind == .image ? "image/jpeg" : fileExtension == "mp3" ? "audio/mpeg" : fileExtension == "aac" ? "audio/aac" : "audio/mp4" }
    var field: String { kind == .image ? "image_url" : "audio_url" }
    func path(owner: UUID) -> String { "\(owner.uuidString.lowercased())/\(id.uuidString.lowercased()).\(fileExtension)" }
    var valid: Bool {
        guard !data.isEmpty else { return false }
        if kind == .image { return fileExtension == "jpg" && data.count <= 5 * 1024 * 1024 && data.starts(with: [0xff, 0xd8, 0xff]) }
        return ["mp3", "m4a", "aac"].contains(fileExtension) && data.count <= 30 * 1024 * 1024
    }
    static func image(_ raw: Data) async throws -> Self {
        let value = Self(kind: .image, data: try await ProblemScreenshot.prepare(raw), fileExtension: "jpg")
        guard value.valid else { throw CocoaError(.fileReadCorruptFile) }; return value
    }
    static func audio(_ url: URL) async throws -> Self {
        try await Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard ["mp3", "m4a", "aac"].contains(url.pathExtension.lowercased()),
                  let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0, size <= 30 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            let value = Self(kind: .audio, data: try Data(contentsOf: url), fileExtension: url.pathExtension.lowercased())
            guard value.valid, try AVAudioPlayer(data: value.data).duration > 0 else { throw CocoaError(.fileReadCorruptFile) }
            return value
        }.value
    }
}
