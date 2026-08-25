import AppKit
import MenoteCore

enum StorageUnavailableAlert {
    static func present(
        reason: String,
        onReconnect: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Storage Unavailable"
        alert.informativeText = """
            Menote cannot access its storage location:
            
            \(reason)
            
            Your existing data has NOT been deleted.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reconnect Drive")
        alert.addButton(withTitle: "Continue in Memory")
        alert.beginSheetModal(for: NSApp.windows.first!) { response in
            switch response {
            case .alertFirstButtonReturn: onReconnect()
            case .alertSecondButtonReturn: onContinue()
            default: onContinue()
            }
        }
    }
}