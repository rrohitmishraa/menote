import Foundation
import ServiceManagement

public enum LaunchAtLoginManager {
    public static var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return Bundle.main.bundleURL.pathExtension == "app"
        }
        return false
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *), isSupported else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    public static func isEnabled() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }
}
