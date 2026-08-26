import Foundation

public enum SaveStatus: Equatable {
    case idle
    case saving
    case saved(Date)
    case failed(String)
}

public final class NoteStore {
    private let queue = DispatchQueue(label: "app.notchpad.store", qos: .userInitiated)
    private let persistence: JSONPersistence
    private let storageManager: StorageManager
    private let markdownPersistence: MarkdownPersistence?
    private let fileLocationManager: FileLocationManager?

    public private(set) var notes: [Note] = []
    public private(set) var currentNoteID: UUID?
    public private(set) var loadHadError: Bool = false
    public private(set) var saveStatus: SaveStatus = .idle

    /// Draft text used when no note has been materialized yet (instant capture).
    public var draftText: String = ""

    public var notesChanged: (() -> Void)?
    public var statusChanged: (() -> Void)?
    public var currentNoteChanged: (() -> Void)?

    private var pendingAutosave: DispatchWorkItem?

    public init(
        persistence: JSONPersistence,
        storageManager: StorageManager,
        markdownPersistence: MarkdownPersistence? = nil,
        fileLocationManager: FileLocationManager? = nil
    ) {
        self.persistence = persistence
        self.storageManager = storageManager
        self.markdownPersistence = markdownPersistence
        self.fileLocationManager = fileLocationManager
    }
    
    public var isStorageAvailable: Bool {
        storageManager.checkAvailability() == .available
    }

    // MARK: - Loading

    public func loadFromDisk() {
        if let markdownPersistence, let fileURL = (try? fileLocationManager?.getSavedFileLocation()) ?? nil {
            loadFromMarkdown(markdownPersistence, fileURL: fileURL)
            return
        }

        var loadedNotes: [Note] = []
        var hadError = false
        queue.sync {
            do {
                let result = try persistence.loadNotes()
                loadedNotes = result.notes
                hadError = result.hadError
            } catch {
                hadError = true
            }
        }
        loadHadError = hadError
        notes = sortForDisplay(loadedNotes)
        if hadError {
            saveStatus = .failed("Could not read notes.json — data NOT overwritten.")
        } else {
            saveStatus = .idle
        }
        notesChanged?()
        statusChanged?()
    }

    private func loadFromMarkdown(_ markdownPersistence: MarkdownPersistence, fileURL: URL) {
        do {
            let note = try markdownPersistence.loadNote(from: fileURL)
            notes = note.map { [$0] } ?? []
            currentNoteID = note?.id
            draftText = ""
            loadHadError = false
            saveStatus = .idle
        } catch {
            // Never replace an unreadable document with an empty one.
            loadHadError = true
            saveStatus = .failed("Could not read Menote.md — data NOT overwritten.")
        }
        notesChanged?()
        currentNoteChanged?()
        statusChanged?()
    }

    public func reloadAfterStorageChange() {
        pendingAutosave?.cancel()
        pendingAutosave = nil
        flushSync()
        loadFromDisk()
    }

    // MARK: - Ordering / queries

    private func sortForDisplay(_ input: [Note]) -> [Note] {
        input.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.modifiedAt > b.modifiedAt
        }
    }

    public var activeNotes: [Note] {
        notes.filter { !$0.isArchived }
    }

    public var archivedNotes: [Note] {
        notes.filter(\.isArchived)
    }

    public func search(_ query: String, includeArchived: Bool = false) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = includeArchived ? notes : activeNotes
        guard !trimmed.isEmpty else { return pool }
        let needle = trimmed.lowercased()
        return pool.filter { $0.searchText.contains(needle) }
    }

    public func note(withID id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    public var currentNote: Note? {
        guard let id = currentNoteID else { return nil }
        return note(withID: id)
    }

    public func selectNote(_ id: UUID) {
        currentNoteID = id
        draftText = ""
        currentNoteChanged?()
        notesChanged?()
    }

    // MARK: - Capture & editing

    @discardableResult
    public func beginDraft() -> UUID? {
        currentNoteID = nil
        draftText = ""
        currentNoteChanged?()
        notesChanged?()
        return nil
    }

    @discardableResult
    public func createNote(text: String = "", richText: Data? = nil, selectIt: Bool = true) -> Note {
        var note = Note(blocks: text.isEmpty ? [] : [.text(text)])
        note.richText = richText
        if !text.isEmpty {
            note.title = deriveTitle(from: text)
        }
        notes.insert(note, at: 0)
        notes = sortForDisplay(notes)
        if selectIt {
            currentNoteID = note.id
            draftText = ""
        }
        scheduleSave()
        notesChanged?()
        if selectIt { currentNoteChanged?() }
        return note
    }

    private func deriveTitle(from text: String) -> String {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard firstLine.count > 60 else { return firstLine }
        return String(firstLine.prefix(60)) + "…"
    }

    public func updateText(for id: UUID?, text: String) {
        if let id, note(withID: id) != nil {
            updateNote(id) { $0.plainText = text }
        } else {
            draftText = text
            if !text.isEmpty {
                createNote(text: text)
            }
        }
    }

    public func updateNote(_ id: UUID, _ mutate: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        mutate(&notes[index])
        notes[index].modifiedAt = Date()
        notes = sortForDisplay(notes)
        scheduleSave()
        notesChanged?()
    }

    public func updateCurrentText(_ text: String, richText: Data? = nil) {
        if let id = currentNoteID, note(withID: id) != nil {
            updateNote(id) { note in
                note.plainText = text
                note.richText = richText
            }
        } else {
            draftText = text
            if !text.isEmpty {
                createNote(text: text, richText: richText)
            }
        }
    }

    public func setTitle(_ title: String, for id: UUID) {
        updateNote(id) { $0.title = title }
    }

    public func togglePin(_ id: UUID) {
        updateNote(id) { $0.isPinned.toggle() }
    }

    public func toggleArchive(_ id: UUID) {
        updateNote(id) { $0.isArchived.toggle() }
    }

    public func deleteNote(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes.remove(at: index)
        if currentNoteID == id {
            currentNoteID = nil
            draftText = ""
            currentNoteChanged?()
        }
        scheduleSave()
        notesChanged?()
    }

    // MARK: - Autosave

    public func scheduleSave() {
        pendingAutosave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushSync() }
        pendingAutosave = work
        queue.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    public func flushSync() {
        pendingAutosave?.cancel()
        pendingAutosave = nil

        guard !loadHadError else { return }

        if let markdownPersistence,
           let fileURL = (try? fileLocationManager?.getSavedFileLocation()) ?? nil {
            setStatus(.saving)
            do {
                try markdownPersistence.saveNote(currentNote, draftText: draftText, to: fileURL)
                setStatus(.saved(Date()))
            } catch {
                setStatus(.failed(error.localizedDescription))
            }
            return
        }

        switch storageManager.checkAvailability() {
        case .available:
            setStatus(.saving)
            do {
                try persistence.saveNotes(notes)
                setStatus(.saved(Date()))
            } catch {
                setStatus(.failed(error.localizedDescription))
            }
        case .unavailable(let reason):
            setStatus(.failed(reason))
        }
    }

    private func setStatus(_ status: SaveStatus) {
        saveStatus = status
        statusChanged?()
    }
}
