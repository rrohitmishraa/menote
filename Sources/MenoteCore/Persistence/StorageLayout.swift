import Foundation

public struct StorageLayout {
    public let baseURL: URL

    public var notesURL: URL { baseURL.appendingPathComponent("notes.json") }
    public var notesBackupURL: URL { baseURL.appendingPathComponent("notes.json.bak") }
    public var clipboardURL: URL { baseURL.appendingPathComponent("clipboard.json") }
    public var metadataURL: URL { baseURL.appendingPathComponent("metadata.json") }
    public var imagesDirectory: URL { baseURL.appendingPathComponent("images", isDirectory: true) }
    public var attachmentsDirectory: URL { baseURL.appendingPathComponent("attachments", isDirectory: true) }

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public static var requiredRelativePaths: [String] {
        ["images", "attachments"]
    }

    public func createDirectories() throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
    }

    public func isWritable() -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: baseURL.path, isDirectory: &isDir) {
            guard isDir.boolValue else { return false }
        } else {
            return false
        }
        return fm.isWritableFile(atPath: baseURL.path)
    }
}

public struct StoreMetadata: Codable, Equatable {
    public var schemaVersion: Int
    public var lastSavedAt: Date?

    public init(schemaVersion: Int = 1, lastSavedAt: Date? = nil) {
        self.schemaVersion = schemaVersion
        self.lastSavedAt = lastSavedAt
    }
}
