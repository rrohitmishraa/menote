import Foundation

public struct ChecklistItem: Codable, Equatable, Hashable {
    public var text: String
    public var isChecked: Bool

    public init(text: String, isChecked: Bool = false) {
        self.text = text
        self.isChecked = isChecked
    }
}

public enum ContentBlock: Equatable {
    case text(String)
    case heading(String)
    case code(String)
    case divider
    case checklist([ChecklistItem])
    case image(imageID: String, caption: String?)
    case link(url: String, title: String?)
}

extension ContentBlock: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case content
        case items
        case imageID
        case caption
        case url
        case title
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decodeIfPresent(String.self, forKey: .content) ?? "")
        case "heading":
            self = .heading(try container.decodeIfPresent(String.self, forKey: .content) ?? "")
        case "code":
            self = .code(try container.decodeIfPresent(String.self, forKey: .content) ?? "")
        case "divider":
            self = .divider
        case "checklist":
            self = .checklist(try container.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? [])
        case "image":
            let id = try container.decode(String.self, forKey: .imageID)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(imageID: id, caption: caption)
        case "link":
            let url = try container.decode(String.self, forKey: .url)
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            self = .link(url: url, title: title)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown content block type '\(type)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let string):
            try container.encode("text", forKey: .type)
            try container.encode(string, forKey: .content)
        case .heading(let string):
            try container.encode("heading", forKey: .type)
            try container.encode(string, forKey: .content)
        case .code(let string):
            try container.encode("code", forKey: .type)
            try container.encode(string, forKey: .content)
        case .divider:
            try container.encode("divider", forKey: .type)
        case .checklist(let items):
            try container.encode("checklist", forKey: .type)
            try container.encode(items, forKey: .items)
        case .image(let imageID, let caption):
            try container.encode("image", forKey: .type)
            try container.encode(imageID, forKey: .imageID)
            try container.encodeIfPresent(caption, forKey: .caption)
        case .link(let url, let title):
            try container.encode("link", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(title, forKey: .title)
        }
    }
}

extension ContentBlock {
    public var searchableText: String {
        switch self {
        case .text(let s): return s
        case .heading(let s): return s
        case .code(let s): return s
        case .divider: return ""
        case .checklist(let items): return items.map(\.text).joined(separator: "\n")
        case .image(_, let caption): return caption ?? ""
        case .link(let url, let title): return [title, url].compactMap { $0 }.joined(separator: " ")
        }
    }
}
