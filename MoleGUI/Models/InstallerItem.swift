import Foundation

struct InstallerItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let fileName: String
    let size: Int64
    let source: InstallerSource
    let fileType: InstallerFileType
    var isSelected: Bool

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstallerItem, rhs: InstallerItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum InstallerSource: String, CaseIterable {
    case downloads = "Downloads"
    case desktop = "Desktop"
    case documents = "Documents"
    case publicFolder = "Public"
    case libraryDownloads = "Library Downloads"
    case shared = "Shared"
    case homebrew = "Homebrew"
    case iCloud = "iCloud"
    case mail = "Mail"
    case telegram = "Telegram"

    var icon: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .desktop: return "desktopcomputer"
        case .documents: return "doc"
        case .publicFolder: return "folder"
        case .libraryDownloads: return "tray.and.arrow.down"
        case .shared: return "person.2"
        case .homebrew: return "mug"
        case .iCloud: return "icloud"
        case .mail: return "envelope"
        case .telegram: return "paperplane"
        }
    }

    var color: String {
        switch self {
        case .downloads: return "blue"
        case .desktop: return "purple"
        case .documents: return "orange"
        case .publicFolder: return "green"
        case .libraryDownloads: return "teal"
        case .shared: return "indigo"
        case .homebrew: return "brown"
        case .iCloud: return "cyan"
        case .mail: return "red"
        case .telegram: return "blue"
        }
    }
}

enum InstallerFileType: String, CaseIterable {
    case dmg = ".dmg"
    case pkg = ".pkg"
    case mpkg = ".mpkg"
    case iso = ".iso"
    case xip = ".xip"
    case zip = ".zip"

    var icon: String {
        switch self {
        case .dmg: return "externaldrive"
        case .pkg: return "shippingbox"
        case .mpkg: return "shippingbox.fill"
        case .iso: return "opticaldisc"
        case .xip: return "doc.zipper"
        case .zip: return "doc.zipper"
        }
    }

    static var installerExtensions: Set<String> {
        Set(allCases.map { String($0.rawValue.dropFirst()) })
    }

    static var nonZipExtensions: Set<String> {
        Set(allCases.filter { $0 != .zip }.map { String($0.rawValue.dropFirst()) })
    }
}
