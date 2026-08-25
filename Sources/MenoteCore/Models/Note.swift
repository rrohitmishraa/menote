import Foundation

public struct Note: Codable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var blocks: [ContentBlock]
    public var richText: Data?
    public var tags: [String]
    public var isPinned: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "",
        blocks: [ContentBlock] = [],
        richText: Data? = nil,
        tags: [String] = [],
        isPinned: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.blocks = blocks
        self.richText = richText
        self.tags = tags
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public var plainText: String {
        get {
            blocks.compactMap { block -> String? in
                switch block {
                case .text(let s): return s
                case .code(let s): return s
                default: return nil
                }
            }
            .joined(separator: "\n")
        }
        set {
            if newValue.isEmpty {
                blocks = blocks.filter {
                    if case .text(let s) = $0 { return false }
                    return true
                }
            } else {
                blocks = [.text(newValue)]
            richText = nil
            }
        }
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = plainText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if firstLine.isEmpty { return "Untitled" }
        return firstLine.count > 60 ? String(firstLine.prefix(60)) + "…" : firstLine
    }

    public var searchText: String {
        var parts: [String] = [title, plainText]
        parts.append(blocks.map(\.searchableText).joined(separator: "\n"))
        parts.append(tags.joined(separator: " "))
        return parts.joined(separator: "\n").lowercased()
    }
}
