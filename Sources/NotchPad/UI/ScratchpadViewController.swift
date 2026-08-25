import AppKit
import NotchPadCore

final class LineNumberView: NSView {
    weak var textView: EditorTextView?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func updateLayer() {
        super.updateLayer()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let textView = textView else { return }

        guard let layoutManager = textView.layoutManager else { return }

        let editorFont = textView.font ?? NSFont.systemFont(ofSize: 18)
        let gutterFont = NSFont.systemFont(ofSize: max(editorFont.pointSize - 4, 11), weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: gutterFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        var baselineOffset: CGFloat? = nil

        let gutterWidth = bounds.width
        let inset = textView.textContainerInset
        let scrollOffset = textView.enclosingScrollView?.contentView.bounds.origin.y ?? 0

        let lines = textView.string.components(separatedBy: "\n")
        var charOffset = 0
        var prevFragmentMaxY: CGFloat = 0
        var lastFragHeight: CGFloat = editorFont.ascender - editorFont.descender

        for (lineNumber, line) in lines.enumerated() {
            let charRange = NSRange(location: charOffset, length: line.utf16.count)
            var actualCharRange = NSRange()
            let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: &actualCharRange)

            var effectiveRange = NSRange()
            let lineFragmentRect: NSRect
            if glyphRange.location < layoutManager.numberOfGlyphs {
                lineFragmentRect = layoutManager.lineFragmentRect(
                    forGlyphAt: glyphRange.location, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                if baselineOffset == nil, !line.isEmpty {
                    baselineOffset = layoutManager.location(forGlyphAt: glyphRange.location).y
                }
            } else {
                lineFragmentRect = .zero
            }

            let fragTop: CGFloat
            let fragHeight: CGFloat
            if lineFragmentRect.height > 0 {
                fragTop = lineFragmentRect.origin.y
                fragHeight = lineFragmentRect.height
                prevFragmentMaxY = fragTop + fragHeight
                lastFragHeight = fragHeight
            } else {
                fragTop = prevFragmentMaxY
                fragHeight = lastFragHeight
                prevFragmentMaxY = fragTop + fragHeight
            }

            let visibleTop = fragTop + inset.height - scrollOffset

            guard visibleTop > -fragHeight else {
                charOffset += line.utf16.count + 1
                continue
            }
            guard visibleTop < bounds.height + fragHeight else {
                break
            }

            let baselineY = visibleTop + (baselineOffset ?? layoutManager.defaultBaselineOffset(for: editorFont))

            let numberString = "\(lineNumber + 1)"
            let numberSize = numberString.size(withAttributes: attributes)

            let x = gutterWidth - numberSize.width - 6

            numberString.draw(at: NSPoint(x: x, y: baselineY - gutterFont.ascender), withAttributes: attributes)

            charOffset += line.utf16.count + 1
        }
    }
}

final class HoverButton: NSButton {
    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovering {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            path.fill()
        }
        super.draw(dirtyRect)
    }
}

