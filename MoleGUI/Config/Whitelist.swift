import Foundation

enum Whitelist {
    // Paths that should never be deleted
    static var protectedPaths: Set<String> {
        var paths: Set<String> = [
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
            "Library/Application Scripts",

            // Security-sensitive app data
            "Library/Application Support/1Password",
            "Library/Application Support/Bitwarden",
            "Library/Application Support/LastPass",
            "Library/Application Support/KeePassXC",
            "Library/Application Support/Dashlane",

            // Cloud storage — accidental deletion can cause data loss across devices
            "~/Library/Mobile Documents",              // iCloud Drive
            "~/Library/CloudStorage",                  // Dropbox, Google Drive, OneDrive mount points
            "Library/Mobile Documents",
            "Library/CloudStorage",
            "Library/Application Support/CloudDocs",
            "~/Dropbox",                               // Legacy Dropbox location
            "~/Google Drive",                          // Legacy Google Drive
            "~/OneDrive",                              // Legacy OneDrive
        ]

        // Load user-defined whitelist from config file
        paths.formUnion(userWhitelistPaths)

        return paths
    }

    /// Paths loaded from ~/.config/mole/whitelist (one path per line)
    static var userWhitelistPaths: Set<String> {
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mole/whitelist")
        guard let content = try? String(contentsOf: configFile, encoding: .utf8) else {
            return []
        }
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return Set(lines)
    }

    /// Writes a path to the user whitelist config file
    static func addToUserWhitelist(_ path: String) {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mole")
        let configFile = configDir.appendingPathComponent("whitelist")

        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        var paths = userWhitelistPaths
        paths.insert(path)

        let content = "# Mole user whitelist - one path per line\n" + paths.sorted().joined(separator: "\n") + "\n"
        try? content.write(to: configFile, atomically: true, encoding: .utf8)
    }

    /// Removes a path from the user whitelist config file
    static func removeFromUserWhitelist(_ path: String) {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mole")
        let configFile = configDir.appendingPathComponent("whitelist")

        var paths = userWhitelistPaths
        paths.remove(path)

        let content = "# Mole user whitelist - one path per line\n" + paths.sorted().joined(separator: "\n") + "\n"
        try? content.write(to: configFile, atomically: true, encoding: .utf8)
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

    // Bundle identifiers whose orphaned data should never be cleaned
    static var protectedOrphanBundleIds: Set<String> {
        [
            "com.agilebits.onepassword",
            "com.bitwarden.desktop",
            "com.lastpass.LastPass",
            "org.keepassxc.keepassxc",
            "com.dashlane.Dashlane",
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

    static func isProtectedOrphan(_ bundleId: String) -> Bool {
        protectedOrphanBundleIds.contains(bundleId)
    }
}
