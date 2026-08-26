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

    init() {
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

    func start() {
        hotkeyManager.onKeyDown = { [weak self] in
            self?.menuBarManager.togglePopover()
        }

        hotkeyManager.register(keyCode: 18, modifierMask: UInt32(cmdKey | shiftKey))

        applyAppearance(settings.appearance)

        guard connectedMarkdownFileIsAvailable() else {
            presentMarkdownFolderPicker()
            return
        }
        startNormalOperation()
    }

    private func startNormalOperation() {
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
    }

    private func connectedMarkdownFileIsAvailable() -> Bool {
        guard fileLocationManager.hasCompletedFirstLaunch else { return false }
        return fileLocationManager.verifySavedFileAccessible()
    }

    private func presentMarkdownFolderPicker() {
        // An accessory app has no normal activation UI. Temporarily become a
        // regular app so the system folder picker can be presented directly.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose a Folder for Menote"
        panel.message = "Menote will create or use Menote.md in this folder."
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard let self else { return }
            defer { NSApp.setActivationPolicy(.accessory) }

            guard response == .OK, let folderURL = panel.url else {
                return
            }

            let fileURL = folderURL.appendingPathComponent("Menote.md")
            do {
                // An existing document is always retained intact.
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    try self.markdownPersistence.createFile(at: fileURL)
                }
                _ = try self.markdownPersistence.loadContent(from: fileURL)
                try self.fileLocationManager.saveFileLocation(fileURL)
                self.fileLocationManager.markFirstLaunchCompleted()
                self.startNormalOperation()
            } catch {
                self.presentMarkdownFolderPickerError(error)
            }
        }
    }

    private func presentMarkdownFolderPickerError(_ error: Error) {
        NSApp.setActivationPolicy(.regular)
        let alert = NSAlert(error: error)
        alert.addButton(withTitle: "Choose Another Folder")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            presentMarkdownFolderPicker()
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
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
