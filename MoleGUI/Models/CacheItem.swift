import Foundation

enum RiskLevel: String, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "red"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

struct CacheItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let category: CacheCategory
    let lastModified: Date?
    let isSelected: Bool
    let displayName: String?
    let subtitle: String?
    let requiresAdmin: Bool
    let riskLevel: RiskLevel

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    init(url: URL, name: String, size: Int64, category: CacheCategory, lastModified: Date? = nil, isSelected: Bool = true, displayName: String? = nil, subtitle: String? = nil, requiresAdmin: Bool = false, riskLevel: RiskLevel? = nil) {
        self.url = url
        self.name = name
        self.size = size
        self.category = category
        self.lastModified = lastModified
        self.isSelected = isSelected
        self.displayName = displayName
        self.subtitle = subtitle
        self.requiresAdmin = requiresAdmin
        self.riskLevel = riskLevel ?? category.riskLevel
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
    case codeEditorCache = "Code Editor Caches"
    case devToolCache = "Developer Tools"
    case shellCache = "Shell Data"
    case logs = "Logs"
    case downloads = "Downloads"
    case trash = "Trash"
    case mailAttachments = "Mail Attachments"
    case xcodeData = "Xcode Data"
    case dockerData = "Docker Data"
    case androidData = "Android Data"
    case homebrewCache = "Homebrew"
    case systemLevel = "System Maintenance"
    case orphanedData = "Orphaned App Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCache: return "gearshape.2"
        case .userCache: return "person"
        case .browserCache: return "globe"
        case .applicationCache: return "app.badge"
        case .codeEditorCache: return "chevron.left.forwardslash.chevron.right"
        case .devToolCache: return "wrench.and.screwdriver"
        case .shellCache: return "terminal"
        case .logs: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .mailAttachments: return "envelope"
        case .xcodeData: return "hammer"
        case .dockerData: return "shippingbox"
        case .androidData: return "cpu"
        case .homebrewCache: return "mug"
        case .systemLevel: return "wrench"
        case .orphanedData: return "questionmark.folder"
        }
    }

    var color: String {
        switch self {
        case .systemCache: return "blue"
        case .userCache: return "purple"
        case .browserCache: return "orange"
        case .applicationCache: return "green"
        case .codeEditorCache: return "indigo"
        case .devToolCache: return "brown"
        case .shellCache: return "gray"
        case .logs: return "gray"
        case .downloads: return "cyan"
        case .trash: return "red"
        case .mailAttachments: return "indigo"
        case .xcodeData: return "teal"
        case .dockerData: return "mint"
        case .androidData: return "green"
        case .homebrewCache: return "orange"
        case .systemLevel: return "red"
        case .orphanedData: return "yellow"
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .userCache, .browserCache, .applicationCache, .codeEditorCache,
             .shellCache, .logs, .trash, .homebrewCache, .devToolCache:
            return .low
        case .downloads, .mailAttachments, .xcodeData, .dockerData,
             .androidData, .orphanedData:
            return .medium
        case .systemCache, .systemLevel:
            return .high
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
