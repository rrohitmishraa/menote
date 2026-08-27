import Foundation

public final class Logger {
    public static let shared = Logger()
    private let logURL: URL
    
    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.logURL = supportDir.appendingPathComponent("Menote_termination.log")
        let logDirPath = logURL.deletingLastPathComponent().path
        if !FileManager.default.fileExists(atPath: logDirPath) {
            try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public func log(_ string: String) {
        let formatted = "\(Date().formatted(.iso8601)) \(string)\n"
        if let data = formatted.data(using: .utf8) {
            try? data.write(to: logURL, options: .atomic)
        }
    }
    
    public func logCallStack() {
        let stack = Thread.callStackSymbols.joined(separator: "\n")
        log("CALL_STACK:\n\(stack)")
    }
}