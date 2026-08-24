import AppKit
import NotchPadCore

final class NotesListOverlayViewController: NSViewController, NSMenuDelegate {
    private let store: NoteStore
    private let onSelect: (Note) -> Void
    private let onNewNote: () -> Void
    private let onPin: (Note) -> Void
    private let onArchive: (Note) -> Void
    private let onDelete: (Note) -> Void

    private var displayedNotes: [Note] = []
    private var searchQuery: String = ""

    var firstDisplayedNote: Note? { displayedNotes.first }

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var emptyLabel: NSTextField!
    private var backButton: NSButton!
    private var newNoteButton: NSButton!

    init(
        store: NoteStore,
        onSelect: @escaping (Note) -> Void,
        onNewNote: @escaping () -> Void,
        onPin: @escaping (Note) -> Void,
        onArchive: @escaping (Note) -> Void,
        onDelete: @escaping (Note) -> Void
    ) {
        self.store = store
        self.onSelect = onSelect
        self.onNewNote = onNewNote
        self.onPin = onPin
        self.onArchive = onArchive
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

override func loadView() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        view = root

        backButton = NSButton(title: "← Notes", target: self, action: #selector(goBack))
        backButton.isBordered = false
        backButton.font = .systemFont(ofSize: 13, weight: .medium)
        backButton.contentTintColor = .labelColor
        backButton.setContentHuggingPriority(.required, for: .horizontal)

        searchField = NSSearchField()
        searchField.placeholderString = "Search notes..."
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.setContentHuggingPriority(.init(1), for: .horizontal)
        searchField.setContentCompressionResistancePriority(.init(249), for: .horizontal)
        searchField.target = self
        searchField.action = #selector(searchFieldAction(_:))
        searchField.delegate = self

        newNoteButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "New Note")!, target: self, action: #selector(createNewNote))
        newNoteButton.isBordered = false
        newNoteButton.contentTintColor = .controlAccentColor
        newNoteButton.setContentHuggingPriority(.required, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let topBar = NSStackView(views: [backButton, searchField, spacer, newNoteButton])
        topBar.orientation = .horizontal
        topBar.spacing = 8
        topBar.alignment = .centerY
        topBar.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(topBar)

        let headerDivider = NSView()
        headerDivider.wantsLayer = true
        headerDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(headerDivider)

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 64
        tableView.intercellSpacing = .zero
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .regular
        tableView.menu = NSMenu()
        tableView.menu?.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickRow(_:))
        tableView.focusRingType = .none
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
        column.width = 500
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        emptyLabel = NSTextField(labelWithString: "No notes yet")
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        root.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            topBar.topAnchor.constraint(equalTo: root.topAnchor),

            headerDivider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            headerDivider.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            headerDivider.heightAnchor.constraint(equalToConstant: 0.5),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerDivider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor)
        ])

        refresh()
    }

    func refresh() {
        displayedNotes = store.search(searchQuery, includeArchived: false)
        
        let logPath = "/tmp/notchpad_debug.log"
        let debugMsg = "DEBUG: NotesListOverlayViewController.refresh() - searchQuery: '\(searchQuery)', displayedNotes: \(displayedNotes.count)\n"
        try? debugMsg.write(toFile: logPath, atomically: false, encoding: .utf8)
        for note in displayedNotes {
            let msg = "DEBUG:   Note: \(note.displayTitle)\n"
            try? msg.write(toFile: logPath, atomically: false, encoding: .utf8)
        }
        
        tableView.reloadData()
        updateEmptyState()
    }

    func setSearchQuery(_ query: String) {
        searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        refresh()
    }

    private func updateEmptyState() {
        let showEmpty = displayedNotes.isEmpty
        emptyLabel.isHidden = !showEmpty
        emptyLabel.stringValue = searchQuery.isEmpty
            ? "No notes yet"
            : "No matching notes"
    }

    @objc private func goBack() {
        onSelect(Note())
    }

    @objc private func createNewNote() {
        onNewNote()
    }

    @objc private func doubleClickRow(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0, row < displayedNotes.count else { return }
        onSelect(displayedNotes[row])
    }

    @objc private func searchFieldAction(_ sender: NSSearchField) {
        let query = sender.stringValue
        setSearchQuery(query)
    }
}

