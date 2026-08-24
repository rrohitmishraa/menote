import Foundation

public final class ImageStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for id: String) -> URL {
        let fm = FileManager.default
        if let ext = knownExtensions.first(where: { fm.fileExists(atPath: directory.appendingPathComponent("\(id).\($0)").path) }) {
            return directory.appendingPathComponent("\(id).\(ext)")
        }
        return directory.appendingPathComponent("\(id).png")
    }

    public func save(data: Data, fileExtension: String) throws -> String {
        let id = UUID().uuidString.prefix(8).uppercased()
        let safeExt = knownExtensions.contains(fileExtension.lowercased()) ? fileExtension.lowercased() : "png"
        let url = directory.appendingPathComponent("\(id).\(safeExt)")
        try data.write(to: url, options: .atomic)
        return String(id)
    }

    public func delete(id: String) {
        let fm = FileManager.default
        for ext in knownExtensions {
            let url = directory.appendingPathComponent("\(id).\(ext)")
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
    }

    public func exists(id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    private let knownExtensions = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp"]
}
