import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let version: String?
    let size: Int64
    let icon: NSImage?
    let lastUsed: Date?
    var isBrewCask: Bool = false
    var brewCaskName: String? = nil

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    /// Relative date string like "Today", "3 days ago", "2 weeks ago"
    var lastUsedRelative: String {
        guard let date = lastUsed else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var remnants: [AppRemnant] = []

    var totalRemnantSize: Int64 {
        remnants.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        size + totalRemnantSize
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

struct AppRemnant: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let type: RemnantType
    let size: Int64

    var name: String {
        url.lastPathComponent
    }

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppRemnant, rhs: AppRemnant) -> Bool {
        lhs.id == rhs.id
    }
}

enum RemnantType: String, CaseIterable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case logs = "Logs"
    case launchAgents = "Launch Agents"
    case launchDaemons = "Launch Daemons"
    case containers = "Containers"
    case savedState = "Saved State"
    case other = "Other"

    var icon: String {
        switch self {
        case .applicationSupport: return "folder"
        case .caches: return "internaldrive"
        case .preferences: return "slider.horizontal.3"
        case .logs: return "doc.text"
        case .launchAgents: return "play.circle"
        case .launchDaemons: return "gearshape.2"
        case .containers: return "shippingbox"
        case .savedState: return "clock.arrow.circlepath"
        case .other: return "questionmark.folder"
        }
    }
}
