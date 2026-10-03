import XCTest
@testable import CoranNative

final class ContractTests: XCTestCase {
    func testUnknownRNFieldsSurviveCacheRoundTrip() throws {
        let original = Data(#"{"schema":1,"future":{"history":[1,true,null]},"reader":{"mushaf":"coran_1441"}}"#.utf8)
        let state = try JSONDecoder().decode(JSONValue.self, from: original)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(state)), state)
        XCTAssertEqual(state["reader"]["mushaf"].string, "coran_1441")
    }
    func testWeekUsesParisCalendarAcrossDSTAndKeepsSchedule() throws {
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-25T22:59:00Z"))
        let state: JSONValue = .object(["sessions": .array([
            .object(["scheduledDate": .string("2026-10-20"), "completedAt": .string("2026-10-19T12:00:00Z"), "status": .string("done")]),
            .object(["scheduledDate": .string("2026-10-21"), "status": .string("todo")])])])
        let projection = HomeProjection(snapshot: HomeSnapshot(state: state), now: now, timeZone: paris)
        XCTAssertEqual(projection.week.start, "2026-10-19"); XCTAssertEqual(projection.week.end, "2026-10-25"); XCTAssertEqual(projection.week.ratio, 0.5)
        let monday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-25T23:01:00Z"))
        XCTAssertEqual(HomeProjection(snapshot: HomeSnapshot(state: state), now: monday, timeZone: paris).week.ratio, 0)
        XCTAssertEqual(state["sessions"].array.count, 2)
    }
    func testAtomicCacheIsIsolatedPerAccount() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = LocalStorageService(directory: dir), a = UUID(), b = UUID()
        try cache.save(HomeSnapshot(displayName: "A"), userID: a)
        XCTAssertEqual(try cache.load(userID: a)?.displayName, "A"); XCTAssertNil(try cache.load(userID: b))
    }
    func testMetadataMatchesExistingQuran() {
        let catalog = QuranCatalog()
        XCTAssertEqual(catalog.surahs.count, 114)
        XCTAssertEqual(catalog.surah(for: 3371)?.number, 29)
        XCTAssertTrue((1...604).contains(catalog.page(for: 3371)))
    }
    func testWeeklyVersesAreDeduplicated() throws {
        let day = LocalCalendar.key(.now)
        let session: JSONValue = .object(["start":.number(8), "end":.number(10), "status":.string("done"), "date":.string(day)])
        let state: JSONValue = .object(["sessions":.array([session, session])])
        XCTAssertEqual(HomeProjection(snapshot: HomeSnapshot(state: state)).weeklyVerseCounts.reduce(0, +), 3)
    }
}
@MainActor final class StartupTests: XCTestCase {
    func testCachedInterfaceIsAvailableBeforeNetworkAndSurvivesFailure() async {
        let identity = AccountIdentity(id: UUID(), email: "test@example.invalid")
        let auth = FakeAuth(identity: identity)
        let store = AppStore(auth: auth, remote: FakeRemote(), cache: FakeCache(name: "Local"))
        XCTAssertEqual(store.identity, identity); XCTAssertEqual(store.snapshot.displayName, "Local")
        auth.failRefresh = true
        await store.start()
        XCTAssertEqual(store.identity, identity); XCTAssertEqual(store.snapshot.displayName, "Local"); XCTAssertNotNil(store.message)
    }
    func testEmailConfirmationDoesNotCreateLocalSession() async throws {
        let auth = FakeAuth(identity: nil); auth.confirmEmail = true
        let store = AppStore(auth: auth, remote: FakeRemote(), cache: FakeCache(name: "Local"))
        let connected = try await store.signUp(email: "test@example.invalid", password: "test-password")
        XCTAssertFalse(connected); XCTAssertNil(store.identity)
    }
    func testSignOutClearsVisibleAccount() async throws {
        let auth = FakeAuth(identity: AccountIdentity(id: UUID(), email: nil))
        let store = AppStore(auth: auth, remote: FakeRemote(), cache: FakeCache(name: "A"))
        try await store.signOut(); XCTAssertNil(store.identity); XCTAssertNil(store.snapshot.displayName)
    }
    func testLoginUsesSameUserIDAndCachesRemoteState() async throws {
        let auth = FakeAuth(identity: nil), remote = FakeRemote()
        let store = AppStore(auth: auth, remote: remote, cache: FakeCache(name: "A"))
        try await store.signIn(email: "test@example.invalid", password: "test-password")
        XCTAssertEqual(store.identity?.id, auth.loginID); XCTAssertEqual(store.snapshot.displayName, "Server")
    }
    func testResponseCannotRestoreSignedOutAccount() async throws {
        let auth = FakeAuth(identity: AccountIdentity(id: UUID(), email: nil)), remote = SlowRemote()
        let store = AppStore(auth: auth, remote: remote, cache: FakeCache(name: "A"))
        let refresh = Task { await store.refresh() }
        while remote.continuation == nil { await Task.yield() }
        try await store.signOut()
        remote.continuation?.resume(returning: HomeSnapshot(displayName: "Old account"))
        await refresh.value
        XCTAssertNil(store.identity); XCTAssertNil(store.snapshot.displayName)
    }
}
@MainActor private final class FakeAuth: AuthGateway {
    var cachedIdentity: AccountIdentity?
    let loginID = UUID()
    var failRefresh = false
    var confirmEmail = false
    init(identity: AccountIdentity?) { cachedIdentity = identity }
    func signIn(email: String, password: String) async throws -> AccountIdentity { let id = AccountIdentity(id: loginID, email: email); cachedIdentity = id; return id }
    func signUp(email: String, password: String) async throws -> AccountIdentity? { if confirmEmail { return nil }; return try await signIn(email: email, password: password) }
    func refresh() async throws -> AccountIdentity { if failRefresh { throw URLError(.notConnectedToInternet) }; return cachedIdentity! }
    func signOut() async throws { cachedIdentity = nil }
    func resetPassword(email: String) async throws {}
    func receive(url: URL) async throws -> AccountIdentity { cachedIdentity! }
    func changePassword(_ password: String) async throws {}
}
@MainActor private final class FakeRemote: HomeRemote {
    func fetch(userID: UUID, cached: HomeSnapshot) async throws -> HomeSnapshot { HomeSnapshot(displayName: "Server") }
}
@MainActor private final class SlowRemote: HomeRemote {
    var continuation: CheckedContinuation<HomeSnapshot, Error>?
    func fetch(userID: UUID, cached: HomeSnapshot) async throws -> HomeSnapshot { try await withCheckedThrowingContinuation { continuation = $0 } }
}
private struct FakeCache: HomeCache {
    let name: String
    func load(userID: UUID) throws -> HomeSnapshot? { HomeSnapshot(displayName: name) }
    func save(_ snapshot: HomeSnapshot, userID: UUID) throws {}
}
