import XCTest
import Foundation
@testable import NotchPadCore

final class NoteStoreTests: XCTestCase {
    private var tempDir: URL!
    private var layout: StorageLayout!
    private var persistence: JSONPersistence!
    private var storageManager: StorageManager!
    private var settings: AppSettings!
    private var store: NoteStore!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("NotchPadTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        layout = StorageLayout(baseURL: tempDir)
        persistence = JSONPersistence(layout: layout)

        settings = AppSettings(defaults: UserDefaults(suiteName: "NotchPadTests_\(UUID().uuidString)")!)
        storageManager = StorageManager(settings: settings)
        storageManager.checkAvailability() // create dirs

        store = NoteStore(persistence: persistence, storageManager: storageManager)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadEmpty() {
        store.loadFromDisk()
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertNil(store.currentNoteID)
    }

    func testCreateNoteSelectsIt() {
        store.loadFromDisk()
        let note = store.createNote(text: "Hello world", selectIt: true)
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.currentNoteID, note.id)
        XCTAssertEqual(store.currentNote?.plainText, "Hello world")
        XCTAssertTrue(note.title.hasPrefix("Hello"))
    }

    func testCreateEmptyNoteDoesNotSelect() {
        store.loadFromDisk()
        let note = store.createNote(text: "", selectIt: true)
        XCTAssertEqual(store.currentNoteID, note.id)
    }

    func testUpdateTextLazilyCreatesNote() {
        store.loadFromDisk()
        store.beginDraft()
        store.updateCurrentText("First line")
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.currentNote?.plainText, "First line")
    }

    func testBeginDraftClearsSelection() {
        store.loadFromDisk()
        let note = store.createNote(text: "content")
        store.beginDraft()
        XCTAssertNil(store.currentNoteID)
        XCTAssertEqual(store.draftText, "")
    }

    func testUpdateExistingNote() {
        store.loadFromDisk()
        let note = store.createNote(text: "original")
        store.updateNote(note.id) { $0.plainText = "updated" }
        XCTAssertEqual(store.note(withID: note.id)?.plainText, "updated")
    }

    func testTogglePin() {
        store.loadFromDisk()
        let n1 = store.createNote(text: "a")
        let n2 = store.createNote(text: "b")
        store.togglePin(n2.id)
        XCTAssertTrue(store.note(withID: n2.id)?.isPinned ?? false)
        XCTAssertFalse(store.note(withID: n1.id)?.isPinned ?? false)
        // Pinned should be first
        XCTAssertEqual(store.activeNotes.first?.id, n2.id)
    }

    func testToggleArchive() {
        store.loadFromDisk()
        let note = store.createNote(text: "test")
        store.toggleArchive(note.id)
        XCTAssertTrue(store.note(withID: note.id)?.isArchived ?? false)
        XCTAssertTrue(store.activeNotes.isEmpty)
        XCTAssertEqual(store.archivedNotes.count, 1)
    }

    func testDeleteNote() {
        store.loadFromDisk()
        let n1 = store.createNote(text: "a")
        let n2 = store.createNote(text: "b")
        store.deleteNote(n1.id)
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes[0].id, n2.id)
    }

    func testDeleteCurrentNoteClearsSelection() {
        store.loadFromDisk()
        let note = store.createNote(text: "only")
        store.deleteNote(note.id)
        XCTAssertNil(store.currentNoteID)
    }

    func testSearch() {
        store.loadFromDisk()
        store.createNote(text: "apple banana")
        store.createNote(text: "cherry date")
        store.createNote(text: "apple pie")

        let results = store.search("apple")
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.plainText.contains("apple") })
    }

    func testSearchEmptyReturnsAll() {
        store.loadFromDisk()
        store.createNote(text: "a")
        store.createNote(text: "b")
        let results = store.search("")
        XCTAssertEqual(results.count, 2)
    }

    func testSearchIncludeArchived() {
        store.loadFromDisk()
        let n = store.createNote(text: "secret")
        store.toggleArchive(n.id)
        let active = store.search("secret", includeArchived: false)
        let all = store.search("secret", includeArchived: true)
        XCTAssertTrue(active.isEmpty)
        XCTAssertEqual(all.count, 1)
    }

    func testSearchCaseInsensitive() {
        store.loadFromDisk()
        store.createNote(text: "Apple")
        let results = store.search("apple")
        XCTAssertEqual(results.count, 1)
    }
}