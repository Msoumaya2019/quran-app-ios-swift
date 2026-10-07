import XCTest
import UIKit
@testable import CoranNative

final class EditorialMediaTests: XCTestCase {
    @MainActor func testImageIsPreparedAsJPEGAndKeepsStableUploadPath() async throws {
        let raw = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in UIColor.green.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }.pngData()!
        let item = try await EditorialAttachment.image(raw), owner = UUID()
        XCTAssertTrue(item.valid); XCTAssertEqual(item.mime, "image/jpeg"); XCTAssertEqual(item.field, "image_url")
        XCTAssertEqual(item.path(owner: owner), item.path(owner: owner))
        XCTAssertTrue(item.path(owner: owner).hasPrefix(owner.uuidString.lowercased() + "/"))
        XCTAssertTrue(item.data.starts(with: [0xff, 0xd8, 0xff]))
        do { _ = try await EditorialAttachment.image(Data("invalid".utf8)); XCTFail("Invalid image accepted") } catch {}
    }
    func testPrivateMediaResolvesOnlyCurrentBackendAndBucket() {
        let base = URL(string: "https://example.supabase.co")!
        XCTAssertEqual(DailyContentMediaService.privatePath(URL(string: "https://example.supabase.co/storage/v1/object/public/daily-content-media/user/image.jpg")!, base: base), "user/image.jpg")
        XCTAssertNil(DailyContentMediaService.privatePath(URL(string: "https://other.supabase.co/storage/v1/object/public/daily-content-media/user/image.jpg")!, base: base))
        XCTAssertNil(DailyContentMediaService.privatePath(URL(string: "https://example.supabase.co/storage/v1/object/public/another-bucket/user/image.jpg")!, base: base))
        XCTAssertNil(DailyContentMediaService.privatePath(URL(string: "https://example.supabase.co/storage/v1/object/public/daily-content-media/")!, base: base))
        XCTAssertNil(DailyContentMediaService.privatePath(URL(string: "http://example.supabase.co/storage/v1/object/public/daily-content-media/user/image.jpg")!, base: base))
    }
    @MainActor func testCachedPrivateImageWorksOfflineAndIsIsolatedByAccount() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = URL(string: "https://example.supabase.co")!, raw = "https://example.supabase.co/storage/v1/object/public/daily-content-media/user/image.jpg"
        let owner = UUID(), media = DailyContentMediaService(client: nil, baseURL: base, directory: directory)
        let bytes = Data([0xff, 0xd8, 0xff, 1])
        try bytes.write(to: media.cacheURL(raw, owner: owner), options: .atomic)
        let cached = try await media.image(raw, owner: owner); XCTAssertEqual(cached, bytes)
        do { _ = try await media.image(raw, owner: UUID()); XCTFail("Another account accessed cached image") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        do { _ = try await media.image(raw, owner: nil); XCTFail("Anonymous accessed cached image") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
    }
    func testInvalidAudioIsRejectedBeforeUpload() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try Data("invalid audio".utf8).write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        do { _ = try await EditorialAttachment.audio(file); XCTFail("Invalid audio accepted") } catch {}
        XCTAssertFalse(EditorialAttachment(kind: .audio, data: Data(), fileExtension: "mp3").valid)
        XCTAssertFalse(EditorialAttachment(kind: .audio, data: Data([1]), fileExtension: "wav").valid)
    }
}
