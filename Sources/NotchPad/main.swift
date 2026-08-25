import AppKit
import NotchPadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: AppCoordinator?
    private var mainMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        coordinator = AppCoordinator()
        coordinator?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.applicationWillTerminate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        self.mainMenu = mainMenu

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About menote", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit menote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu()
        fileMenuItem.submenu = fileMenu

        fileMenu.addItem(withTitle: "Open TXT…", action: #selector(ScratchpadViewController.openTXT), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Export as TXT…", action: #selector(ScratchpadViewController.exportAsTXT), keyEquivalent: "e")

        // Edit menu - critical for standard text editing shortcuts
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu()
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find…", action: #selector(ScratchpadViewController.findOpen), keyEquivalent: "f")
        editMenu.addItem(withTitle: "Find Next", action: #selector(ScratchpadViewController.findNext), keyEquivalent: "g")
        editMenu.addItem(withTitle: "Find Previous", action: #selector(ScratchpadViewController.findPrevious), keyEquivalent: "G")

        NSApp.mainMenu = mainMenu
    }

    @objc private func showPreferences() {
        coordinator?.openPreferences()
    }
}

let app = NSApplication.shared

var appDelegate: AppDelegate? = AppDelegate()
app.delegate = appDelegate!
app.setActivationPolicy(.accessory)
app.run()