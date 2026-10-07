import Foundation
import Combine

@MainActor final class QuranDownloadStatus: ObservableObject {
    static let shared = QuranDownloadStatus()
    @Published var phase = "idle"
    @Published var written: Int64 = 0
    @Published var expected: Int64 = 0
    @Published var preparedLines = 0
    var preparationProgress: Double { min(1, max(0, Double(preparedLines) / Double(QuranResourceService.lineCount))) }
    var progress: Double? { expected > 0 ? min(1, max(0, Double(written) / Double(expected))) : nil }
}

/// The existing resource installer owns this transfer independently of any screen.
final class QuranDownloadTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var session: URLSession?
    private var result: (URL, URLResponse)?
    private var failure: Error?
    private var lastReport: TimeInterval = 0
    func download(_ url: URL) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForResource = 3600
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            session.downloadTask(with: url).resume()
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastReport >= 0.1 || totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite else { return }
        lastReport = now
        Task { @MainActor in
            QuranDownloadStatus.shared.written = totalBytesWritten
            QuranDownloadStatus.shared.expected = totalBytesExpectedToWrite
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response else { throw URLError(.badServerResponse) }
            let retained = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
            try FileManager.default.moveItem(at: location, to: retained)
            result = (retained, response)
        } catch { failure = error }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let written = task.countOfBytesReceived, expected = task.countOfBytesExpectedToReceive
        Task { @MainActor in QuranDownloadStatus.shared.written = written; QuranDownloadStatus.shared.expected = expected }
        if let error = error ?? failure { continuation?.resume(throwing: error) }
        else if let result { continuation?.resume(returning: result) }
        else { continuation?.resume(throwing: URLError(.cannotCreateFile)) }
        continuation = nil; session.finishTasksAndInvalidate(); self.session = nil
    }
}
