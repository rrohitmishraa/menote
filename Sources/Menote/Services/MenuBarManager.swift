import AppKit
import MenoteCore

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidRequestNewNote()
    func menuBarDidRequestQuit()
}

final class MenuBarManager {
    weak var delegate: MenuBarManagerDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverContent: ScratchpadViewController?
    private var isPopoverVisible = false

    func setup(with contentController: ScratchpadViewController) {
        self.popoverContent = contentController

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let logoURL = Bundle.main.url(forResource: "logo", withExtension: "png"),
           let logo = NSImage(contentsOf: logoURL) {
            logo.size = NSSize(width: 18, height: 18)
            logo.isTemplate = false
            item.button?.image = logo
        } else {
            item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Menote")
            item.button?.image?.isTemplate = true
        }
        item.button?.toolTip = "Menote"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = contentController
        popover.animates = true
        self.popover = popover

        statusItem = item
    }

    func teardown() {
        popover?.close()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        popover = nil
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.popoverContent?.applyFocus(.editor)
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "About Menote", action: #selector(aboutAction(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Menote", action: #selector(quitAction(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        if let event = NSApp.currentEvent, let button = statusItem?.button {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        }
    }

    @objc private func aboutAction(_ sender: NSMenuItem) {
        AboutWindowController.shared.showAbout()
    }

    @objc private func newNoteAction(_ sender: NSMenuItem) { delegate?.menuBarDidRequestNewNote() }
    @objc private func quitAction(_ sender: NSMenuItem) { delegate?.menuBarDidRequestQuit() }
}