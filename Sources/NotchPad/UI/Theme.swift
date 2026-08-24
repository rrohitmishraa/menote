import AppKit
import NotchPadCore

enum Theme {
    static var panelBackground: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
                : NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        }
    }

    static var pillFill: NSColor {
        NSColor(srgbRed: 0.05, green: 0.05, blue: 0.06, alpha: 1)
    }

    static var editorFont: NSFont { .systemFont(ofSize: 18) }
    static var codeFont: NSFont { .monospacedSystemFont(ofSize: 13, weight: .regular) }

    static func formatSavedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

final class StatusDotView: NSView {
    var color: NSColor = .systemGreen {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let diameter = min(bounds.width, bounds.height) - 2
        let rect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
    }
}
