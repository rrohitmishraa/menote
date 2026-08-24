import AppKit
import NotchPadCore

final class PreferencesWindowController: NSWindowController {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init(window: nil)
        buildWindow()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        w.title = "menote Settings"
        w.center()
        w.setAccessibilityIdentifier("preferences-window")
        self.window = w

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        w.contentView?.addSubview(scroll)

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 24
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        // Access Point
        stack.addArrangedSubview(buildAccessPointSection())

        // Appearance
        stack.addArrangedSubview(buildAppearanceSection())

        // General
        stack.addArrangedSubview(buildGeneralSection())

        // About
        stack.addArrangedSubview(buildAboutSection())

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),

            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),

            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(preferencesChanged),
            name: AppSettings.didChange, object: nil)
    }

    @objc private func preferencesChanged() {
        // No storage section to refresh
    }

    private func sectionHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func buildAccessPointSection() -> NSView {
        return NSView()
    }

    private func buildAppearanceSection() -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .noBorder
        box.fillColor = .clear

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        stack.addArrangedSubview(sectionHeader("Appearance"))

        let radioStack = NSStackView()
        radioStack.orientation = .horizontal
        radioStack.spacing = 20

        for (label, value) in [("System", AppearanceMode.system), ("Light", AppearanceMode.light), ("Dark", AppearanceMode.dark)] {
            let btn = NSButton(radioButtonWithTitle: label, target: self, action: #selector(appearanceChanged(_:)))
            btn.state = (coordinator.settings.appearance == value) ? .on : .off
            btn.identifier = NSUserInterfaceItemIdentifier(value.rawValue)
            radioStack.addArrangedSubview(btn)
        }

        stack.addArrangedSubview(radioStack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])

        return box
    }

    @objc private func appearanceChanged(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let mode = AppearanceMode(rawValue: raw) else { return }
        coordinator.settings.appearance = mode
        applyAppearance(mode)
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func buildGeneralSection() -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .noBorder
        box.fillColor = .clear

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        stack.addArrangedSubview(sectionHeader("General"))

        let launchBtn = NSButton(checkboxWithTitle: "Launch menote at Login", target: self, action: #selector(launchAtLoginChanged(_:)))
        launchBtn.state = coordinator.settings.launchAtLogin ? .on : .off
        if !LaunchAtLoginManager.isSupported {
            launchBtn.isEnabled = false
            launchBtn.toolTip = "Requires app to be run from a built .app bundle"
        }
        stack.addArrangedSubview(launchBtn)

        let hotkeyLabel = NSTextField(labelWithString: "Global Shortcut: ⌘ ⇧ Space (customizable in a future update)")
        hotkeyLabel.font = .systemFont(ofSize: 12)
        hotkeyLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hotkeyLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])

        return box
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        if LaunchAtLoginManager.setEnabled(enabled) {
            coordinator.settings.launchAtLogin = enabled
        } else {
            sender.state = coordinator.settings.launchAtLogin ? .on : .off
        }
    }

    private func buildAboutSection() -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .noBorder
        box.fillColor = .clear

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        stack.addArrangedSubview(sectionHeader("About"))

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let versionLabel = NSTextField(labelWithString: "menote \(version)")
        versionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        stack.addArrangedSubview(versionLabel)

        let privacy = NSTextField(wrappingLabelWithString: "menote is fully offline. Your notes, images, and clipboard history never leave this Mac. No analytics. No tracking.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        privacy.preferredMaxLayoutWidth = 480
        stack.addArrangedSubview(privacy)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])

        return box
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification, object: window)
    }

    @objc private func windowClosed() {
        NotificationCenter.default.removeObserver(self)
    }
}

private extension NSBox {
    private static var stackKey = "prefs_box_stack"
    var stack: NSStackView? {
        get { objc_getAssociatedObject(self, &NSBox.stackKey) as? NSStackView }
        set { objc_setAssociatedObject(self, &NSBox.stackKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private extension NSImageView {
    func with(_ configure: (NSImageView) -> Void) -> NSImageView {
        configure(self)
        return self
    }
}