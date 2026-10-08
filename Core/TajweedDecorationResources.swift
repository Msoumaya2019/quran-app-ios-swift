import Foundation
import CryptoKit

/// Small, unmodified QUL companion fonts. Page fonts remain downloaded on demand.
/// Kept separate from 1441 assets, and available to already installed pages offline.
enum TajweedDecorationResources {
    static let version = "qul-qcf-v4-decorations-1"
    static let fingerprints = [
        "quran-common.ttf": "63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa",
        "surah-name-v4.ttf": "026cfe8ac461531a7b1c8e4edd05ce3343f09e9c73447ff14c6bc93f3193d661"
    ]

    static func prepare(in directory: URL) throws {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("QCFDecorations") else {
            throw URLError(.fileDoesNotExist)
        }
        let manager = FileManager.default
        let common = directory.deletingLastPathComponent().appendingPathComponent("common")
        try manager.createDirectory(at: common, withIntermediateDirectories: true)
        for (name, fingerprint) in fingerprints {
            let target = common.appendingPathComponent(name)
            if let data = try? Data(contentsOf: target), digest(data) == fingerprint { continue }
            let original = root.appendingPathComponent(name)
            let data = try Data(contentsOf: original)
            guard digest(data) == fingerprint else { throw URLError(.cannotDecodeContentData) }
            // One shared copy for all 604 pages, including when bundle hard links are denied.
            if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
            do { try manager.linkItem(at: original, to: target) }
            catch { try data.write(to: target, options: .atomic) }
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