final class EditorTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    private let baseFont: NSFont = .systemFont(ofSize: 18)

    func toggleTrait(_ trait: NSFontTraitMask) {
        let manager = NSFontManager.shared
        guard let storage = textStorage else { return }
        let selected = selectedRange()
        if selected.length > 0 {
            // Coordinate through NSTextView so the formatting change is recorded as a
            // normal undoable operation in its NSUndoManager (⌘Z / ⇧⌘Z).
            if shouldChangeText(in: selected, replacementString: nil) {
                storage.beginEditing()
                var index = selected.location
                let end = selected.upperBound
                while index < end {
                    var effective = NSRange()
                    let attributes = storage.attributes(at: index, effectiveRange: &effective)
                    let font = (attributes[.font] as? NSFont) ?? baseFont
                    let has = manager.traits(of: font).contains(trait)
                    let newFont = has
                        ? manager.convert(font, toNotHaveTrait: trait)
                        : manager.convert(font, toHaveTrait: trait)
                    storage.addAttribute(.font, value: newFont, range: NSIntersectionRange(effective, selected))
                    index = NSMaxRange(effective)
                }
                storage.endEditing()
                didChangeText()
            }
        } else {
            var attrs = typingAttributes
            let font = (attrs[.font] as? NSFont) ?? baseFont
            let has = manager.traits(of: font).contains(trait)
            let newFont = has
                ? manager.convert(font, toNotHaveTrait: trait)
                : manager.convert(font, toHaveTrait: trait)
            attrs[.font] = newFont
            typingAttributes = attrs
        }
        needsDisplay = true
    }

    // Drag & drop support for .txt files
    var onFileDrop: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasValidTXTFile(sender) {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.propertyList(forType: .fileURL) as? [String],
              let url = urls.first else { return false }

        let fileURL = URL(fileURLWithPath: url)
        guard fileURL.pathExtension.lowercased() == "txt" else { return false }

        onFileDrop?(fileURL)
        return true
    }

    private func hasValidTXTFile(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.propertyList(forType: .fileURL) as? [String],
              let urlString = urls.first else { return false }
        return (urlString as NSString).pathExtension.lowercased() == "txt"
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "b": toggleTrait(.boldFontMask); return true
            case "i": toggleTrait(.italicFontMask); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

protocol ScratchpadActions: AnyObject {
    func openPreferences()
    func quitApp()
}

final class ScratchpadViewController: NSViewController {
    enum Focus { case editor }

    private let store: NoteStore
    private let actions: ScratchpadActions

    private var isLoadingContent = false

    private var editorScroll: NSScrollView!
    private(set) var textView: EditorTextView!
    private var lineNumberView: LineNumberView!
    private var headerView: NSView!
    private var footerView: NSView!
    private var statusLabel: NSTextField!

    private var statusTimer: Timer?

    // Find bar state
    private var findControls: NSStackView!
    private var findIconButton: NSButton!
    private var findField: NSSearchField!
    private var findCount: NSTextField!
    private var isFindOpen = false
    private var matchRanges: [NSRange] = []
    private var currentMatchIndex = 0
    private let findHighlightColor = NSColor(srgbRed: 1.0, green: 0.95, blue: 0.45, alpha: 0.35)
    private let findCurrentColor = NSColor(srgbRed: 1.0, green: 0.84, blue: 0.0, alpha: 0.6)

    init(store: NoteStore, actions: ScratchpadActions) {
        self.store = store
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
        self.preferredContentSize = NSSize(width: 480, height: 420)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 10
        root.layer?.masksToBounds = true
        root.layer?.cornerCurve = .continuous
        root.layer?.borderWidth = 0.5
        root.layer?.borderColor = NSColor.separatorColor.cgColor
        view = root

        buildHeader()
        buildFooter()
        buildEditor()

        store.currentNoteChanged = { [weak self] in self?.reloadFromStore() }
        store.statusChanged = { [weak self] in self?.updateFooter() }

        NotificationCenter.default.addObserver(
            self, selector: #selector(storageAvailabilityChanged),
            name: StorageManager.availabilityDidChange, object: nil)

        updateFooter()
        startStatusTimer()
        reloadFromStore()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyFocus(.editor)
        resizeEditorToContent()
    }

    private func buildEditor() {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.addTextContainer(textContainer)

        textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 392), textContainer: textContainer)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = .systemFont(ofSize: 18)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.typingAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 18)
        ]
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.controlAccentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.delegate = self
        textView.setAccessibilityIdentifier("editor-text")

        editorScroll = NSScrollView()
        editorScroll.hasVerticalScroller = true
        editorScroll.hasHorizontalScroller = false
        editorScroll.autohidesScrollers = true
        editorScroll.borderType = .noBorder
        editorScroll.horizontalScrollElasticity = .none
        editorScroll.drawsBackground = false
        editorScroll.documentView = textView
        editorScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editorScroll)

        lineNumberView = LineNumberView()
        lineNumberView.textView = textView
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lineNumberView)

        editorScroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrollViewDidScroll),
            name: NSView.boundsDidChangeNotification, object: editorScroll.contentView)

        // Drag & drop support for .txt files
        textView.registerForDraggedTypes([.fileURL])
        textView.onFileDrop = { [weak self] url in self?.loadTXTFromURL(url) }

        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: 44),

            editorScroll.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            editorScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorScroll.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            editorScroll.bottomAnchor.constraint(equalTo: footerView.topAnchor)
        ])
    }

    private func makeToolbarButton(title: String? = nil, image: NSImage? = nil, target: AnyObject, action: Selector, tooltip: String) -> NSButton {
        let button: HoverButton
        if let image {
            button = HoverButton(image: image, target: target, action: action)
            button.imagePosition = .imageOnly
        } else {
            button = HoverButton(title: title ?? "", target: target, action: action)
        }
        button.bezelStyle = .texturedRounded
        button.controlSize = .small
        button.isBordered = false
        button.refusesFirstResponder = true
        button.toolTip = tooltip
        return button
    }

    private func buildHeader() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let openButton = makeToolbarButton(
            image: NSImage(systemSymbolName: "doc", accessibilityDescription: "Open TXT")!,
            target: self, action: #selector(openTXT), tooltip: "Open TXT (⌘O)")

        let exportButton = makeToolbarButton(
            image: NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export TXT")!,
            target: self, action: #selector(exportAsTXT), tooltip: "Export as TXT (⌘E)")

        let boldButton = makeToolbarButton(
            title: "B", target: self, action: #selector(toggleBold), tooltip: "Bold (⌘B)")
        boldButton.font = NSFont.boldSystemFont(ofSize: 13)

        let italicButton = makeToolbarButton(
            title: "I", target: self, action: #selector(toggleItalic), tooltip: "Italic (⌘I)")
        italicButton.font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 13), toHaveTrait: .italicFontMask)

        let leftStack = NSStackView(views: [openButton, exportButton, boldButton, italicButton])
        leftStack.orientation = .horizontal
        leftStack.spacing = 4
        leftStack.alignment = .centerY
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(leftStack)

        findField = NSSearchField()
        findField.translatesAutoresizingMaskIntoConstraints = false
        findField.delegate = self
        findField.font = .systemFont(ofSize: 12)
        findField.placeholderString = "Find"
        findField.maximumRecents = 0
        findField.sendsSearchStringImmediately = true
        findField.widthAnchor.constraint(equalToConstant: 160).isActive = true

        findCount = NSTextField(labelWithString: "")
        findCount.font = .systemFont(ofSize: 11)
        findCount.textColor = .tertiaryLabelColor

        let findControls = NSStackView(views: [findCount, findField])
        findControls.orientation = .horizontal
        findControls.spacing = 6
        findControls.alignment = .centerY
        findControls.isHidden = true
        self.findControls = findControls

        findIconButton = makeToolbarButton(
            image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Find")!,
            target: self, action: #selector(toggleFind), tooltip: "Find (⌘F)")

        let rightStack = NSStackView(views: [findControls, findIconButton])
        rightStack.orientation = .horizontal
        rightStack.spacing = 6
        rightStack.alignment = .centerY
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(rightStack)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(separator)

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 10),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),
            leftStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            rightStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            rightStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func buildFooter() {
        footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerView)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        let footerStack = NSStackView(views: [statusLabel])
        footerStack.orientation = .horizontal
        footerStack.spacing = 8
        footerStack.alignment = .centerY
        footerStack.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(footerStack)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(separator)

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            separator.topAnchor.constraint(equalTo: footerView.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            footerStack.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            footerStack.topAnchor.constraint(equalTo: separator.bottomAnchor),
            footerStack.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),

            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func reloadFromStore() {
        guard !isLoadingContent else { return }
        isLoadingContent = true
        if let rtf = store.currentNote?.richText,
           let attr = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(normalizeAttributedString(attr))
        } else {
            let string = store.currentNote?.plainText ?? store.draftText
            textView.textStorage?.setAttributedString(NSAttributedString(
                string: string,
                attributes: [.font: NSFont.systemFont(ofSize: 18),
                             .foregroundColor: NSColor.labelColor]))
        }
        updatePlaceholder()
        textView.scrollToBeginningOfDocument(nil)
        textView.typingAttributes = [.foregroundColor: NSColor.labelColor,
                                     .font: NSFont.systemFont(ofSize: 18)]
        isLoadingContent = false
        resizeEditorToContent()
        lineNumberView?.needsDisplay = true
    }

    private func normalizeAttributedString(_ attr: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let manager = NSFontManager.shared
        var index = 0
        while index < attr.length {
            var effective = NSRange()
            let attributes = attr.attributes(at: index, effectiveRange: &effective)
            var next = attributes
            if let font = attributes[.font] as? NSFont {
                let traits = manager.traits(of: font)
                var normalized = NSFont.systemFont(ofSize: 18)
                if traits.contains(.boldFontMask) {
                    normalized = manager.convert(normalized, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    normalized = manager.convert(normalized, toHaveTrait: .italicFontMask)
                }
                next[.font] = normalized
            } else {
                next[.font] = NSFont.systemFont(ofSize: 18)
            }
            let substring = attr.attributedSubstring(from: effective).string
            result.append(NSAttributedString(string: substring, attributes: next))
            index = NSMaxRange(effective)
        }
        return result
    }

    private func currentRichTextData() -> Data? {
        guard let storage = textView.textStorage, storage.length > 0 else { return nil }
        let fullRange = NSRange(location: 0, length: storage.length)
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        return try? storage.rtf(from: fullRange, documentAttributes: documentAttributes)
    }

    private func resizeEditorToContent() {
        guard let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }
        layoutManager.ensureLayout(for: container)
        let inset = textView.textContainerInset
        let contentHeight = layoutManager.usedRect(for: container).height + inset.height * 2
        let width = editorScroll.contentSize.width
        let minHeight = max(editorScroll.contentSize.height, 1)
        let newHeight = max(contentHeight, minHeight)
        let newWidth = max(width, 1)
        if abs(textView.frame.height - newHeight) > 0.5 || abs(textView.frame.width - newWidth) > 0.5 {
            textView.setFrameSize(NSSize(width: newWidth, height: newHeight))
        }
    }

    private func updatePlaceholder() {
        textView.needsDisplay = true
    }

    private func updateFooter() {
        switch store.saveStatus {
        case .idle:
            statusLabel.textColor = .tertiaryLabelColor
            statusLabel.stringValue = "Ready"
        case .saving:
            statusLabel.textColor = .tertiaryLabelColor
            statusLabel.stringValue = "Saving…"
        case .saved(let date):
            statusLabel.textColor = .tertiaryLabelColor
            statusLabel.stringValue = "Saved \(Theme.formatSavedDate(date))"
        case .failed(let msg):
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "⚠ \(msg)"
        }
    }

    private func startStatusTimer() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.updateFooter()
        }
        RunLoop.current.add(statusTimer!, forMode: .common)
    }

    @objc private func storageAvailabilityChanged() {
        updateFooter()
        if case .failed = store.saveStatus {
            store.scheduleSave()
        }
    }

    func newNote() {
        store.beginDraft()
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        textView.typingAttributes = [.foregroundColor: NSColor.labelColor,
                                     .font: NSFont.systemFont(ofSize: 18)]
        updatePlaceholder()
        lineNumberView?.needsDisplay = true
        applyFocus(.editor)
    }

    func applyFocus(_ focus: Focus) {
        view.window?.makeKeyAndOrderFront(nil)
        switch focus {
        case .editor:
            view.window?.makeFirstResponder(textView)
        }
    }

    func flushBeforeCollapse() {
        store.flushSync()
    }

    // MARK: - TXT Export / Import

    @objc func exportAsTXT() {
        let text = textView.string
        guard !text.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "note.txt"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self?.showImportError("Could not export: \(error.localizedDescription)")
            }
        }
    }

    @objc func openTXT() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.isExtensionHidden = false
        panel.message = "Select a text file to open. The current note will be replaced."

        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.loadTXTFromURL(url)
        }
    }

    private func loadTXTFromURL(_ url: URL) {
        guard textView.string.isEmpty || store.currentNoteID == nil else {
            let alert = NSAlert()
            alert.messageText = "Open this text file?"
            alert.informativeText = "Your current note will be replaced."
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning

            if alert.runModal() == .alertFirstButtonReturn {
                performTXTImport(from: url)
            }
            return
        }
        performTXTImport(from: url)
    }

    private func performTXTImport(from url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            textView.undoManager?.beginUndoGrouping()
            textView.selectAll(nil)
            textView.insertText(text, replacementRange: textView.selectedRange())
            textView.undoManager?.endUndoGrouping()
            textView.scrollToBeginningOfDocument(nil)
            resizeEditorToContent()
            lineNumberView?.needsDisplay = true
            refreshMatches()
        } catch {
            showImportError("Could not read file: \(error.localizedDescription)")
        }
    }

    private func showImportError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Import Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func lineNumberRedraw(_ notification: Notification?) {
        lineNumberView?.needsDisplay = true
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        lineNumberView?.needsDisplay = true
    }
}

