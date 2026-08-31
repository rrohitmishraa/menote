import Foundation

/// Manages reading and writing a single Markdown file as the persistent source of truth.
/// Converts between the editor's content (plain text with optional RTF) and Markdown format.
public final class MarkdownPersistence {
    private let fileManager = FileManager.default
    
    public init() {}
    
    // MARK: - Loading
    
    /// Loads content from a Markdown file at the specified URL.
    /// Returns the text content that should be displayed in the editor.
    public func loadContent(from url: URL) throws -> String {
        // Read the markdown file
        guard fileManager.fileExists(atPath: url.path) else {
            throw MarkdownError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw MarkdownError.invalidEncoding
        }
        
        return content
    }

    /// Loads a Menote document from a readable Markdown file. Rich text is
    /// stored as a Markdown comment only when it still matches the visible
    /// document text, so external Markdown edits always take precedence.
    public func loadNote(from url: URL) throws -> Note? {
        let content = try loadContent(from: url)
        guard !content.isEmpty else { return nil }

        let marker = "\n<!-- menote-rtf:"
        guard let markerRange = content.range(of: marker, options: .backwards),
              let commentEnd = content[markerRange.upperBound...].range(of: " -->") else {
            return Note(blocks: [.text(content)])
        }

        let body = String(content[..<markerRange.lowerBound])
        let payload = String(content[markerRange.upperBound..<commentEnd.lowerBound])
        let parts = payload.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let storedTextData = Data(base64Encoded: parts[0]),
              let storedText = String(data: storedTextData, encoding: .utf8),
              storedText == body,
              let rtf = Data(base64Encoded: parts[1]) else {
            return Note(blocks: body.isEmpty ? [] : [.text(body)])
        }

        return Note(blocks: body.isEmpty ? [] : [.text(body)], richText: rtf)
    }
    
    // MARK: - Saving
    
    /// Saves content to a Markdown file at the specified URL.
    /// Uses atomic writing to prevent corruption.
    public func saveContent(_ content: String, to url: URL) throws {
        guard let data = content.data(using: .utf8) else {
            throw MarkdownError.encodingFailed
        }
        
        // Create backup if file exists
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).bak")
        
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.copyItem(at: url, to: backupURL)
        }
        
        // Write atomically
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw MarkdownError.writeFailed(underlying: error)
        }
    }

    /// Writes visible Markdown text plus optional Menote formatting metadata.
    /// The visible text stays a valid, editable Markdown document.
    public func saveNote(_ note: Note?, draftText: String, to url: URL) throws {
        let text = note?.plainText ?? draftText
        guard let rtf = note?.richText,
              !text.isEmpty,
              let textData = text.data(using: .utf8) else {
            try saveContent(text, to: url)
            return
        }

        let metadata = "<!-- menote-rtf:\(textData.base64EncodedString()).\(rtf.base64EncodedString()) -->"
        try saveContent(text + "\n" + metadata + "\n", to: url)
    }
    
    /// Creates a new Markdown file at the specified location with initial content.
    public func createFile(at url: URL, initialContent: String = "") throws {
        // Ensure parent directory exists
        let parentDir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        // Check if file already exists
        if fileManager.fileExists(atPath: url.path) {
            throw MarkdownError.fileAlreadyExists
        }
        
        // Create the file
        try saveContent(initialContent, to: url)
    }
    
    // MARK: - Verification
    
    /// Verifies that a file at the given URL is readable.
    public func verifyReadable(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        guard fileManager.isReadableFile(atPath: url.path) else { return false }
        
        // Try to read it
        do {
            _ = try loadContent(from: url)
            return true
        } catch {
            return false
        }
    }
    
    /// Verifies that a file at the given URL is writable.
    public func verifyWritable(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            // Check if parent directory is writable
            let parentDir = url.deletingLastPathComponent()
            return fileManager.isWritableFile(atPath: parentDir.path)
        }
        return fileManager.isWritableFile(atPath: url.path)
    }
}

// MARK: - Errors

public enum MarkdownError: LocalizedError {
    case fileNotFound
    case fileAlreadyExists
    case invalidEncoding
    case encodingFailed
    case writeFailed(underlying: Error)
    case readFailed(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Markdown file not found"
        case .fileAlreadyExists:
            return "File already exists at this location"
        case .invalidEncoding:
            return "File is not valid UTF-8 text"
        case .encodingFailed:
            return "Failed to encode content as UTF-8"
        case .writeFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to read file: \(error.localizedDescription)"
        }
    }
}
