import Foundation
import SwiftUI

struct DiskItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    var children: [DiskItem]?
    let depth: Int

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    var color: Color {
        if isDirectory {
            return colorForDirectory(name)
        } else {
            return colorForExtension(url.pathExtension)
        }
    }

    var icon: String {
        if isDirectory {
            return "folder.fill"
        } else {
            return iconForExtension(url.pathExtension)
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiskItem, rhs: DiskItem) -> Bool {
        lhs.id == rhs.id
    }

    private func colorForDirectory(_ name: String) -> Color {
        switch name.lowercased() {
        case "applications": return .blue
        case "library": return .purple
        case "documents": return .green
        case "downloads": return .orange
        case "desktop": return .cyan
        case "movies": return .red
        case "music": return .pink
        case "pictures": return .yellow
        default: return .gray
        }
    }

    private func colorForExtension(_ ext: String) -> Color {
        switch ext.lowercased() {
        case "app": return .blue
        case "dmg", "pkg", "zip", "tar", "gz": return .orange
        case "mp4", "mov", "avi", "mkv": return .red
        case "mp3", "wav", "aac", "flac": return .pink
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .yellow
        case "pdf": return .red
        case "doc", "docx", "txt", "rtf": return .blue
        case "xls", "xlsx", "csv": return .green
        case "ppt", "pptx", "key": return .orange
        case "swift", "js", "ts", "py", "rb", "go", "rs": return .purple
        default: return .gray
        }
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "app": return "app"
        case "dmg": return "opticaldiscdrive"
        case "pkg": return "shippingbox"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "pdf": return "doc.text"
        case "swift": return "swift"
        case "js", "ts": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}

struct DiskUsageInfo {
    let totalSpace: Int64
    let freeSpace: Int64
    let usedSpace: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace) * 100
    }

    var formattedTotal: String { ByteFormatter.format(totalSpace) }
    var formattedFree: String { ByteFormatter.format(freeSpace) }
    var formattedUsed: String { ByteFormatter.format(usedSpace) }
}
