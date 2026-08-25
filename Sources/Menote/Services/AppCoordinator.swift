import AppKit
import MenoteCore
import Carbon.HIToolbox

final class AppCoordinator: MenuBarManagerDelegate {
    let settings = AppSettings.shared
    let storageManager: StorageManager
    let noteStore: NoteStore
    let persistence: JSONPersistence
    let hotkeyManager = HotkeyManager()
    let menuBarManager = MenuBarManager()

    var scratchpadVC: ScratchpadViewController?

    private var hasWarnedStorage = false

    init() {
        storageManager = StorageManager(settings: settings)
        let layout = storageManager.layout
        persistence = JSONPersistence(layout: layout)
        noteStore = NoteStore(persistence: persistence, storageManager: storageManager)

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

        let vc = makeScratchpadVC()
        scratchpadVC = vc

        menuBarManager.delegate = self
        menuBarManager.setup(with: vc)

        let avail = storageManager.checkAvailability()
        switch avail {
        case .unavailable:
            showStorageUnavailableAlert(reason: avail)
        case .available:
            break
        }

        noteStore.loadFromDisk()

        if noteStore.currentNoteID == nil, let firstNote = noteStore.notes.first {
            noteStore.selectNote(firstNote.id)
        }

        applyAppearance(settings.appearance)
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