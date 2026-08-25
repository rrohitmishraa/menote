import XCTest
import Foundation
@testable import NotchPadCore

final class StorageManagerTests: XCTestCase {
    private var tempDir: URL!
    private var settings: AppSettings!
    private var storageManager: StorageManager!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("NotchPadTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        settings = AppSettings(defaults: UserDefaults(suiteName: "NotchPadTests_\(UUID().uuidString)")!)
        storageManager = StorageManager(settings: settings)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDefaultLocation() {
        let expected = StorageManager.defaultBaseURL()
        XCTAssertEqual(storageManager.baseURL.standardizedFileURL, expected.standardizedFileURL)
    }

    func testEnsureStructureCreatesDirs() throws {
        try storageManager.ensureStructure()
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageManager.layout.imagesDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageManager.layout.attachmentsDirectory.path))
    }

    func testAvailabilityOnValidDir() {
        do {
            try storageManager.ensureStructure()
        } catch {
            XCTFail("ensureStructure threw: \(error)")
        }
        let avail = storageManager.checkAvailability()
        switch avail {
        case .available: break
        case .unavailable: XCTFail("Should be available")
        }
    }

    func testAvailabilityOnNonExistentDir() {
        _ = tempDir.appendingPathComponent("DoesNotExist")
        let avail = storageManager.checkAvailability()
        switch avail {
        case .unavailable: break
        case .available: XCTFail("Should be unavailable")
        }
    }
}