extension NotesListOverlayViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        let logPath = "/tmp/notchpad_debug.log"
        let debugMsg = "DEBUG: numberOfRows: \(displayedNotes.count)\n"
        try? debugMsg.write(toFile: logPath, atomically: false, encoding: .utf8)
        return displayedNotes.count
    }
}

extension NotesListOverlayViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let logPath = "/tmp/notchpad_debug.log"
        let debugMsg = "DEBUG: viewFor row: \(row), note: \(displayedNotes[row].displayTitle)\n"
        try? debugMsg.write(toFile: logPath, atomically: false, encoding: .utf8)
        
        let note = displayedNotes[row]
        let identifier = NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NoteCellView
        if cell == nil {
            cell = NoteCellView()
            cell?.identifier = identifier
        }
        cell?.configure(with: note)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < displayedNotes.count else { return }
        onSelect(displayedNotes[row])
    }

    @objc func menuNeedsUpdate(_ menu: NSMenu) {
        let row = tableView.clickedRow
        guard row >= 0, row < displayedNotes.count else {
            menu.items = []
            return
        }
        let note = displayedNotes[row]

        menu.items = [
            makeItem(note.isPinned ? "Unpin" : "Pin", image: "pin.fill", action: #selector(pinSelected(_:))),
            makeItem(note.isArchived ? "Unarchive" : "Archive", image: "archivebox.fill", action: #selector(archiveSelected(_:))),
            NSMenuItem.separator(),
            makeItem("Delete…", image: "trash.fill", action: #selector(deleteSelected(_:)))
        ]
        menu.items.forEach { $0.representedObject = note }
    }

    private func makeItem(_ title: String, image: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let img = NSImage(systemSymbolName: image, accessibilityDescription: title) {
            img.isTemplate = true
            item.image = img
        }
        return item
    }

    @objc private func pinSelected(_ sender: NSMenuItem) {
        guard let note = sender.representedObject as? Note else { return }
        onPin(note)
    }

    @objc private func archiveSelected(_ sender: NSMenuItem) {
        guard let note = sender.representedObject as? Note else { return }
        onArchive(note)
    }

    @objc private func deleteSelected(_ sender: NSMenuItem) {
        guard let note = sender.representedObject as? Note else { return }
        onDelete(note)
    }
}

extension NotesListOverlayViewController: NSSearchFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let first = firstDisplayedNote {
                onSelect(first)
            }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if searchField.stringValue.isEmpty {
                onSelect(Note())
            } else {
                searchField.stringValue = ""
                setSearchQuery("")
            }
            return true
        }
        return false
    }
}

private class NoteCellView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let pinImage = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        previewLabel.font = .systemFont(ofSize: 11)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.setContentHuggingPriority(.init(1), for: .horizontal)

        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)

        pinImage.contentTintColor = .controlAccentColor
        pinImage.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pinImage.isHidden = true
        pinImage.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = NSStackView(views: [titleLabel, previewLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.setContentHuggingPriority(.init(1), for: .horizontal)

        let topStack = NSStackView(views: [pinImage, textStack])
        topStack.orientation = .horizontal
        topStack.spacing = 6
        topStack.alignment = .centerY

        let stack = NSStackView(views: [topStack, dateLabel])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with note: Note) {
        titleLabel.stringValue = note.displayTitle

        let preview = note.plainText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        if preview.isEmpty {
            previewLabel.stringValue = ""
        } else {
            previewLabel.stringValue = preview.count > 80 ? String(preview.prefix(80)) + "…" : preview
        }

        dateLabel.stringValue = Theme.formatDate(note.modifiedAt)
        pinImage.isHidden = !note.isPinned
    }
}