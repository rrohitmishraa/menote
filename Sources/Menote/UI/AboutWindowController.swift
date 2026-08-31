import AppKit
import MenoteCore

final class AboutWindowController: NSWindowController {
    private var launchCheckbox: NSButton?
    private var fileLocationLabel: NSTextField!
    private weak var noteStore: NoteStore?

    static let shared = AboutWindowController()

    private init() {
        super.init(window: nil)
        buildWindow()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(store: NoteStore) {
        self.noteStore = store
    }

    private func buildWindow() {
        let w = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "Menote"
        w.center()
        w.isReleasedWhenClosed = false
        w.setAccessibilityIdentifier("about-window")
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
        stack.spacing = 0
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        // Header
        stack.addArrangedSubview(buildCreditLine())
        stack.addArrangedSubview(makeSpacer(12))
        stack.addArrangedSubview(buildHeader())
        stack.addArrangedSubview(makeSpacer(20))

        // How to use
        stack.addArrangedSubview(buildHowToUseSection())
        stack.addArrangedSubview(makeSpacer(16))

        // Separator
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSpacer(16))

        // File Location
        stack.addArrangedSubview(buildFileLocationSection())
        stack.addArrangedSubview(makeSpacer(16))

        // Separator
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSpacer(16))

        // Reference grid
        stack.addArrangedSubview(buildReferenceGrid())
        stack.addArrangedSubview(makeSpacer(16))

