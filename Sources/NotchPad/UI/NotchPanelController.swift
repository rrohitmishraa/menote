import AppKit
import NotchPadCore

protocol NotchPanelControllerDelegate: AnyObject {
    func notchPanelWillExpand(_ controller: NotchPanelController)
    func notchPanelDidCollapse(_ controller: NotchPanelController)
}

final class NotchPanelController {
    weak var delegate: NotchPanelControllerDelegate?

    private(set) var isExpanded = false
    private var isAnimating = false

    let pillPanel: KeyablePanel
    private let pillView: NotchPillView

    let scratchpadPanel: KeyablePanel
    private let scratchpadController: ScratchpadViewController
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?

    static let bodyWidth: CGFloat = 480
    static let bodyHeight: CGFloat = 420
    static let pillWidth: CGFloat = 150
    static let pillHeight: CGFloat = 16

    init(scratchpadController: ScratchpadViewController) {
        self.scratchpadController = scratchpadController

        pillView = NotchPillView(frame: NSRect(x: 0, y: 0, width: Self.pillWidth, height: Self.pillHeight))
        pillView.wantsLayer = true

        pillPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.pillWidth, height: Self.pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        pillPanel.isOpaque = false
        pillPanel.backgroundColor = .clear
        pillPanel.hasShadow = false
        pillPanel.level = .statusBar
        pillPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        pillPanel.isReleasedWhenClosed = false
        pillPanel.hidesOnDeactivate = false
        pillPanel.contentView = pillView
        pillPanel.setAccessibilityIdentifier("notch-pill")

        let content = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: Self.bodyWidth, height: Self.bodyHeight))
        content.material = .popover
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 12
        content.layer?.masksToBounds = true
        content.layer?.cornerCurve = .continuous

        scratchpadPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.bodyWidth, height: Self.bodyHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        scratchpadPanel.isOpaque = false
        scratchpadPanel.backgroundColor = .clear
        scratchpadPanel.hasShadow = true
        scratchpadPanel.level = .floating
        scratchpadPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        scratchpadPanel.isReleasedWhenClosed = false
        scratchpadPanel.hidesOnDeactivate = false
        scratchpadPanel.contentView = content
        scratchpadPanel.setAccessibilityIdentifier("scratchpad-panel")

        scratchpadController.view.frame = content.bounds
        scratchpadController.view.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        content.addSubview(scratchpadController.view)

        pillView.onActivate = { [weak self] in
            self?.expand()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        NotificationCenter.default.addObserver(
            forName: NSPanel.didResignKeyNotification, object: scratchpadPanel, queue: .main
        ) { [weak self] _ in
            guard let self, self.isExpanded, !self.isAnimating else { return }
            self.collapse()
        }

        installMonitors()
        repositionPill()
    }

    private func installMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.scratchpadPanel.isKeyWindow else { return event }
            if event.keyCode == 53 {
                self.collapse()
                return nil
            }
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, self.isExpanded else { return }
            let locationInWindow = event.locationInWindow
            if !self.scratchpadPanel.frame.contains(locationInWindow),
               !self.pillPanel.frame.contains(locationInWindow) {
                self.collapse()
            }
        }
    }

    private var targetScreen: NSScreen? {
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main
    }

    @objc private func screenConfigurationChanged() {
        repositionPill()
    }

    private func repositionPill() {
        guard let screen = targetScreen else { return }
        let frame = Self.pillFrame(for: screen)
        pillPanel.setFrame(frame, display: true)
    }

    static func pillFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - pillWidth - 8
        let y = screenFrame.maxY - pillHeight - 4
        return NSRect(x: x, y: y, width: pillWidth, height: pillHeight)
    }

    static func expandedFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - bodyWidth - 8
        let y = screenFrame.maxY - 28 - bodyHeight
        return NSRect(x: x, y: y, width: bodyWidth, height: bodyHeight)
    }

    // MARK: - Expand / collapse

    func expand() {
        guard !isExpanded else { return }
        delegate?.notchPanelWillExpand(self)
        isExpanded = true
        isAnimating = true
        pillPanel.orderOut(nil)

        guard let screen = targetScreen else { return }
        let start = Self.pillFrame(for: screen)
        let target = Self.expandedFrame(for: screen)

        scratchpadPanel.setFrame(start, display: false)
        scratchpadPanel.makeKeyAndOrderFront(nil)
        activateApp()

        scratchpadPanel.invalidateShadow()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1)
            context.allowsImplicitAnimation = true
            self.scratchpadPanel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimating = false
            self.scratchpadController.applyFocus(.editor)
        })
    }

    func collapse() {
        guard isExpanded else { return }
        isAnimating = true
        scratchpadPanel.orderOut(nil)
        activateApp()

        guard let screen = targetScreen else {
            isExpanded = false
            isAnimating = false
            pillPanel.makeKeyAndOrderFront(nil)
            delegate?.notchPanelDidCollapse(self)
            return
        }
        let start = scratchpadPanel.frame
        let target = Self.pillFrame(for: screen)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1)
            context.allowsImplicitAnimation = true
            self.scratchpadPanel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isExpanded = false
            self.isAnimating = false
            self.pillPanel.makeKeyAndOrderFront(nil)
            self.delegate?.notchPanelDidCollapse(self)
        })
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}