import AppKit

struct ContextItem {
    let title: String
    let charIndex: Int
}

final class ContextNavigatorViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var contexts: [ContextItem] = []
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var emptyLabel: NSTextField!

    var onScrollToContext: ((Int) -> Void)?

    override func loadView() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 300))
        content.wantsLayer = true

        emptyLabel = NSTextField(wrappingLabelWithString: "No contexts yet\n\nYou can add one by starting a line with ###")
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyLabel)

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.style = .sourceList
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = .clear
        tableView.setAccessibilityIdentifier("context-table")

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),

            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        view = content
    }

    func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.contentViewController = self
        popover.contentSize = NSSize(width: 220, height: 300)
        popover.behavior = .transient
        popover.animates = true
        return popover
    }

    func updateContexts(from text: String) {
        contexts = Self.parseContexts(from: text)
        let hasContexts = !contexts.isEmpty
        emptyLabel.isHidden = hasContexts
        scrollView.isHidden = !hasContexts
        tableView.reloadData()
    }

    static func parseContexts(from text: String) -> [ContextItem] {
        var results: [ContextItem] = []
        var charOffset = 0
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("### ") {
                let title = String(line.dropFirst(4))
                results.append(ContextItem(title: title, charIndex: charOffset))
            }
            charOffset += line.utf16.count + 1
        }
        return results
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        contexts.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < contexts.count else { return nil }
        let id = NSUserInterfaceItemIdentifier("ContextCell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView
            ?? NSTableCellView()
        if cell.textField == nil {
            let tf = NSTextField(labelWithString: "")
            tf.font = .systemFont(ofSize: 13)
            tf.textColor = .labelColor
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.identifier = id
        cell.textField?.stringValue = contexts[row].title
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < contexts.count else { return }
        let charIndex = contexts[row].charIndex
        onScrollToContext?(charIndex)
        DispatchQueue.main.async { [weak self] in
            self?.tableView.deselectRow(row)
        }
    }

    func scrollToContext(at charIndex: Int, in textView: NSTextView) {
        let textLength = textView.string.utf16.count
        guard charIndex >= 0, charIndex <= textLength else { return }
        let anchorRange = NSRange(location: charIndex, length: charIndex < textLength ? 1 : 0)
        textView.setSelectedRange(NSRange(location: charIndex, length: 0))
        textView.scrollRangeToVisible(NSRange(location: charIndex, length: 0))

        guard let layoutManager = textView.layoutManager else { return }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: anchorRange, actualCharacterRange: nil)
        guard glyphRange.location < layoutManager.numberOfGlyphs else { return }
        let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let inset = textView.textContainerInset.height
        let targetY = lineFragmentRect.origin.y + inset - 60

        textView.enclosingScrollView?.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: max(0, targetY)))
        textView.setSelectedRange(NSRange(location: charIndex, length: 0))
    }
}
