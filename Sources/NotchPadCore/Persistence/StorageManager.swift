import Foundation

public enum StorageAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

public final class StorageManager {
    public static let storageDidChange = Notification.Name(kStorageDidChange as String)
    public static let availabilityDidChange = Notification.Name(kAvailabilityDidChange as String)

    private let settings: AppSettings
    private let fm = FileManager.default

    public private(set) var lastCheckReason: String?
    private var lastAvailability: StorageAvailability = .available

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var baseURL: URL {
        return StorageManager.defaultBaseURL()
    }

    public static func defaultBaseURL() -> URL {
        let support = fm_urlsForDirectory(.applicationSupportDirectory).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("menote", isDirectory: true)
    }

    private static func fm_urlsForDirectory(_ dir: FileManager.SearchPathDirectory) -> [URL] {
        FileManager.default.urls(for: dir, in: .userDomainMask)
    }

    public var layout: StorageLayout {
        StorageLayout(baseURL: baseURL)
    }

    public func ensureStructure() throws {
        try layout.createDirectories()
    }

    @discardableResult
    public func checkAvailability() -> StorageAvailability {
        let url = baseURL
        var newAvailability: StorageAvailability = .available
        var isDir: ObjCBool = false
        
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                let reason = "\(url.path) is not a folder."
                lastCheckReason = reason
                newAvailability = .unavailable(reason: reason)
            } else {
                do {
                    try ensureStructure()
                    guard layout.isWritable() else {
                        let reason = "\(url.path) is not writable."
                        lastCheckReason = reason
                        newAvailability = .unavailable(reason: reason)
                        if newAvailability != lastAvailability {
                            lastAvailability = newAvailability
                            postAvailabilityChange()
                        }
                        return newAvailability
                    }
                    lastCheckReason = nil
                    newAvailability = .available
                } catch {
                    let reason = "Cannot create menote folders at \(url.path): \(error.localizedDescription)"
                    lastCheckReason = reason
                    newAvailability = .unavailable(reason: reason)
                }
            }
        } else {
            // Default location doesn't exist yet — that's fine, we'll create it
            do {
                try ensureStructure()
                guard layout.isWritable() else {
                    let reason = "\(url.path) is not writable."
                    lastCheckReason = reason
                    newAvailability = .unavailable(reason: reason)
                    if newAvailability != lastAvailability {
                        lastAvailability = newAvailability
                        postAvailabilityChange()
                    }
                    return newAvailability
                }
                lastCheckReason = nil
                newAvailability = .available
            } catch {
                let reason = "Cannot create menote folders at \(url.path): \(error.localizedDescription)"
                lastCheckReason = reason
                newAvailability = .unavailable(reason: reason)
            }
        }
        
        if newAvailability != lastAvailability {
            lastAvailability = newAvailability
            postAvailabilityChange()
        }
        return newAvailability
    }

    private func postAvailabilityChange() {
        NotificationCenter.default.post(name: StorageManager.availabilityDidChange, object: self)
    }

    /// Migrates data to `destination`. The original location is never deleted.
    private func copyDirectoryContents(from source: URL, to destination: URL) throws {
        guard fm.fileExists(atPath: source.path) else { return }
        let items = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in items {
            let dest = destination.appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
            try fm.copyItem(at: item, to: dest)
        }
    }
}

extension JSONPersistence {
    static let isoDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private let kStorageDidChange = "NotchPadStorageDidChange" as NSString
private let kAvailabilityDidChange = "NotchPadStorageAvailabilityDidChange" as NSString
private let kErrorDomain = "NotchPadStorage" as NSString
