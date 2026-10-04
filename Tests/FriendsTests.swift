import XCTest
@testable import CoranNative

final class FriendsTests: XCTestCase {
    func testOverviewRequiresAcceptedRelationAndExplicitSharing() throws {
        var snapshot = try fixture()
        snapshot.overviews = ["two": .object(["weekly_verses": .number(28)])]
        XCTAssertEqual(snapshot.overview(for: "two"), .null)
        snapshot.profiles = .array([.object(["id": .string("two"), "share_progress": .bool(true)])])
        XCTAssertEqual(snapshot.overview(for: "two")["weekly_verses"].int, 28)
        snapshot.links = .array([])
        XCTAssertEqual(snapshot.overview(for: "two"), .null)
    }
    func testOlderCacheWithoutOverviewRemainsReadable() throws {
        let snapshot = try fixture()
        let data = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "overviews")
        let decoded = try JSONDecoder().decode(FriendsSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.items().map(\.id), ["a"])
        XCTAssertNil(decoded.overviews)
    }
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private func fixture() throws -> FriendsSnapshot {
        let links = try JSONDecoder().decode(JSONValue.self, from: Data(#"[{"id":"a","requester_id":"00000000-0000-0000-0000-000000000001","recipient_id":"two","status":"accepted"},{"id":"b","requester_id":"three","recipient_id":"00000000-0000-0000-0000-000000000001","status":"pending"},{"id":"c","requester_id":"four","recipient_id":"00000000-0000-0000-0000-000000000001","status":"blocked"},{"id":"foreign","requester_id":"foreign","recipient_id":"two","status":"accepted"}]"#.utf8))
        let profiles = try JSONDecoder().decode(JSONValue.self, from: Data(#"[{"id":"two","display_name":"Yassine","share_online":true},{"id":"three","display_name":"Amélie","share_online":false}]"#.utf8))
        let inbox = try JSONDecoder().decode(JSONValue.self, from: Data(#"[{"other_id":"two","is_online":true},{"other_id":"three","is_online":true}]"#.utf8))
        return FriendsSnapshot(owner: owner, links: links, profiles: profiles, inbox: inbox)
    }
    func testOnlyAccountAcceptedFriendsAndIncomingRequests() throws {
        let snapshot = try fixture()
        XCTAssertEqual(snapshot.items().map(\.id), ["a"])
        XCTAssertEqual(snapshot.items(filter: "requests").map(\.id), ["b"])
        XCTAssertEqual(snapshot.items(filter: "requests").first?.incoming, true)
        XCTAssertEqual(snapshot.items(filter: "online").map(\.id), ["a"])
        XCTAssertFalse(snapshot.items(filter: "requests")[0].online)
    }
    func testSearchAndCacheKeepBackendContract() throws {
        let snapshot = try fixture()
        XCTAssertEqual(snapshot.items(search: "YASS").count, 1)
        XCTAssertEqual(snapshot.items(search: "amelie", filter: "requests").count, 1)
        XCTAssertTrue(snapshot.items(search: "absent").isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(FriendsSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }
    @MainActor func testCacheClearsOnAccountSwitchAndRejectsForeignOwner() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = try fixture()
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent(owner.uuidString.lowercased() + ".json"))
        let library = FriendsLibrary(client: nil, directory: directory)
        library.select(owner); XCTAssertEqual(library.snapshot?.items().count, 1)
        let other = UUID()
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent(other.uuidString.lowercased() + ".json"))
        library.select(other); XCTAssertEqual(library.snapshot?.owner, other); XCTAssertTrue(library.snapshot!.items().isEmpty)
        library.select(nil); XCTAssertNil(library.snapshot)
    }
}
