import Foundation

struct UserActivityChunk: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionID: UUID
    let startedAt: Date
    var seconds: Int
}

/// Monotonic foreground time only; no background catch-up after process termination.
struct ForegroundUsageMeter {
    private(set) var lastUptime: TimeInterval?
    mutating func resume(uptime: TimeInterval) { lastUptime = uptime }
    mutating func checkpoint(uptime: TimeInterval) -> Int {
        guard let previous = lastUptime else { return 0 }
        let elapsed = max(0, min(10, uptime - previous))
        lastUptime = uptime - previous > 10 ? uptime : previous + floor(elapsed)
        return Int(elapsed)
    }
    mutating func pause() { lastUptime = nil }
}
