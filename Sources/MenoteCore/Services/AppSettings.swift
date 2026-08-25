import Foundation

public enum AccessPoint: String {
    case menuBar
}

public enum AppearanceMode: String {
    case system
    case light
    case dark
}

public final class AppSettings {
    public static let shared = AppSettings()
    public static let didChange = Notification.Name(kSettingsDidChange as String)

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            kAccessPoint as String: AccessPoint.menuBar.rawValue,
            kAppearance as String: AppearanceMode.system.rawValue,
            kClipboardHistoryEnabled as String: true,
            kClipboardLimit as String: 50,
            kLaunchAtLogin as String: false,
        ])
    }

    private func postChange() {
        NotificationCenter.default.post(name: AppSettings.didChange, object: self)
    }

    public var accessPoint: AccessPoint {
        get { AccessPoint(rawValue: defaults.string(forKey: kAccessPoint as String) ?? "") ?? .menuBar }
        set {
            defaults.set(newValue.rawValue, forKey: kAccessPoint as String)
            postChange()
        }
    }

    public var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: defaults.string(forKey: kAppearance as String) ?? "") ?? .system }
        set {
            defaults.set(newValue.rawValue, forKey: kAppearance as String)
            postChange()
        }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: kLaunchAtLogin as String) }
        set {
            defaults.set(newValue, forKey: kLaunchAtLogin as String)
            postChange()
        }
    }

    public var clipboardHistoryEnabled: Bool {
        get { defaults.bool(forKey: kClipboardHistoryEnabled as String) }
        set {
            defaults.set(newValue, forKey: kClipboardHistoryEnabled as String)
            postChange()
        }
    }

    public var clipboardLimit: Int {
        get { max(1, min(500, defaults.integer(forKey: kClipboardLimit as String))) }
        set {
            defaults.set(max(1, min(500, newValue)), forKey: kClipboardLimit as String)
            postChange()
        }
    }
}

private let kAccessPoint = "Menote.accessPoint" as NSString
private let kAppearance = "Menote.appearance" as NSString
private let kLaunchAtLogin = "Menote.launchAtLogin" as NSString
private let kClipboardHistoryEnabled = "Menote.clipboardHistoryEnabled" as NSString
private let kClipboardLimit = "Menote.clipboardLimit" as NSString
private let kSettingsDidChange = "MenoteSettingsDidChange" as NSString