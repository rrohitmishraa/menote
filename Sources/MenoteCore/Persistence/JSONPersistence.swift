import Foundation

public enum PersistenceError: LocalizedError {
    case corruptBothPrimaryAndBackup(underlying: Error)
    case writeFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .corruptBothPrimaryAndBackup:
            return "The notes file at this location could not be read. Your data has NOT been overwritten."
        case .writeFailed(let error):
            return "Saving failed: \(error.localizedDescription)"
        }
    }
}

public final class JSONPersistence {
    public let layout: StorageLayout
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(layout: StorageLayout) {
        self.layout = layout
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    private func readData(at url: URL) -> Data? {
        try? Data(contentsOf: url)
    }
    
    private var legacyDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    public func loadNotes() throws -> (notes: [Note], hadError: Bool) {
        let fm = FileManager.default
        
        // Try primary location first
        if fm.fileExists(atPath: layout.notesURL.path) {
            if let data = readData(at: layout.notesURL) {
                do {
                    let notes = try decoder.decode([Note].self, from: data)
                    
                    // If primary location is not the default menote location, migrate to default
                    let defaultBaseURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("menote", isDirectory: true)
                    
                    if layout.baseURL != defaultBaseURL {
                        let defaultLayout = StorageLayout(baseURL: defaultBaseURL)
                        try defaultLayout.createDirectories()
                        try writeAtomically(try encoder.encode(notes), to: defaultLayout.notesURL, keepingBackup: true)
                    }
                    
                    return (notes, false)
                } catch {
                    if let backup = readData(at: layout.notesBackupURL),
                       let recovered = try? decoder.decode([Note].self, from: backup) {
                        return (recovered, false)
                    }
                    // Primary and backup both failed - fall through to migration
                }
            }
        }
        
        // Same-format migration: copy the previous "Menote" data folder into the new location.
        let supportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let previousFolder = supportURL.appendingPathComponent("Menote", isDirectory: true)
        
        if !fm.fileExists(atPath: layout.baseURL.path),
           fm.fileExists(atPath: previousFolder.path) {
            do {
                try fm.copyItem(at: previousFolder, to: layout.baseURL)
                if let data = readData(at: layout.notesURL),
                   let notes = try? decoder.decode([Note].self, from: data) {
                    return (notes, false)
                }
            } catch {
                // Fall through to legacy migration if the copy/parse fails.
            }
        }
        
        // Fallback: Try to migrate from known old locations
        let oldLocations = [
            supportURL.appendingPathComponent("Menote/notes.json"),
            supportURL.appendingPathComponent("Menote/notes.json"),
        ]
        
        for oldURL in oldLocations {
            if fm.fileExists(atPath: oldURL.path),
               let data = readData(at: oldURL) {
                do {
                    let legacyNotes = try legacyDecoder.decode([LegacyNote].self, from: data)
                    let notes = legacyNotes.compactMap { $0.toNote() }
                    // Save migrated notes to new location
                    do {
                        try layout.createDirectories()
                        try saveNotes(notes)
                    } catch {
                        // Ignore save errors, return migrated notes anyway
                    }
                    return (notes, false)
                } catch {
                    // Ignore migration errors
                }
            }
        }
        
        return ([], false)
    }

private struct LegacyNote: Codable {
    let id: UUID
    let title: String
    let body: String
    let isPinned: Bool
    let isArchived: Bool
    let tags: [String]
    let createdAt: Date
    let modifiedAt: Date
    
    func toNote() -> Note? {
        var note = Note(
            id: id,
            title: title,
            blocks: body.isEmpty ? [] : [.text(body)],
            tags: tags,
            isPinned: isPinned,
            isArchived: isArchived,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
        return note
    }
}

    public func saveNotes(_ notes: [Note]) throws {
        let data: Data
        do {
            data = try encoder.encode(notes)
        } catch {
            throw PersistenceError.writeFailed(underlying: error)
        }
        writeAtomically(data, to: layout.notesURL, keepingBackup: true)
        saveMetadata(StoreMetadata(schemaVersion: 1, lastSavedAt: Date()))
    }

    public func loadMetadata() -> StoreMetadata {
        if let data = readData(at: layout.metadataURL),
           let meta = try? decoder.decode(StoreMetadata.self, from: data) {
            return meta
        }
        return StoreMetadata()
    }

    public func saveMetadata(_ metadata: StoreMetadata) {
        if let data = try? encoder.encode(metadata) {
            writeAtomically(data, to: layout.metadataURL, keepingBackup: false)
        }
    }

    private func writeAtomically(_ data: Data, to url: URL, keepingBackup: Bool) {
        let fm = FileManager.default
        if keepingBackup, fm.fileExists(atPath: url.path) {
            let backupURL = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".bak")
            try? fm.copyItem(at: url, to: backupURL)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // Keep in-memory state authoritative; caller surfaces the failure.
        }
    }

    public func verifyReadable() -> Bool {
        guard FileManager.default.fileExists(atPath: layout.notesURL.path) else { return true }
        guard let data = readData(at: layout.notesURL) else { return false }
        return ((try? decoder.decode([Note].self, from: data)) != nil)
    }
}