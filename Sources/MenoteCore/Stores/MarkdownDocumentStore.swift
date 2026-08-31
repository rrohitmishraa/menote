import Foundation

/// Manages a single Markdown document as the persistent source of truth.
/// This replaces the multi-note architecture with a single-file model.
public final class MarkdownDocumentStore {
    private let queue = DispatchQueue(label: "app.menote.markdownstore", qos: .userInitiated)
    private let markdownPersistence: MarkdownPersistence
    private let fileLocationManager: FileLocationManager
    
    public private(set) var content: String = ""
    public private(set) var saveStatus: SaveStatus = .idle
    
    public var contentChanged: (() -> Void)?
    public var statusChanged: (() -> Void)?
    
    private var pendingAutosave: DispatchWorkItem?
    
    public init(markdownPersistence: MarkdownPersistence, fileLocationManager: FileLocationManager) {
        self.markdownPersistence = markdownPersistence
        self.fileLocationManager = fileLocationManager
    }
    
    // MARK: - File Access
    
    /// Returns the current Markdown file URL if one is configured.
    public var fileURL: URL? {
        try? fileLocationManager.getSavedFileLocation()
    }
    
    /// Checks if a Markdown file has been configured.
    public var hasConfiguredFile: Bool {
        fileURL != nil
    }
    
    // MARK: - Loading
    
    /// Loads content from the configured Markdown file.
    public func loadFromDisk() {
        guard let url = fileURL else {
            content = ""
            contentChanged?()
            return
        }
        
        queue.sync {
            do {
                let loadedContent = try markdownPersistence.loadContent(from: url)
                DispatchQueue.main.async { [weak self] in
                    self?.content = loadedContent
                    self?.saveStatus = .idle
                    self?.contentChanged?()
                    self?.statusChanged?()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.saveStatus = .failed("Could not read file: \(error.localizedDescription)")
                    self?.statusChanged?()
                }
            }
        }
    }
    
    // MARK: - Editing
    
    /// Updates the current content and schedules a save.
    public func updateContent(_ newContent: String) {
        content = newContent
        scheduleSave()
        contentChanged?()
    }
    
    // MARK: - Autosave
    
    private func scheduleSave() {
        pendingAutosave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushSync() }
        pendingAutosave = work
        queue.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
    
    /// Immediately saves content to disk.
    public func flushSync() {
        pendingAutosave?.cancel()
        pendingAutosave = nil
        
        guard let url = fileURL else {
            DispatchQueue.main.async { [weak self] in
                self?.setStatus(.failed("No file configured"))
            }
            return
        }
        
        let contentToSave = content
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async { [weak self] in
                self?.setStatus(.saving)
            }
            
            do {
                try self.markdownPersistence.saveContent(contentToSave, to: url)
                DispatchQueue.main.async { [weak self] in
                    self?.setStatus(.saved(Date()))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.setStatus(.failed(error.localizedDescription))
                }
            }
        }
    }
    
    private func setStatus(_ status: SaveStatus) {
        saveStatus = status
        statusChanged?()
    }
}
