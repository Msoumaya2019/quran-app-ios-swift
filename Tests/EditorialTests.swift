import XCTest
@testable import CoranNative

@MainActor private final class EditorialProbe: EditorialRemote {
    var fail = false
    let category: JSONValue = .object(["id": .string("00000000-0000-0000-0000-000000000010"), "type": .string("reminder"), "name": .string("Test"), "display_order": .number(0), "is_active": .bool(true)])
    var rows: [JSONValue] = []
    func load(owner: UUID, kind: EditorialKind, offset: Int) async throws -> EditorialSnapshot { EditorialSnapshot(categories: [category], contents: rows, schedules: []) }
    func save(owner: UUID, draft: EditorialDraft) async throws -> JSONValue { if fail { throw URLError(.notConnectedToInternet) }; return draft.payload }
    func saveCategory(owner: UUID, row: JSONValue) async throws -> JSONValue { if fail { throw URLError(.notConnectedToInternet) }; return row }
    func delete(owner: UUID, id: String, category: Bool) async throws { if fail { throw URLError(.notConnectedToInternet) } }
    func unschedule(owner: UUID, row: JSONValue) async throws { if fail { throw URLError(.notConnectedToInternet) } }
}

final class EditorialTests: XCTestCase {
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
        let remote = EditorialProbe(), library = EditorialLibrary(remote: EditorialProbe())
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
        XCTAssertTrue(library.contents.isEmpty)
    }
    @MainActor func testCategoryRejectsFractionAndIntegerOverflow() {
        let category = EditorialProbe().category
        XCTAssertTrue(EditorialDraft.validCategory(category))
        XCTAssertFalse(EditorialDraft.validCategory(category.setting("display_order", .number(1.5))))
        XCTAssertFalse(EditorialDraft.validCategory(category.setting("display_order", .number(Double(Int32.max) + 1))))
    }
}
