import XCTest
import Foundation
@testable import NotchPadCore

final class PersistenceTests: XCTestCase {
    private var tempDir: URL!
    private var layout: StorageLayout!
    private var persistence: JSONPersistence!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("NotchPadTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        layout = StorageLayout(baseURL: tempDir)
        persistence = JSONPersistence(layout: layout)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testEmptyLoadReturnsEmptyArray() throws {
        let (notes, hadError) = try persistence.loadNotes()
        XCTAssertTrue(notes.isEmpty)
        XCTAssertFalse(hadError)
    }

    func testSaveAndLoadRoundtrip() throws {
        let notes = [
            Note(title: "A", blocks: [.text("content 1")]),
            Note(title: "B", blocks: [.text("content 2")], isPinned: true)
        ]
        try persistence.saveNotes(notes)

        let (loaded, hadError) = try persistence.loadNotes()
        XCTAssertFalse(hadError)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, notes[1].id) // pinned first
        XCTAssertEqual(loaded[1].id, notes[0].id)
    }

    func testCorruptPrimaryFallsBackToBackup() throws {
        let notes = [Note(title: "Good", blocks: [.text("ok")])]
        try persistence.saveNotes(notes)

        // Corrupt primary
        let badData = Data("not json".utf8)
        try badData.write(to: layout.notesURL, options: .atomic)

        // Backup should exist and be used
        let (loaded, hadError) = try persistence.loadNotes()
        XCTAssertFalse(hadError)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Good")
    }

    func testCorruptBothReturnsEmptyAndError() throws {
        let notes = [Note(title: "Good", blocks: [.text("ok")])]
        try persistence.saveNotes(notes)

        // Corrupt both
        let badData = Data("not json".utf8)
        try badData.write(to: layout.notesURL, options: .atomic)
        try badData.write(to: layout.notesBackupURL, options: .atomic)

        let (loaded, hadError) = try persistence.loadNotes()
        XCTAssertTrue(hadError)
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveCreatesBackup() throws {
        let notes1 = [Note(title: "First", blocks: [.text("v1")])]
        try persistence.saveNotes(notes1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.notesBackupURL.path))

        // Second save should update backup to previous version
        let notes2 = [Note(title: "Second", blocks: [.text("v2")])]
        try persistence.saveNotes(notes2)

        // Backup should now contain v1
        let backupData = try Data(contentsOf: layout.notesBackupURL)
        let backupNotes = try JSONPersistence.isoDecoder.decode([Note].self, from: backupData)
        XCTAssertEqual(backupNotes[0].title, "First")
    }

    func testMetadataSaveAndLoad() {
        let meta = StoreMetadata(schemaVersion: 1, lastSavedAt: Date())
        persistence.saveMetadata(meta)
        let loaded = persistence.loadMetadata()
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertNotNil(loaded.lastSavedAt)
    }
}