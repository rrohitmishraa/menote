import AppKit
import MenoteCore

protocol NotesSidebarDelegate: AnyObject {
    func sidebarDidSelectNote(_ note: Note)
    func sidebarDidCreateNewNote()
    func sidebarDidRequestRename(_ note: Note, newTitle: String)
    func sidebarDidRequestDelete(_ notes: [Note])
    func sidebarDidSelectMultipleNotes(_ notes: [Note])
}

final class NotesSidebarViewController: NSViewController {
    private let store: NoteStore
    private weak var delegate: NotesSidebarDelegate?
    
    private var displayedNotes: [Note] = []
    private var searchQuery: String = ""
    private var hoveredRow: Int = -1
    
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var emptyLabel: NSTextField!
    private var backButton: NSButton!
    private var newNoteButton: NSButton!
    
    init(store: NoteStore, delegate: NotesSidebarDelegate) {
        self.store = store
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view = root
        
        buildHeader()
        buildTableView()
        buildEmptyState()
        
        store.notesChanged = { [weak self] in self?.refresh() }
        
        refresh()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        debugPrintSidebarLayout()
    }
    
    func debugPrintSidebarLayout() {
        let logPath = "/tmp/notchpad_layout_debug.log"
        let lines = [
            "=== SIDEBAR LAYOUT DEBUG ===",
            "SIDEBAR VIEW: frame=\(view.frame)",
            "SIDEBAR SCROLLVIEW: frame=\(scrollView.frame)",
            "SIDEBAR SCROLLVIEW contentView.bounds=\(scrollView.contentView.bounds)",
            "SIDEBAR SCROLLVIEW documentView?.frame=\(scrollView.documentView?.frame ?? .zero)",
            "SIDEBAR SCROLLVIEW documentView?.bounds=\(scrollView.documentView?.bounds ?? .zero)",
            "SIDEBAR SCROLLVIEW hasHorizontalScroller=\(scrollView.hasHorizontalScroller)",
            "TABLEVIEW: frame=\(tableView.frame)",
            "TABLEVIEW bounds=\(tableView.bounds)",
            "DOCVIEW intrinsicContentSize=\(scrollView.documentView?.intrinsicContentSize ?? .zero)",
            "=== END SIDEBAR DEBUG ==="
        ]
        
        let logContent = lines.joined(separator: "\n") + "\n"
        try? logContent.write(toFile: logPath, atomically: true, encoding: .utf8)
        
        // Also print to console for immediate feedback
        lines.forEach { print($0) }
    }
    
    private func buildHeader() {
        let titleLabel = NSTextField(labelWithString: "Notes")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        
        newNoteButton = NSButton(title: "+ New Note", target: self, action: #selector(createNewNote))
        newNoteButton.bezelStyle = .rounded
        newNoteButton.setContentHuggingPriority(.required, for: .horizontal)
        newNoteButton.font = .systemFont(ofSize: 12)
        
        searchField = NSSearchField()
        searchField.placeholderString = "Search notes..."
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.setContentHuggingPriority(.init(1), for: .horizontal)
        searchField.setContentCompressionResistancePriority(.init(249), for: .horizontal)
        searchField.target = self
        searchField.action = #selector(searchFieldAction(_:))
        searchField.delegate = self
        
        let headerStack = NSStackView(views: [titleLabel, NSView(), searchField, newNoteButton])
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .centerY
        headerStack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)
        
        let headerDivider = NSView()
        headerDivider.wantsLayer = true
        headerDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerDivider)
        
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerStack.topAnchor.constraint(equalTo: view.topAnchor),
            
            headerDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerDivider.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            headerDivider.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
    
