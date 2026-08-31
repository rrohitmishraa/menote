import Foundation

/// Manages the user-selected Markdown file location and security-scoped bookmarks.
/// Ensures the app can access the file across launches, even in sandboxed environments.
public final class FileLocationManager {
    private let userDefaults: UserDefaults
    private let fileManager = FileManager.default
    
    // UserDefaults keys
    private let bookmarkKey = "menote.markdownFileBookmark"
    private let filePathKey = "menote.markdownFilePath"
    private let firstLaunchCompletedKey = "menote.firstLaunchCompleted"
    
    private var currentSecurityScopedURL: URL?
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - First Launch
    
    /// Returns true if the first-launch setup has been completed.
    public var hasCompletedFirstLaunch: Bool {
        userDefaults.bool(forKey: firstLaunchCompletedKey)
    }
    
    /// Marks first-launch setup as completed.
    public func markFirstLaunchCompleted() {
        userDefaults.set(true, forKey: firstLaunchCompletedKey)
    }
    
    // MARK: - File Selection
    
    /// Saves the selected file location with a security-scoped bookmark.
    public func saveFileLocation(_ url: URL) throws {
        // Stop accessing previous URL if any
        stopAccessingSecurityScopedResource()
        
        // Create bookmark for the new URL
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            userDefaults.set(bookmarkData, forKey: bookmarkKey)
            userDefaults.set(url.path, forKey: filePathKey)
            
            // Start accessing the new URL
            if url.startAccessingSecurityScopedResource() {
                currentSecurityScopedURL = url
            }
            
        } catch {
            throw FileLocationError.bookmarkCreationFailed(underlying: error)
        }
    }
    
    /// Retrieves the saved file location, restoring from bookmark if necessary.
    public func getSavedFileLocation() throws -> URL? {
        // Try to get bookmark data
        guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
            // Non-sandboxed installs can retain access through the persisted path.
            guard let path = userDefaults.string(forKey: filePathKey) else { return nil }
            return URL(fileURLWithPath: path)
        }
        
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // If bookmark is stale, try to recreate it
            if isStale {
                try saveFileLocation(url)
            }
            
            // Start accessing the security-scoped resource
            if url.startAccessingSecurityScopedResource() {
                currentSecurityScopedURL = url
            }
            
            return url
            
        } catch {
            // Bookmark resolution failed - try fallback to stored path
            if let path = userDefaults.string(forKey: filePathKey) {
                let url = URL(fileURLWithPath: path)
                if fileManager.fileExists(atPath: url.path) {
                    return url
                }
            }
            throw FileLocationError.bookmarkResolutionFailed(underlying: error)
        }
    }
    
    /// Clears the saved file location.
    public func clearFileLocation() {
        stopAccessingSecurityScopedResource()
        userDefaults.removeObject(forKey: bookmarkKey)
        userDefaults.removeObject(forKey: filePathKey)
    }
    
    // MARK: - Security Scoped Access
    
    private func stopAccessingSecurityScopedResource() {
        currentSecurityScopedURL?.stopAccessingSecurityScopedResource()
        currentSecurityScopedURL = nil
    }
    
    deinit {
        stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Utilities
    
    /// Verifies that the saved file location is still accessible.
    public func verifySavedFileAccessible() -> Bool {
        guard let url = try? getSavedFileLocation() else { return false }
        return fileManager.fileExists(atPath: url.path) && 
               fileManager.isReadableFile(atPath: url.path)
    }
}

// MARK: - Errors

public enum FileLocationError: LocalizedError {
    case bookmarkCreationFailed(underlying: Error)
    case bookmarkResolutionFailed(underlying: Error)
    case fileNotAccessible
    
    public var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed(let error):
            return "Failed to save file location: \(error.localizedDescription)"
        case .bookmarkResolutionFailed(let error):
            return "Failed to restore file location: \(error.localizedDescription)"
        case .fileNotAccessible:
            return "The selected file is no longer accessible"
        }
    }
}
