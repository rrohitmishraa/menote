import AppKit
import NotchPadCore

final class LineNumberView: NSView {
    weak var textView: EditorTextView?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    func updateLineNumbers() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}

final class EditorTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.systemFont(ofSize: 18)
        ]
        let placeholder = "Start typing…"
        let rect = textContainerInset
        (placeholder as NSString).draw(at: NSPoint(x: rect.width, y: rect.height + 2), withAttributes: attrs)
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
    private var footerView: NSView!
    private var statusLabel: NSTextField!
    private var storageDot: StatusDotView!

    private var statusTimer: Timer?

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
        root.layer?.cornerRadius = 12
        root.layer?.masksToBounds = true
        root.layer?.cornerCurve = .continuous
        view = root

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
        textView.isRichText = false
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
        textView.textContainerInset = NSSize(width: 24, height: 20)
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

        NSLayoutConstraint.activate([
            editorScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorScroll.topAnchor.constraint(equalTo: view.topAnchor),
            editorScroll.bottomAnchor.constraint(equalTo: footerView.topAnchor)
        ])
    }

    private func buildFooter() {
        footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerView)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        storageDot = StatusDotView()
        storageDot.translatesAutoresizingMaskIntoConstraints = false

        let footerStack = NSStackView(views: [statusLabel, NSView(), storageDot])
        footerStack.orientation = .horizontal
        footerStack.spacing = 8
        footerStack.alignment = .centerY
        footerStack.edgeInsets = NSEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(footerStack)

        NSLayoutConstraint.activate([
            footerStack.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            footerStack.topAnchor.constraint(equalTo: footerView.topAnchor),
            footerStack.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),

            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func reloadFromStore() {
        guard !isLoadingContent else { return }
        isLoadingContent = true
        textView.string = store.currentNote?.plainText ?? store.draftText
        updatePlaceholder()
        textView.scrollToBeginningOfDocument(nil)
        isLoadingContent = false
        resizeEditorToContent()
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
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "Ready"
        case .saving:
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "Saving…"
        case .saved(let date):
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "Saved \(Theme.formatSavedDate(date))"
        case .failed(let msg):
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "⚠ \(msg)"
        }
        let available = store.isStorageAvailable
        storageDot.color = available ? .systemGreen : .systemRed
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
        textView.string = ""
        updatePlaceholder()
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
}

extension ScratchpadViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        resizeEditorToContent()
        guard !isLoadingContent else { return }
        store.updateCurrentText(textView.string)
    }
}
