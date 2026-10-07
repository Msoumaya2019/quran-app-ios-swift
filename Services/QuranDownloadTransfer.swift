import Foundation
import Combine

@MainActor final class QuranDownloadStatus: ObservableObject {
    static let shared = QuranDownloadStatus()
    @Published var phase = "idle"
    @Published var written: Int64 = 0
    @Published var expected: Int64 = 0
    var progress: Double? { expected > 0 ? min(1, max(0, Double(written) / Double(expected))) : nil }
}

/// The existing resource installer owns this transfer independently of any screen.
final class QuranDownloadTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var session: URLSession?
    private var result: (URL, URLResponse)?
    private var failure: Error?
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
        if let error = error ?? failure { continuation?.resume(throwing: error) }
        else if let result { continuation?.resume(returning: result) }
        else { continuation?.resume(throwing: URLError(.cannotCreateFile)) }
        continuation = nil; session.finishTasksAndInvalidate(); self.session = nil
    }
}
