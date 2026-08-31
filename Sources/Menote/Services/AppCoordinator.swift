import AppKit
import MenoteCore
import Carbon.HIToolbox

final class AppCoordinator: MenuBarManagerDelegate {
    let settings = AppSettings.shared
    let storageManager: StorageManager
    let noteStore: NoteStore
    let persistence: JSONPersistence
    let markdownPersistence = MarkdownPersistence()
    let fileLocationManager = FileLocationManager()
    let hotkeyManager = HotkeyManager()
    let menuBarManager = MenuBarManager()

    var scratchpadVC: ScratchpadViewController?

    private var hasWarnedStorage = false

    private var menoteURL: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportDir.appendingPathComponent("Menote").appendingPathComponent("Menote.menote")
    }

    deinit { Logger.shared.log("AppCoordinator deinit") }

    init() {
        Logger.shared.log("AppCoordinator init")
        storageManager = StorageManager(settings: settings)
        let layout = storageManager.layout
        persistence = JSONPersistence(layout: layout)
        noteStore = NoteStore(
            persistence: persistence,
            storageManager: storageManager,
            markdownPersistence: markdownPersistence,
            fileLocationManager: fileLocationManager
        )

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: AppSettings.didChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(availabilityChanged), name: StorageManager.availabilityDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(volumeUnmounted),
            name: NSWorkspace.didUnmountNotification, object: nil)
    }

    @objc private func settingsChanged(_ notification: Notification) {
        applyAppearance(settings.appearance)
    }

    func start() {
        Logger.shared.log("AppCoordinator.start()")
        hotkeyManager.onKeyDown = { [weak self] in
            self?.menuBarManager.togglePopover()
        }

        hotkeyManager.register(keyCode: 18, modifierMask: UInt32(cmdKey | shiftKey))

        applyAppearance(settings.appearance)

        AboutWindowController.shared.configure(store: noteStore)

        Logger.shared.log("[DEBUG] Resolved default file URL: \(menoteURL.path)")

        guard connectedMarkdownFileIsAvailable() else {
            presentDefaultMenote()
            return
        }

        ensureActiveFileLocationIsSaved()
        Logger.shared.log("[DEBUG] Active file URL after startup: \(noteStore.activeFileURL?.path ?? "nil")")
        startNormalOperation()
    }

    @objc private func availabilityChanged(_ notification: Notification) {
        let avail = storageManager.checkAvailability()
        switch avail {
        case .unavailable where !hasWarnedStorage:
            showStorageUnavailableAlert(reason: avail)
            hasWarnedStorage = true
        case .available:
            hasWarnedStorage = false
            noteStore.scheduleSave()
        case .unavailable:
            break
        }
    }

    @objc private func volumeUnmounted(_ notification: Notification) {
        _ = storageManager.checkAvailability()
    }


    private func startNormalOperation() {
        Logger.shared.log("startNormalOperation BEGIN")
        NSApp.setActivationPolicy(.accessory)
        let vc = makeScratchpadVC()
        scratchpadVC = vc
        menuBarManager.delegate = self
        menuBarManager.setup(with: vc)

        let avail = storageManager.checkAvailability()
        if case .unavailable = avail {
            showStorageUnavailableAlert(reason: avail)
        }

        noteStore.loadFromDisk()
        if noteStore.currentNoteID == nil, let firstNote = noteStore.notes.first {
            noteStore.selectNote(firstNote.id)
        }
        Logger.shared.log("startNormalOperation END")
    }

    private func connectedMarkdownFileIsAvailable() -> Bool {
        let menoteURL = menoteURL
        guard FileManager.default.fileExists(atPath: menoteURL.path) else { return false }
        return FileManager.default.isReadableFile(atPath: menoteURL.path)
    }

    private func ensureActiveFileLocationIsSaved() {
        let defaultURL = menoteURL
        let existingURL = try? fileLocationManager.getSavedFileLocation()
        if existingURL == nil {
            try? fileLocationManager.saveFileLocation(defaultURL)
            Logger.shared.log("[DEBUG] Saved default file URL to active state: \(defaultURL.path)")
        } else {
            Logger.shared.log("[DEBUG] Active file URL already set: \(existingURL?.path ?? "nil")")
        }
    }

    private func presentDefaultMenote() {
        Logger.shared.log("presentDefaultMenote BEGIN")

        let menoteURL = menoteURL
        let menoteDir = menoteURL.deletingLastPathComponent()
        let mdURL = menoteURL.deletingLastPathComponent().appendingPathComponent("Menote.md")

        if !FileManager.default.fileExists(atPath: menoteDir.path) {
            try? FileManager.default.createDirectory(at: menoteDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Migration: if Menote.md exists but Menote.menote doesn't, migrate content
        let needsMigration = FileManager.default.fileExists(atPath: mdURL.path) &&
            !FileManager.default.fileExists(atPath: menoteURL.path)

        do {
            if needsMigration {
                // Copy content from Menote.md to Menote.menote
                let mdContent = try String(contentsOf: mdURL, encoding: .utf8)
                try "\(mdContent)\n".write(to: menoteURL, atomically: true, encoding: .utf8)
                // Note: we keep the original Menote.md per fix.txt instructions
            }

            if !FileManager.default.fileExists(atPath: menoteURL.path) {
                try markdownPersistence.createFile(at: menoteURL)
            }
            _ = try markdownPersistence.loadContent(from: menoteURL)
            try fileLocationManager.saveFileLocation(menoteURL)
            fileLocationManager.markFirstLaunchCompleted()
            Logger.shared.log("[DEBUG] Saved default file URL in presentDefaultMenote: \(menoteURL.path)")
            startNormalOperation()
        } catch {
            // Handle error gracefully - don't crash
            Logger.shared.log("Error presenting default Menote: \(error.localizedDescription)")
        }

        Logger.shared.log("presentDefaultMenote END")
    }

    // MARK: - App lifecycle

    func applicationWillTerminate() {
        noteStore.flushSync()
    }

    // MARK: - Settings & storage

    private func showStorageUnavailableAlert(reason: StorageAvailability) {
        guard case .unavailable(let reason) = reason else { return }
        StorageUnavailableAlert.present(reason: reason,
            onReconnect: { [weak self] in _ = self?.storageManager.checkAvailability() },
            onContinue: { [weak self] in self?.hasWarnedStorage = false })
    }

    // MARK: - Actions

    private func makeScratchpadVC() -> ScratchpadViewController {
        ScratchpadViewController(
            store: noteStore,
            actions: ScratchpadActionsImpl(coordinator: self))
    }

    func newNote() {
        scratchpadVC?.newNote()
    }

    func openPreferences() {
        // No preferences in Phase 1
    }

    func openStorageFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([storageManager.baseURL])
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Appearance

    private func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - MenuBarManagerDelegate

    func menuBarDidRequestOpenPopover() {}
    func menuBarDidRequestNewNote() { newNote() }
    func menuBarDidRequestSearch() { /* no-op in Phase 1 */ }
    func menuBarDidRequestPreferences() { /* no-op in Phase 1 */ }
    func menuBarDidRequestQuit() { quitApp() }

    func storeMetadata() -> StoreMetadata {
        persistence.loadMetadata()
    }
}

// MARK: - ScratchpadActionsImpl

private final class ScratchpadActionsImpl: ScratchpadActions {
    weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) { self.coordinator = coordinator }

    func openPreferences() { coordinator?.openPreferences() }
    func quitApp() { coordinator?.quitApp() }
}