        // Separator
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSpacer(16))

        // Launch at Login
        stack.addArrangedSubview(buildLaunchSection())
        stack.addArrangedSubview(makeSpacer(16))

        // Quit
        stack.addArrangedSubview(buildQuitButton())
        stack.addArrangedSubview(makeSpacer(20))

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),

            content.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentView.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),

            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 424),
        ])
    }

    // MARK: - Sections

    private func buildCreditLine() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let prefix = NSTextField(labelWithString: "Made by Rohit Mishra (")
        prefix.font = .systemFont(ofSize: 12)
        prefix.textColor = .tertiaryLabelColor
        prefix.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(prefix)

        let link = NSTextField(labelWithString: "@techroholic")
        link.font = .systemFont(ofSize: 12)
        link.textColor = .controlAccentColor
        link.attributedStringValue = NSAttributedString(
            string: "@techroholic",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.controlAccentColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        link.translatesAutoresizingMaskIntoConstraints = false
        link.isSelectable = false
        let linkClick = NSClickGestureRecognizer(target: self, action: #selector(openInstagram))
        link.addGestureRecognizer(linkClick)
        v.addSubview(link)

        let suffix = NSTextField(labelWithString: ") with \u{2764}\u{FE0F} in India")
        suffix.font = .systemFont(ofSize: 12)
        suffix.textColor = .tertiaryLabelColor
        suffix.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(suffix)

        // Center the group horizontally in the container
        NSLayoutConstraint.activate([
            link.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            link.centerYAnchor.constraint(equalTo: v.centerYAnchor),

            prefix.trailingAnchor.constraint(equalTo: link.leadingAnchor),
            prefix.centerYAnchor.constraint(equalTo: v.centerYAnchor),

            suffix.leadingAnchor.constraint(equalTo: link.trailingAnchor),
            suffix.centerYAnchor.constraint(equalTo: v.centerYAnchor),

            v.bottomAnchor.constraint(equalTo: prefix.bottomAnchor),
        ])

        return v
    }

    @objc private func openInstagram() {
        if let url = URL(string: "https://www.instagram.com/techroholic") {
            NSWorkspace.shared.open(url)
        }
    }

    private func buildHeader() -> NSView {
        let v = NSView()

        let name = NSTextField(labelWithString: "Menote")
        name.font = .systemFont(ofSize: 22, weight: .semibold)
        name.textColor = .labelColor
        name.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(name)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let versionText: String
        if let version, let build {
            versionText = "Version \(version) (build \(build))"
        } else if let version {
            versionText = "Version \(version)"
        } else if let build {
            versionText = "Build \(build)"
        } else {
            versionText = ""
        }
        let versionLabel = NSTextField(labelWithString: versionText)
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(versionLabel)

        let desc = NSTextField(wrappingLabelWithString: "A minimal menu-bar writing app.")
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        desc.alignment = .center
        desc.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(desc)

        NSLayoutConstraint.activate([
            name.topAnchor.constraint(equalTo: v.topAnchor),
            name.centerXAnchor.constraint(equalTo: v.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4),
            versionLabel.centerXAnchor.constraint(equalTo: v.centerXAnchor),

            desc.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 8),
            desc.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            desc.leadingAnchor.constraint(greaterThanOrEqualTo: v.leadingAnchor),
            desc.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor),
            desc.bottomAnchor.constraint(equalTo: v.bottomAnchor),
        ])

        return v
    }

    private func buildHowToUseSection() -> NSView {
        let v = makeFullWidthStack()

        v.addArrangedSubview(sectionLabel("How to Use Menote"))

        let items = [
            "Click the Menote icon in your menu bar to open the editor.",
            "Type notes directly — they save automatically.",
            "Use the toolbar buttons for Open, Save a Copy, Bold, Italic, and text colors.",
        ]

        for text in items {
            v.addArrangedSubview(bulletText(text))
        }

        return v
    }

    private func buildReferenceGrid() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Left column
        let left = makeFullWidthStack()
        left.spacing = 10

        left.addArrangedSubview(sectionLabel("Keyboard Shortcuts"))
        for (key, desc) in [("⌘B","Bold"),("⌘I","Italic"),("⌘F","Find"),("⌘G","Next"),("⇧⌘G","Previous"),("⌘Z","Undo"),("⇧⌘Z","Redo"),("⌘Q","Quit")] {
            left.addArrangedSubview(shortcutRow(key, desc))
        }

        left.addArrangedSubview(makeSpacer(10))

        left.addArrangedSubview(sectionLabel("Text Formatting"))
        for (title, desc) in [("Bold","Select text, press ⌘B"),("Italic","Select text, press ⌘I"),("Colors","Use color circles in toolbar")] {
            left.addArrangedSubview(bulletRow(title, desc))
        }
        left.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(left)

        // Single vertical separator
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)

        // Right column
        let right = makeFullWidthStack()
        right.spacing = 10

        right.addArrangedSubview(sectionLabel("Slash Commands"))
        for (cmd, desc) in [("/line","Insert separator"),("/list","Start bullet list"),("/number","Start numbered list")] {
            right.addArrangedSubview(shortcutRow(cmd, desc))
        }
        let hint = NSTextField(wrappingLabelWithString: "Type \"/\" at the start of a line for suggestions. Enter to execute, Escape to close.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.preferredMaxLayoutWidth = 180
        let hintWrapper = NSStackView()
        hintWrapper.orientation = .horizontal
        hintWrapper.addArrangedSubview(hint)
        right.addArrangedSubview(hintWrapper)

        right.addArrangedSubview(makeSpacer(10))

        right.addArrangedSubview(sectionLabel("Files"))
        for (title, desc) in [("Open","Open a .menote file (\u{2318}O)"),("Save","Auto-saves to active file"),("Save a Copy","Save a copy anywhere (\u{2318}E)")] {
            right.addArrangedSubview(bulletRow(title, desc))
        }
        right.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(right)

        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            left.topAnchor.constraint(equalTo: container.topAnchor),
            left.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            sep.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 12),
            sep.widthAnchor.constraint(equalToConstant: 1),
            sep.topAnchor.constraint(equalTo: container.topAnchor),
            sep.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            right.leadingAnchor.constraint(equalTo: sep.trailingAnchor, constant: 12),
            right.topAnchor.constraint(equalTo: container.topAnchor),
            right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            right.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
        ])

        return container
    }

    private func buildLaunchSection() -> NSView {
        let v = makeFullWidthStack()

        let launchBtn = NSButton(checkboxWithTitle: "Launch Menote at Login", target: self, action: #selector(launchAtLoginChanged(_:)))
        launchBtn.state = LaunchAtLoginManager.isEnabled() ? .on : .off
        if !LaunchAtLoginManager.isSupported {
            launchBtn.isEnabled = false
            launchBtn.toolTip = "Requires app to be run from a built .app bundle"
        }
        launchCheckbox = launchBtn
        v.addArrangedSubview(launchBtn)

        return v
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        if !LaunchAtLoginManager.setEnabled(enabled) {
            sender.state = LaunchAtLoginManager.isEnabled() ? .on : .off
        }
    }

    private func buildQuitButton() -> NSView {
        let btn = NSButton(title: "Quit Menote", target: self, action: #selector(quitApp))
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.font = .systemFont(ofSize: 12)
        let wrapper = makeFullWidthStack()
        wrapper.alignment = .centerX
        wrapper.addArrangedSubview(btn)
        return wrapper
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - File Location

    private func buildFileLocationSection() -> NSView {
        let v = makeFullWidthStack()

        v.addArrangedSubview(sectionLabel("File Location"))

        fileLocationLabel = NSTextField(wrappingLabelWithString: "Not Available")
        fileLocationLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        fileLocationLabel.textColor = .secondaryLabelColor
        fileLocationLabel.preferredMaxLayoutWidth = 400
        fileLocationLabel.lineBreakMode = .byTruncatingMiddle
        let labelWrapper = makeFullWidthStack()
        labelWrapper.addArrangedSubview(fileLocationLabel)
        v.addArrangedSubview(labelWrapper)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let copyPathBtn = NSButton(title: "Copy Path", target: self, action: #selector(copyPath))
        copyPathBtn.bezelStyle = .rounded
        copyPathBtn.controlSize = .small
        copyPathBtn.font = .systemFont(ofSize: 12)

        let openFolderBtn = NSButton(title: "Open Folder", target: self, action: #selector(openFolder))
        openFolderBtn.bezelStyle = .rounded
        openFolderBtn.controlSize = .small
        openFolderBtn.font = .systemFont(ofSize: 12)

        buttonRow.addArrangedSubview(copyPathBtn)
        buttonRow.addArrangedSubview(openFolderBtn)

        let btnWrapper = makeFullWidthStack()
        btnWrapper.addArrangedSubview(buttonRow)
        v.addArrangedSubview(btnWrapper)

        return v
    }

    private func refreshFileLocation() {
        guard let noteStore else {
            Logger.shared.log("[DEBUG] About: noteStore is nil")
            fileLocationLabel.stringValue = "Not Available"
            return
        }
        if let url = noteStore.activeFileURL {
            Logger.shared.log("[DEBUG] About: Active file URL = \(url.path)")
            fileLocationLabel.stringValue = url.path
        } else {
            Logger.shared.log("[DEBUG] About: activeFileURL is nil")
            fileLocationLabel.stringValue = "Not Available"
        }
    }

    @objc private func copyPath() {
        guard let noteStore, let url = noteStore.activeFileURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)

        let feedback = NSTextField(labelWithString: "Copied")
        feedback.font = .systemFont(ofSize: 11, weight: .medium)
        feedback.textColor = .controlAccentColor
        feedback.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = window?.contentView {
            contentView.addSubview(feedback)
            NSLayoutConstraint.activate([
                feedback.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                feedback.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
            ])
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 1.5
                ctx.allowsImplicitAnimation = true
                feedback.animator().alphaValue = 0
            } completionHandler: {
                feedback.removeFromSuperview()
            }
        }
    }

    @objc private func openFolder() {
        guard let noteStore, let url = noteStore.activeFileURL else { return }
        NSWorkspace.shared.open(url.deletingLastPathComponent())
    }

    private func sectionLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let wrapper = makeFullWidthStack()
        wrapper.addArrangedSubview(label)
        return wrapper
    }

    private func bulletText(_ text: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6

        let bullet = NSTextField(labelWithString: "•")
        bullet.font = .systemFont(ofSize: 12)
        bullet.textColor = .tertiaryLabelColor

        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.preferredMaxLayoutWidth = 400

        row.addArrangedSubview(bullet)
        row.addArrangedSubview(label)
        return row
    }

    private func shortcutRow(_ key: String, _ desc: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline

        let keyLabel = NSTextField(labelWithString: key)
        keyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        keyLabel.textColor = .labelColor
        keyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        let descLabel = NSTextField(labelWithString: desc)
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor

        row.addArrangedSubview(keyLabel)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func bulletRow(_ title: String, _ desc: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline

        let t = NSTextField(labelWithString: title)
        t.font = .systemFont(ofSize: 12, weight: .medium)
        t.textColor = .labelColor

        let d = NSTextField(wrappingLabelWithString: desc)
        d.font = .systemFont(ofSize: 12)
        d.textColor = .secondaryLabelColor
        d.preferredMaxLayoutWidth = 300

        row.addArrangedSubview(t)
        row.addArrangedSubview(d)
        return row
    }

    private func makeFullWidthStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        return stack
    }

    private func makeSpacer(_ height: CGFloat) -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        let wrapper = makeFullWidthStack()
        wrapper.addArrangedSubview(sep)
        return wrapper
    }

    // MARK: - Presentation

    func showAbout() {
        refreshFileLocation()
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
        } else {
            launchCheckbox?.state = LaunchAtLoginManager.isEnabled() ? .on : .off
            showWindow(nil)
        }
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
