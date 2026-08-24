import Foundation
import Carbon.HIToolbox

public final class HotkeyManager {
    public var onKeyDown: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyIDSignature: OSType = 0x4E504144 // 'NPAD'

    public init() {}

    /// Registers ⌘⇧Space as a system-wide shortcut. Carbon hotkeys do not
    /// require accessibility permissions.
    public func register() {
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
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef)
        _ = hotKeyID
    }
}
