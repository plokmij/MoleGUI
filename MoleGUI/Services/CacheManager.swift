import Foundation
import AppKit

actor CacheManager {
    enum CleanError: Error, LocalizedError {
        case deletionFailed(URL, Error)
        case accessDenied(URL)
        case protectedPath(URL)
        case appRunning(String)

        var errorDescription: String? {
            switch self {
            case .deletionFailed(let url, let error):
                return "Failed to delete \(url.path): \(error.localizedDescription)"
            case .accessDenied(let url):
                return "Access denied to \(url.path)"
            case .protectedPath(let url):
                return "Cannot delete protected path: \(url.path)"
            case .appRunning(let name):
                return "Skipped: \(name) is currently running"
            }
        }
    }

    struct CleanResult {
        let deletedCount: Int
        let deletedSize: Int64
        let errors: [CleanError]
        let skippedRunning: Int

        var hadErrors: Bool { !errors.isEmpty }
    }

    private let fileManager = FileManager.default
    private let logger = OperationLogger.shared

    func cleanItems(_ items: [CacheItem], dryRun: Bool = false, skipRunningApps: Bool = true) async throws -> CleanResult {
        var deletedCount = 0
        var deletedSize: Int64 = 0
        var errors: [CleanError] = []
        var skippedRunning = 0

        // Build set of running app bundle IDs for skip detection
        let runningBundleIds: Set<String> = skipRunningApps ? await getRunningAppBundleIds() : []

        for item in items where item.isSelected {
            // Check if path is protected
            if Whitelist.isProtected(item.url) {
                errors.append(.protectedPath(item.url))
                await logger.log("SKIP-PROTECTED", path: item.url.path)
                continue
            }

            // Path traversal validation
            if containsPathTraversal(item.url.path) {
                errors.append(.protectedPath(item.url))
                await logger.log("SKIP-TRAVERSAL", path: item.url.path)
                continue
            }

            // Check if owning app is running (bundle-ID and name-based matching)
            if skipRunningApps && isAppRunning(for: item.url.path, runningBundleIds: runningBundleIds) {
                skippedRunning += 1
                await logger.log("SKIP-RUNNING", path: item.url.path)
                continue
            }

            if dryRun {
                deletedCount += 1
                deletedSize += item.size
                await logger.log("DRY-RUN", path: item.url.path, size: item.size)
            } else {
                do {
                    try await deleteItem(item.url)
                    deletedCount += 1
                    deletedSize += item.size
                    await logger.log("DELETE", path: item.url.path, size: item.size)
                } catch {
                    errors.append(.deletionFailed(item.url, error))
                    await logger.log("DELETE", path: item.url.path, success: false)
                }
            }
        }

        return CleanResult(deletedCount: deletedCount, deletedSize: deletedSize, errors: errors, skippedRunning: skippedRunning)
    }

    func cleanCategories(_ categories: [CacheCategoryResult], dryRun: Bool = false) async throws -> CleanResult {
        var totalDeleted = 0
        var totalSize: Int64 = 0
        var allErrors: [CleanError] = []
        var totalSkipped = 0

        for category in categories {
            let result = try await cleanItems(category.items, dryRun: dryRun)
            totalDeleted += result.deletedCount
            totalSize += result.deletedSize
            allErrors.append(contentsOf: result.errors)
            totalSkipped += result.skippedRunning
        }

        return CleanResult(deletedCount: totalDeleted, deletedSize: totalSize, errors: allErrors, skippedRunning: totalSkipped)
    }

    private func deleteItem(_ url: URL) async throws {
        // Use NSWorkspace to move to Trash for safer deletion
        try await MainActor.run {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
        }
    }

    func deleteItemPermanently(_ url: URL) async throws {
        guard !Whitelist.isProtected(url) else {
            throw CleanError.protectedPath(url)
        }

        guard !containsPathTraversal(url.path) else {
            throw CleanError.protectedPath(url)
        }

        try fileManager.removeItem(at: url)
        await logger.log("PERMANENT-DELETE", path: url.path)
    }

    /// Cleans items that require administrator privileges using AppleScript privilege escalation.
    /// Uses `osascript -e 'do shell script "rm -rf ..." with administrator privileges'`
    func cleanWithPrivileges(_ items: [CacheItem], dryRun: Bool = false) async throws -> CleanResult {
        var deletedCount = 0
        var deletedSize: Int64 = 0
        var errors: [CleanError] = []

        let adminItems = items.filter { $0.isSelected && $0.requiresAdmin }
        guard !adminItems.isEmpty else {
            return CleanResult(deletedCount: 0, deletedSize: 0, errors: [], skippedRunning: 0)
        }

        if dryRun {
            for item in adminItems {
                deletedCount += 1
                deletedSize += item.size
                await logger.log("DRY-RUN-ADMIN", path: item.url.path, size: item.size)
            }
            return CleanResult(deletedCount: deletedCount, deletedSize: deletedSize, errors: [], skippedRunning: 0)
        }

        // Process in batches to avoid overly long shell commands
        let batchSize = 10
        for batch in stride(from: 0, to: adminItems.count, by: batchSize) {
            let end = min(batch + batchSize, adminItems.count)
            let batchItems = Array(adminItems[batch..<end])
            let batchPaths = batchItems.map { item in
                "'\(item.url.path.replacingOccurrences(of: "'", with: "'\\''"))'"
            }
            let rmCommand = "rm -rf " + batchPaths.joined(separator: " ")

            let script = "do shell script \"\(rmCommand.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    for item in batchItems {
                        deletedCount += 1
                        deletedSize += item.size
                        await logger.log("DELETE-ADMIN", path: item.url.path, size: item.size)
                    }
                } else {
                    for item in batchItems {
                        errors.append(.accessDenied(item.url))
                        await logger.log("DELETE-ADMIN", path: item.url.path, success: false)
                    }
                }
            } catch {
                for item in batchItems {
                    errors.append(.deletionFailed(item.url, error))
                }
            }
        }

        return CleanResult(deletedCount: deletedCount, deletedSize: deletedSize, errors: errors, skippedRunning: 0)
    }

    func emptyTrash() async throws -> Int64 {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")

        guard fileManager.fileExists(atPath: trashURL.path) else {
            return 0
        }

        // Calculate size before deletion
        let scanner = FileScanner()
        let size = try await scanner.calculateDirectorySize(trashURL)

        // Get contents
        let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)

        for item in contents {
            try fileManager.removeItem(at: item)
        }

        await logger.log("EMPTY-TRASH", path: trashURL.path, size: size)
        return size
    }

    // MARK: - Running App Detection

    /// Maps cache folder names to bundle identifiers for apps whose cache paths
    /// don't follow the reverse-DNS convention
    private static let knownAppMappings: [String: String] = [
        // Browsers
        "Google/Chrome": "com.google.Chrome",
        "Google": "com.google.Chrome",
        "Firefox": "org.mozilla.firefox",
        "Microsoft Edge": "com.microsoft.edgemac",
        "Safari": "com.apple.Safari",
        "BraveSoftware": "com.brave.Browser",

        // Communication
        "Slack": "com.tinyspeck.slackmacgap",
        "discord": "com.hnc.Discord",
        "Discord": "com.hnc.Discord",
        "Telegram Desktop": "ru.keepcoder.Telegram",
        "WhatsApp": "net.whatsapp.WhatsApp",
        "Skype": "com.skype.skype",
        "zoom.us": "us.zoom.xos",

        // Productivity
        "Spotify": "com.spotify.client",
        "Notion": "notion.id",

        // Dev tools
        "Code": "com.microsoft.VSCode",
        "Cursor": "com.todesktop.230313mzl4w4u92",
        "Sublime Text": "com.sublimetext.4",
        "Zed": "dev.zed.Zed",

        // Design
        "Figma": "com.figma.Desktop",
        "Sketch": "com.bohemiancoding.sketch3",

        // Apple apps
        "Mail Downloads": "com.apple.mail",
        "FinalCut": "com.apple.FinalCut",

        // Adobe
        "Adobe": "com.adobe.cc.ui",

        // Media
        "Steam": "com.valvesoftware.steam",
        "Blender": "org.blenderfoundation.blender",
    ]

    private func getRunningAppBundleIds() async -> Set<String> {
        await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        }
    }

    /// Checks if the app owning the given cache path is currently running
    private func isAppRunning(for path: String, runningBundleIds: Set<String>) -> Bool {
        // Try reverse-DNS bundle ID extraction first
        if let bundleId = extractBundleId(from: path) {
            if runningBundleIds.contains(bundleId) {
                return true
            }
        }

        // Fall back to name-based matching via knownAppMappings
        let components = path.components(separatedBy: "/")
        for (folderName, bundleId) in Self.knownAppMappings {
            // Check if the folder name appears as a path component (or as adjacent components for "Google/Chrome")
            if folderName.contains("/") {
                // Multi-component match (e.g., "Google/Chrome")
                if path.contains(folderName) && runningBundleIds.contains(bundleId) {
                    return true
                }
            } else {
                if components.contains(folderName) && runningBundleIds.contains(bundleId) {
                    return true
                }
            }
        }

        return false
    }

    /// Extracts a likely bundle ID from a cache path like ~/Library/Caches/com.example.app
    private func extractBundleId(from path: String) -> String? {
        let components = path.components(separatedBy: "/")
        // Look for bundle-id-like component (contains dots like com.example.app)
        for component in components.reversed() {
            let parts = component.split(separator: ".")
            if parts.count >= 3, parts.first?.count ?? 0 >= 2 {
                return component
            }
        }
        return nil
    }

    /// Validates that a path doesn't contain traversal sequences
    private func containsPathTraversal(_ path: String) -> Bool {
        // Check for directory traversal
        if path.contains("../") || path.contains("/..") { return true }
        // Check for control characters
        for scalar in path.unicodeScalars {
            if scalar.value < 32 && scalar.value != 10 { return true }
        }
        return false
    }
}