extension ScratchpadViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        resizeEditorToContent()
        guard !isLoadingContent else { return }
        let rtf = currentRichTextData()
        store.updateCurrentText(textView.string, richText: rtf)
        lineNumberRedraw(nil)
        refreshMatches()
    }

    @objc private func toggleBold() {
        textView.toggleTrait(.boldFontMask)
    }

    @objc private func toggleItalic() {
        textView.toggleTrait(.italicFontMask)
    }
}

extension ScratchpadViewController: NSSearchFieldDelegate {
    // MARK: - Find (menu / shortcuts)

    @objc func findOpen(_ sender: Any?) {
        isFindOpen = true
        findControls.isHidden = false
        setFindIcon(close: true)
        view.window?.makeFirstResponder(findField)
        runSearch()
    }

    @objc private func toggleFind(_ sender: Any?) {
        if isFindOpen {
            closeFind()
        } else {
            findOpen(sender)
        }
    }

    private func setFindIcon(close: Bool) {
        let symbol = close ? "xmark" : "magnifyingglass"
        let label = close ? "Close Find (Esc)" : "Find (⌘F)"
        findIconButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        findIconButton.toolTip = label
    }

    @objc func findNext(_ sender: Any?) {
        if !isFindOpen { findOpen(sender); return }
        goToNextMatch()
    }

