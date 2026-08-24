import XCTest
@testable import NotchPadCore

final class NoteCodableTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    override func setUp() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func testContentBlockTextRoundtrip() throws {
        let block = ContentBlock.text("Hello world")
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testContentBlockHeadingRoundtrip() throws {
        let block = ContentBlock.heading("Title")
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testContentBlockCodeRoundtrip() throws {
        let block = ContentBlock.code("func foo() {}")
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testContentBlockDividerRoundtrip() throws {
        let block = ContentBlock.divider
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testContentBlockChecklistRoundtrip() throws {
        let block = ContentBlock.checklist([
            ChecklistItem(text: "Task 1", isChecked: false),
            ChecklistItem(text: "Task 2", isChecked: true)
        ])
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testContentBlockImageRoundtrip() throws {
        let block = ContentBlock.image(imageID: "ABC123", caption: "A caption")
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testContentBlockLinkRoundtrip() throws {
        let block = ContentBlock.link(url: "https://example.com", title: "Example")
        let data = try encoder.encode(block)
        let decoded = try decoder.decode(ContentBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testNoteRoundtrip() throws {
        var note = Note(
            title: "Test Note",
            blocks: [.text("Line 1"), .code("print('hi')")],
            tags: ["swift", "test"],
            isPinned: true,
            isArchived: false
        )
        let data = try encoder.encode(note)
        let decoded = try decoder.decode(Note.self, from: data)
        XCTAssertEqual(decoded.id, note.id)
        XCTAssertEqual(decoded.title, note.title)
        XCTAssertEqual(decoded.blocks, note.blocks)
        XCTAssertEqual(decoded.tags, note.tags)
        XCTAssertEqual(decoded.isPinned, note.isPinned)
        XCTAssertEqual(decoded.isArchived, note.isArchived)
    }

    func testNotePlainTextGetterSetter() {
        var note = Note(blocks: [.text("Hello"), .heading("Title"), .text("World")])
        XCTAssertEqual(note.plainText, "Hello\nWorld")

        note.plainText = "New content"
        XCTAssertEqual(note.blocks.count, 1)
        if case .text(let s) = note.blocks[0] {
            XCTAssertEqual(s, "New content")
        } else {
            XCTFail("Expected text block")
        }
    }

    func testNoteDisplayTitle() {
        let note1 = Note(title: "  My Title  ")
        XCTAssertEqual(note1.displayTitle, "My Title")

        let note2 = Note(blocks: [.text("First line of content\nSecond line")])
        XCTAssertEqual(note2.displayTitle, "First line of content")

        let note3 = Note()
        XCTAssertEqual(note3.displayTitle, "Untitled")
    }

    func testNoteSearchText() {
        let note = Note(
            title: "Title",
            blocks: [.text("body content"), .checklist([ChecklistItem(text: "task")])],
            tags: ["tag1", "tag2"]
        )
        let search = note.searchText
        XCTAssertTrue(search.contains("title"))
        XCTAssertTrue(search.contains("body"))
        XCTAssertTrue(search.contains("task"))
        XCTAssertTrue(search.contains("tag1"))
    }
}