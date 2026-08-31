import Foundation
import Carbon.HIToolbox

public final class HotkeyManager {
    public var onKeyDown: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyIDSignature: OSType = 0x4E504144 // 'NPAD'

    public init() {}

    /// Registers a global shortcut using Carbon event handler.
    /// The handler is called on the main thread when the shortcut is pressed.
    /// Call this method once during application launch.
    /// - Parameters:
    ///   - keyCode: The Carbon key code for the shortcut (e.g., kVK_ANSI_1 = 18)
    ///   - modifierMask: The modifier key mask (e.g., cmdKey | shiftKey)
    public func register(keyCode: UInt32, modifierMask: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, _, userData in
            if let userData {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onKeyDown?()
                }
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &eventHandler)
        guard status == noErr else { return }

        var hotKeyID = EventHotKeyID(signature: hotKeyIDSignature, id: 1)
        let status2 = RegisterEventHotKey(
            keyCode,
            modifierMask,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef)
        if status2 == noErr {
            // successfully registered
        }
        _ = hotKeyID
    }

    deinit {
        if hotKeyRef != nil {
            UnregisterEventHotKey(hotKeyRef!)
        }
    }
}