import XCTest
@testable import CoranNative

final class ChatTests: XCTestCase {
    func testGroupMessagesAndDirectMessagesUseSeparateRoomsAndCaches() throws {
        let owner = UUID(), room = UUID()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var group = ChatSnapshot(owner: owner, linkID: room, groupRoom: true)
        let pending = try group.enqueue("Message du groupe")
        XCTAssertNil(pending.linkID); XCTAssertEqual(pending.groupID, room)
        var direct = ChatSnapshot(owner: owner, linkID: room)
        let personal = try direct.enqueue("Message privé")
        group.merge([personal]); XCTAssertEqual(group.pending.count, 1); XCTAssertEqual(group.visible.count, 1)
        direct.merge([pending]); XCTAssertEqual(direct.visible.first?.body, "Message privé")
        let cache = ChatCache(directory: directory); try cache.save(group); try cache.save(direct)
        XCTAssertEqual(try cache.load(owner: owner, link: room, group: true)?.pending, [pending])
        XCTAssertEqual(try cache.load(owner: owner, link: room)?.pending, [personal])
        XCTAssertEqual(try JSONDecoder().decode(ChatSnapshot.self, from: JSONEncoder().encode(direct)).groupRoom, nil)
    }
    let owner = UUID(), link = UUID()
    func testQueueKeepsStableIdentityAndRejectsInvalidBodies() throws {
        var snapshot = ChatSnapshot(owner: owner, linkID: link)
        let id = UUID(), row = try snapshot.enqueue("  Bonjour  ", id: id)
        XCTAssertEqual(row.body, "Bonjour"); XCTAssertEqual(snapshot.visible.first?.id, id)
        XCTAssertThrowsError(try snapshot.enqueue("Bonjour", id: id))
        XCTAssertThrowsError(try snapshot.enqueue(" \n "))
        XCTAssertThrowsError(try snapshot.enqueue(String(repeating: "a", count: 2001)))
        XCTAssertThrowsError(try snapshot.enqueue(String(repeating: "👨‍👩‍👧‍👦", count: 400)))
        XCTAssertEqual(try JSONDecoder().decode(ChatSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }
    func testForeignRowsCannotConfirmPendingAndDeletedRowsStayDeleted() throws {
        var snapshot = ChatSnapshot(owner: owner, linkID: link)
        let pending = try snapshot.enqueue("Bonjour")
        let foreign = ChatMessage(id: pending.id, linkID: UUID(), groupID: nil, senderID: owner, kind: "text", body: pending.body, createdAt: pending.createdAt, deletedAt: nil, recitationID: nil)
        snapshot.merge([foreign]); XCTAssertEqual(snapshot.pending.count, 1)
        snapshot.merge([pending]); XCTAssertTrue(snapshot.pending.isEmpty); XCTAssertEqual(snapshot.visible.count, 1)
        let deleted = ChatMessage(id: pending.id, linkID: link, groupID: nil, senderID: owner, kind: "text", body: pending.body, createdAt: pending.createdAt, deletedAt: pending.createdAt, recitationID: nil)
        snapshot.merge([deleted]); snapshot.merge([pending])
        XCTAssertEqual(snapshot.visible[0].displayBody, "Message supprimé")
        snapshot.merge([], hiddenIDs: [pending.id]); XCTAssertTrue(snapshot.visible.isEmpty)
    }
    func testCacheIsSeparatedByOwnerAndConversation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ChatCache(directory: directory)
        var snapshot = ChatSnapshot(owner: owner, linkID: link); _ = try snapshot.enqueue("À envoyer")
        try cache.save(snapshot)
        XCTAssertEqual(try cache.load(owner: owner, link: link)?.pending.first?.id, snapshot.pending.first?.id)
        XCTAssertNil(try cache.load(owner: UUID(), link: link)); XCTAssertNil(try cache.load(owner: owner, link: UUID()))
    }
    @MainActor func testConfirmedServerInsertIsNotDuplicatedAfterInterruptedResponse() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ChatCache(directory: directory), remote = FakeChatRemote()
        let first = ConversationLibrary(owner: owner, link: link, remote: remote, cache: cache)
        XCTAssertTrue(first.enqueue("Bonjour")); let id = first.snapshot.pending[0].id
        remote.failAfterInsert = true
        await first.refresh(); XCTAssertEqual(first.snapshot.pending.first?.id, id)
        let reopened = ConversationLibrary(owner: owner, link: link, remote: remote, cache: cache)
        XCTAssertEqual(reopened.snapshot.pending.first?.id, id)
        await reopened.refresh()
        XCTAssertTrue(reopened.snapshot.pending.isEmpty); XCTAssertEqual(reopened.snapshot.visible.map(\.id), [id]); XCTAssertEqual(remote.insertions, 1)
        await reopened.refresh(); XCTAssertEqual(remote.insertions, 1)
    }
}
@MainActor private final class FakeChatRemote: ChatRemote {
    var rows: [UUID: ChatMessage] = [:]
    var insertions = 0
    var failAfterInsert = false
    func load(owner: UUID, link: UUID, before: ChatMessage?) async throws -> ChatPage { ChatPage(messages: Array(rows.values), hidden: []) }
    func send(owner: UUID, message: ChatMessage) async throws -> ChatMessage {
        if let existing = rows[message.id] { return existing }
        rows[message.id] = message; insertions += 1
        if failAfterInsert { failAfterInsert = false; throw URLError(.networkConnectionLost) }
        return message
    }
    func markRead(owner: UUID, link: UUID, through: String) async throws {}
}