    private func buildTableView() {
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 64
        tableView.intercellSpacing = .zero
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = true
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickRow(_:))
        tableView.focusRingType = .none
        tableView.dataSource = self
        tableView.delegate = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
        column.width = 220
        tableView.addTableColumn(column)
        
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func buildEmptyState() {
        emptyLabel = NSTextField(labelWithString: "No notes yet")
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func refresh() {
        displayedNotes = store.search(searchQuery, includeArchived: false)
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
        emptyLabel.stringValue = searchQuery.isEmpty ? "No notes yet" : "No matching notes"
    }
    
    @objc private func createNewNote() {
        delegate?.sidebarDidCreateNewNote()
    }
    
    @objc private func searchFieldAction(_ sender: NSSearchField) {
        setSearchQuery(sender.stringValue)
    }
    
    @objc private func doubleClickRow(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0, row < displayedNotes.count else { return }
        delegate?.sidebarDidSelectNote(displayedNotes[row])
    }
    
    func selectNote(_ note: Note) {
        if let index = displayedNotes.firstIndex(where: { $0.id == note.id }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }
    }
    
    func getSelectedNotes() -> [Note] {
        return tableView.selectedRowIndexes.map { displayedNotes[$0] }
    }
    
    private func showActionMenu(for row: Int) {
        guard row >= 0, row < displayedNotes.count else { return }
        let note = displayedNotes[row]
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Rename", action: #selector(renameNote(_:)), keyEquivalent: "").representedObject = note
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Delete", action: #selector(deleteNote(_:)), keyEquivalent: "").representedObject = note
        
        let location = NSPoint(x: 0, y: 0)
        menu.popUp(positioning: nil, at: location, in: tableView)
    }
    
    @objc private func renameNote(_ sender: NSMenuItem) {
        guard let note = sender.representedObject as? Note else { return }
        startInlineRename(for: note)
    }
    
    @objc private func deleteNote(_ sender: NSMenuItem) {
        guard let note = sender.representedObject as? Note else { return }
        confirmDelete([note])
    }
    
    private func startInlineRename(for note: Note) {
        if let row = displayedNotes.firstIndex(where: { $0.id == note.id }) {
            tableView.editColumn(0, row: row, with: nil, select: true)
        }
    }
    
    private func confirmDelete(_ notes: [Note]) {
        let alert = NSAlert()
        if notes.count == 1 {
            alert.messageText = "Delete \"\(notes[0].displayTitle)\"?"
            alert.informativeText = "This note will be permanently deleted."
        } else {
            alert.messageText = "Delete \(notes.count) notes?"
            alert.informativeText = "These notes will be permanently deleted."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        alert.buttons[1].hasDestructiveAction = true
        
        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertSecondButtonReturn {
                    self?.delegate?.sidebarDidRequestDelete(notes)
                }
            }
        } else {
            if alert.runModal() == .alertSecondButtonReturn {
                delegate?.sidebarDidRequestDelete(notes)
            }
        }
    }
}

extension NotesSidebarViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedNotes.count
    }
}

extension NotesSidebarViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let note = displayedNotes[row]
        let identifier = NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NoteRowView
        if cell == nil {
            cell = NoteRowView()
            cell?.identifier = identifier
            cell?.onActionButtonClick = { [weak self] in
                self?.showActionMenu(for: row)
            }
        }
        cell?.configure(with: note, isSelected: tableView.selectedRowIndexes.contains(row), isHovered: row == self.hoveredRow)
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedNotes = tableView.selectedRowIndexes.map { displayedNotes[$0] }
        if selectedNotes.count == 1 {
            delegate?.sidebarDidSelectNote(selectedNotes[0])
        } else if selectedNotes.count > 1 {
            delegate?.sidebarDidSelectMultipleNotes(selectedNotes)
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }
    
    func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        false
    }
}

extension NotesSidebarViewController: NSSearchFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if searchField.stringValue.isEmpty {
                // Could close sidebar or clear search
            } else {
                searchField.stringValue = ""
                setSearchQuery("")
            }
            return true
        }
        return false
    }
}

private class NoteRowView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton()
    var onActionButtonClick: (() -> Void)?
    
    var isHovered: Bool = false {
        didSet { updateActionButtonVisibility() }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupViews() {
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
        
        actionButton.title = "..."
        actionButton.font = .systemFont(ofSize: 12, weight: .medium)
        actionButton.bezelStyle = .regularSquare
        actionButton.isBordered = true
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.target = self
        actionButton.action = #selector(actionButtonClicked)
        actionButton.isHidden = true
        
        let textStack = NSStackView(views: [titleLabel, previewLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.setContentHuggingPriority(.init(1), for: .horizontal)
        
        let topStack = NSStackView(views: [textStack])
        topStack.orientation = .horizontal
        topStack.spacing = 8
        topStack.alignment = .centerY
        
        let stack = NSStackView(views: [topStack, dateLabel, actionButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        // Ensure action button never gets pushed out
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        previewLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with note: Note, isSelected: Bool, isHovered: Bool) {
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
        
        if isSelected {
            backgroundStyle = .emphasized
            titleLabel.textColor = .selectedTextColor
            previewLabel.textColor = .selectedTextColor
            dateLabel.textColor = .selectedTextColor
        } else {
            backgroundStyle = .normal
            titleLabel.textColor = .labelColor
            previewLabel.textColor = .secondaryLabelColor
            dateLabel.textColor = .tertiaryLabelColor
        }
        
        self.isHovered = isHovered
    }
    
    private func updateActionButtonVisibility() {
        actionButton.isHidden = !isHovered
    }
    
    @objc private func actionButtonClicked() {
        onActionButtonClick?()
    }
}