    @objc func findPrevious(_ sender: Any?) {
        if !isFindOpen { findOpen(sender); return }
        goToPreviousMatch()
    }

    // MARK: - Find bar behavior

    private func runSearch() {
        guard isFindOpen else { return }
        let query = findField.stringValue
        if query.isEmpty {
            matchRanges.removeAll()
            currentMatchIndex = 0
            updateCountLabel()
            clearHighlights()
            return
        }
        matchRanges = findRanges(query: query, in: textView.string)
        currentMatchIndex = 0
        if let _ = matchRanges.first {
            selectCurrentMatch()
        } else {
            updateCountLabel()
            clearHighlights()
        }
    }

    private func refreshMatches() {
        guard isFindOpen else { return }
        let query = findField.stringValue
        guard !query.isEmpty else { return }
        matchRanges = findRanges(query: query, in: textView.string)
        if matchRanges.isEmpty {
            currentMatchIndex = 0
        } else {
            currentMatchIndex = min(currentMatchIndex, matchRanges.count - 1)
        }
        applyHighlights()
        updateCountLabel()
    }

    private func goToNextMatch() {
        guard !matchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchRanges.count
        selectCurrentMatch()
    }

    private func goToPreviousMatch() {
        guard !matchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchRanges.count) % matchRanges.count
        selectCurrentMatch()
    }

    private func selectCurrentMatch() {
        guard matchRanges.indices.contains(currentMatchIndex) else { return }
        applyHighlights()
        selectRange(matchRanges[currentMatchIndex])
        updateCountLabel()
    }

    private func applyHighlights() {
        guard let lm = textView.layoutManager, let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        for (i, range) in matchRanges.enumerated() {
            let color = (i == currentMatchIndex) ? findCurrentColor : findHighlightColor
            lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }
    }

    private func clearHighlights() {
        guard let lm = textView.layoutManager, let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
    }

    private func selectRange(_ range: NSRange) {
        // Native selection highlight; does NOT create an undo op and does NOT save.
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }

    @objc private func closeFind() {
        isFindOpen = false
        findControls.isHidden = true
        setFindIcon(close: false)
        matchRanges.removeAll()
        currentMatchIndex = 0
        clearHighlights()
        view.window?.makeFirstResponder(textView)
    }

    private func updateCountLabel() {
        let query = findField.stringValue
        if query.isEmpty {
            findCount.stringValue = ""
        } else if matchRanges.isEmpty {
            findCount.stringValue = "No matches"
        } else {
            findCount.stringValue = "\(currentMatchIndex + 1) of \(matchRanges.count)"
        }
    }

    private func findRanges(query: String, in text: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        var ranges: [NSRange] = []
        let ns = text as NSString
        var searchRange = NSRange(location: 0, length: ns.length)
        while searchRange.location < ns.length {
            let found = ns.range(of: query, options: .caseInsensitive, range: searchRange)
            if found.location == NSNotFound { break }
            ranges.append(found)
            let next = NSMaxRange(found)
            if next >= ns.length { break }
            searchRange = NSRange(location: next, length: ns.length - next)
        }
        return ranges
    }

    // Live search as the user types.
    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }

    // Enter -> next match, Shift+Enter -> previous match, Escape -> close.
    func control(_ control: NSControl, textView fieldEditor: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            if shift {
                goToPreviousMatch()
            } else {
                goToNextMatch()
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            closeFind()
            return true
        }
        return false
    }
}