import Foundation

enum CachePaths {
    static let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    static var userCaches: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches"),
                category: .userCache,
                description: "User application caches"
            )
        ]
    }

    static var systemCaches: [CacheLocation] {
        [
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Caches"),
                category: .systemCache,
                description: "System-wide caches"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/System/Library/Caches"),
                category: .systemCache,
                description: "macOS system caches"
            )
        ]
    }

    static var browserCaches: [CacheLocation] {
        [
            // Safari
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Safari"),
                category: .browserCache,
                description: "Safari browsing data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.Safari"),
                category: .browserCache,
                description: "Safari cache"
            ),
            // Chrome
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Google/Chrome"),
                category: .browserCache,
                description: "Chrome cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"),
                category: .browserCache,
                description: "Chrome browsing cache"
            ),
            // Firefox
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Firefox"),
                category: .browserCache,
                description: "Firefox cache"
            ),
            // Edge
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/Microsoft Edge"),
                category: .browserCache,
                description: "Edge cache"
            ),
            // Arc
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/company.thebrowser.Browser"),
                category: .browserCache,
                description: "Arc browser cache"
            )
        ]
    }

    static var logs: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Logs"),
                category: .logs,
                description: "User application logs"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/Library/Logs"),
                category: .logs,
                description: "System logs"
            ),
            CacheLocation(
                path: URL(fileURLWithPath: "/var/log"),
                category: .logs,
                description: "Unix system logs"
            )
        ]
    }

    static var applicationCaches: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Slack/Cache"),
                category: .applicationCache,
                description: "Slack cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/discord/Cache"),
                category: .applicationCache,
                description: "Discord cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Application Support/Spotify/PersistentCache"),
                category: .applicationCache,
                description: "Spotify cache"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Group Containers/group.com.apple.notes/Accounts"),
                category: .applicationCache,
                description: "Notes attachments cache"
            )
        ]
    }

    static var xcodeData: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                category: .xcodeData,
                description: "Xcode build data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives"),
                category: .xcodeData,
                description: "Xcode archives"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator/Devices"),
                category: .xcodeData,
                description: "iOS Simulator data"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
                category: .xcodeData,
                description: "Xcode caches"
            )
        ]
    }

    static var dockerData: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Containers/com.docker.docker/Data"),
                category: .dockerData,
                description: "Docker Desktop data"
            )
        ]
    }

    static var trash: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent(".Trash"),
                category: .trash,
                description: "User Trash"
            )
        ]
    }

    static var mailAttachments: [CacheLocation] {
        [
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Mail Downloads"),
                category: .mailAttachments,
                description: "Mail downloaded attachments"
            ),
            CacheLocation(
                path: homeDirectory.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
                category: .mailAttachments,
                description: "Mail app attachments"
            )
        ]
    }

    static var allLocations: [CacheLocation] {
        userCaches + browserCaches + logs + applicationCaches + xcodeData + dockerData + trash + mailAttachments
    }

    static var safeLocations: [CacheLocation] {
        // Locations that are generally safe to clean without breaking apps
        userCaches + browserCaches + logs + trash
    }
}

struct CacheLocation: Identifiable {
    let id = UUID()
    let path: URL
    let category: CacheCategory
    let description: String

    var exists: Bool {
        FileManager.default.fileExists(atPath: path.path)
    }
}
