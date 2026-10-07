import XCTest
@testable import CoranNative

@MainActor private final class EditorialProbe: EditorialRemote {
    var fail = false
    let category: JSONValue = .object(["id": .string("00000000-0000-0000-0000-000000000010"), "type": .string("reminder"), "name": .string("Test"), "display_order": .number(0), "is_active": .bool(true)])
    var rows: [JSONValue] = []
    var holdSave = false
    var waiting: CheckedContinuation<Void, Never>?
    func load(owner: UUID, kind: EditorialKind, offset: Int) async throws -> EditorialSnapshot { EditorialSnapshot(categories: [category], contents: Array(rows.dropFirst(offset).prefix(30)), schedules: []) }
    func save(owner: UUID, draft: EditorialDraft) async throws -> JSONValue { if holdSave { await withCheckedContinuation { waiting = $0 } }; if fail { throw URLError(.notConnectedToInternet) }; return draft.payload }
    func saveCategory(owner: UUID, row: JSONValue) async throws -> JSONValue { if fail { throw URLError(.notConnectedToInternet) }; return row }
    func delete(owner: UUID, id: String, category: Bool) async throws { if fail { throw URLError(.notConnectedToInternet) }; rows.removeAll { $0["id"].string == id } }
    func unschedule(owner: UUID, row: JSONValue) async throws { if fail { throw URLError(.notConnectedToInternet) } }
}

final class EditorialTests: XCTestCase {
    @MainActor func testDeletionBetweenPagesDoesNotSkipNextContent() async {
        let remote = EditorialProbe()
        remote.rows = (0..<35).map { _ in .object(["id": .string(UUID().uuidString), "type": .string("reminder")]) }
        let expected = Set(remote.rows.dropFirst().compactMap { $0["id"].string })
        let library = EditorialLibrary(remote: remote); library.select(UUID()); await library.load(.reminder)
        XCTAssertEqual(library.contents.count, 30)
        await library.delete(library.contents[0]); await library.load(.reminder, more: true)
        XCTAssertEqual(Set(library.contents.compactMap { $0["id"].string }), expected)
        XCTAssertFalse(library.hasMore)
    }
    func testCalendarAndMediaValidation() {
        XCTAssertTrue(EditorialDraft.validDate("2028-02-29"))
        XCTAssertFalse(EditorialDraft.validDate("2026-02-29"))
        XCTAssertFalse(EditorialDraft.validDate("2026-13-01"))
        XCTAssertFalse(EditorialDraft.validMedia("http://example.org/image.png"))
        XCTAssertFalse(EditorialDraft.validMedia("https://user:password@example.org/image.png"))
        XCTAssertTrue(EditorialDraft.validMedia("https://example.org/image.png"))
    }
    @MainActor func testDraftPreservesOnlyBackendContractAndRejectsWrongCategory() {
        let remote = EditorialProbe()
        var draft = EditorialDraft(kind: .reminder, categories: [remote.category])
        draft.value = draft.value.setting("french_text", .string(" Texte ")).setting("source", .string(" Source ")).setting("created_by", .string("another-account"))
        XCTAssertNil(draft.validation(categories: [remote.category]))
        XCTAssertEqual(draft.payload["french_text"].string, "Texte")
        XCTAssertEqual(draft.payload["created_by"], .null)
        draft.value = draft.value.setting("type", .string("invocation"))
        XCTAssertNotNil(draft.validation(categories: [remote.category]))
        let category = remote.category.setting("type", .string("invocation"))
        XCTAssertNotNil(draft.validation(categories: [category]))
        draft.value = draft.value.setting("arabic_text", .string("Texte de test")).setting("phonetic_text", .string("Test"))
        XCTAssertNil(draft.validation(categories: [category]))
    }
    @MainActor func testFailedMutationDoesNotChangeContentOrScheduleAndRetryIsStable() async {
        let remote = EditorialProbe()
        let subject = EditorialLibrary(remote: remote)
        subject.select(UUID()); await subject.load(.reminder)
        var draft = EditorialDraft(kind: .reminder, categories: [remote.category])
        draft.value = draft.value.setting("french_text", .string("Test")).setting("source", .string("Test")); draft.date = "2026-10-08"
        remote.fail = true
        let failed = await subject.save(draft); XCTAssertFalse(failed); XCTAssertTrue(subject.contents.isEmpty); XCTAssertTrue(subject.schedules.isEmpty)
        remote.fail = false
        let saved = await subject.save(draft); XCTAssertTrue(saved)
        let retried = await subject.save(draft); XCTAssertTrue(retried)
        XCTAssertEqual(subject.contents.count, 1); XCTAssertEqual(subject.schedules.count, 1)
        remote.fail = true
        await subject.delete(subject.contents[0]); XCTAssertEqual(subject.contents.count, 1)
        await subject.unschedule(subject.schedules[0]); XCTAssertEqual(subject.schedules.count, 1)
        subject.select(UUID()); XCTAssertTrue(subject.contents.isEmpty); XCTAssertTrue(subject.categories.isEmpty)
    }
    @MainActor func testCategoryRejectsFractionAndIntegerOverflow() {
        let category = EditorialProbe().category
        XCTAssertTrue(EditorialDraft.validCategory(category))
        XCTAssertFalse(EditorialDraft.validCategory(category.setting("display_order", .number(1.5))))
        XCTAssertFalse(EditorialDraft.validCategory(category.setting("display_order", .number(Double(Int32.max) + 1))))
    }
    @MainActor func testAccountChangeDiscardsLateServerConfirmation() async {
        let remote = EditorialProbe()
        let library = EditorialLibrary(remote: remote); library.select(UUID()); await library.load(.reminder)
        var draft = EditorialDraft(kind: .reminder, categories: [remote.category])
        draft.value = draft.value.setting("french_text", .string("Test")).setting("source", .string("Test"))
        remote.holdSave = true
        let save = Task { await library.save(draft) }
        while remote.waiting == nil { await Task.yield() }
        library.select(UUID()); remote.waiting?.resume(); remote.waiting = nil
        let result = await save.value
        XCTAssertFalse(result); XCTAssertTrue(library.contents.isEmpty); XCTAssertTrue(library.categories.isEmpty); XCTAssertFalse(library.busy)
    }
    @MainActor func testSchedulingReplacesOnlySameDateAndEmptyDatePreservesSchedules() async {
        let remote = EditorialProbe()
        let subject = EditorialLibrary(remote: remote); subject.select(UUID()); await subject.load(.reminder)
        var first = EditorialDraft(kind: .reminder, categories: [remote.category])
        first.value = first.value.setting("french_text", .string("Test")).setting("source", .string("Test")); first.date = "2026-10-08"
        let savedFirst = await subject.save(first); XCTAssertTrue(savedFirst)
        var second = first; second.value = first.value.setting("id", .string(UUID().uuidString)); second.date = "2026-10-09"
        let savedSecond = await subject.save(second); XCTAssertTrue(savedSecond); XCTAssertEqual(subject.schedules.count, 2)
        second.date = "2026-10-08"; let replaced = await subject.save(second); XCTAssertTrue(replaced)
        XCTAssertEqual(subject.schedules.count, 2); XCTAssertTrue(subject.schedules.allSatisfy { $0["content_id"] == second.value["id"] })
        second.date = ""; second.value = second.value.setting("is_active", .bool(false))
        let deactivated = await subject.save(second); XCTAssertTrue(deactivated); XCTAssertEqual(subject.schedules.count, 2)
        await subject.unschedule(subject.schedules[0]); XCTAssertEqual(subject.schedules.count, 1)
    }
}
