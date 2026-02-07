import Foundation

struct CacheItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let category: CacheCategory
    let lastModified: Date?
    let isSelected: Bool

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    init(url: URL, name: String, size: Int64, category: CacheCategory, lastModified: Date? = nil, isSelected: Bool = true) {
        self.url = url
        self.name = name
        self.size = size
        self.category = category
        self.lastModified = lastModified
        self.isSelected = isSelected
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CacheItem, rhs: CacheItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum CacheCategory: String, CaseIterable, Identifiable {
    case systemCache = "System Caches"
    case userCache = "User Caches"
    case browserCache = "Browser Data"
    case applicationCache = "App Caches"
    case logs = "Logs"
    case downloads = "Downloads"
    case trash = "Trash"
    case mailAttachments = "Mail Attachments"
    case xcodeData = "Xcode Data"
    case dockerData = "Docker Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCache: return "gearshape.2"
        case .userCache: return "person"
        case .browserCache: return "globe"
        case .applicationCache: return "app.badge"
        case .logs: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .mailAttachments: return "envelope"
        case .xcodeData: return "hammer"
        case .dockerData: return "shippingbox"
        }
    }

    var color: String {
        switch self {
        case .systemCache: return "blue"
        case .userCache: return "purple"
        case .browserCache: return "orange"
        case .applicationCache: return "green"
        case .logs: return "gray"
        case .downloads: return "cyan"
        case .trash: return "red"
        case .mailAttachments: return "indigo"
        case .xcodeData: return "teal"
        case .dockerData: return "mint"
        }
    }
}

struct CacheCategoryResult: Identifiable {
    let id = UUID()
    let category: CacheCategory
    var items: [CacheItem]
    var isExpanded: Bool = false

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var formattedSize: String {
        ByteFormatter.format(totalSize)
    }
}
