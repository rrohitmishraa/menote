import AppKit
import MenoteCore

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class NotchPillView: NSView {
    var onActivate: (() -> Void)?

    override var isFlipped: Bool { true }

    private let fill = Theme.pillFill
    private var trackingArea: NSTrackingArea?

    override func layout() {
        super.layout()
        if trackingArea == nil || trackingArea?.rect != bounds {
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self)
            addTrackingArea(area)
            trackingArea = area
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius: CGFloat = 7
        let rect = bounds
        let path = NSBezierPath()
        path.appendRoundedRect(rect, xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()

        let dotDiameter: CGFloat = 4
        let dotRect = CGRect(
            x: (rect.width - dotDiameter) / 2,
            y: rect.height - 8,
            width: dotDiameter,
            height: dotDiameter)
        NSColor.white.withAlphaComponent(0.4).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
        animator().alphaValue = 0.85
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        animator().alphaValue = 1.0
    }

    override func mouseDown(with event: NSEvent) {
        onActivate?()
    }

    override func accessibilityLabel() -> String? {
        "Open Menote"
    }

    override func isAccessibilityElement() -> Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .button }

    override func accessibilityPerformPress() -> Bool {
        onActivate?()
        return true
    }
}
