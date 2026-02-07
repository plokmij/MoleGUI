import Foundation

enum Whitelist {
    // Paths that should never be deleted
    static var protectedPaths: Set<String> {
        [
            // System critical
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/private/var",
            "/Library/Apple",

            // User critical
            "~/Library/Keychains",
            "~/Library/Application Scripts",
            "~/.ssh",
            "~/.gnupg",
            "~/.config",

            // App critical data (expanded from home)
            "Library/Keychains",
            "Library/Application Scripts"
        ]
    }

    // Bundle identifiers of apps that should not be uninstalled
    static var protectedApps: Set<String> {
        [
            "com.apple.finder",
            "com.apple.Safari",
            "com.apple.AppStore",
            "com.apple.systempreferences",
            "com.apple.Terminal",
            "com.apple.dt.Xcode"
        ]
    }

    // Cache paths that should be skipped
    static var protectedCaches: Set<String> {
        [
            "CloudKit",
            "com.apple.Safari",
            "com.apple.Finder",
            "com.apple.metadata",
            "com.apple.nsurlsessiond"
        ]
    }

    static func isProtected(_ url: URL) -> Bool {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Check absolute paths
        for protectedPath in protectedPaths {
            let expandedPath = protectedPath.replacingOccurrences(of: "~", with: home)
            if path.hasPrefix(expandedPath) {
                return true
            }
        }

        return false
    }

    static func isProtectedApp(_ bundleIdentifier: String) -> Bool {
        protectedApps.contains(bundleIdentifier)
    }

    static func isProtectedCache(_ name: String) -> Bool {
        protectedCaches.contains { name.localizedCaseInsensitiveContains($0) }
    }
}
