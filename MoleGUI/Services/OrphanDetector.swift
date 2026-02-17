import Foundation
import AppKit

actor OrphanDetector {
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    private var isCancelled = false

    /// Directories inside ~/Library that may contain orphaned app data
    private let librarySubdirs = [
        "Caches",
        "Logs",
        "Saved Application State",
        "WebKit",
        "HTTPStorages",
        "Cookies",
        "LaunchAgents",
    ]

    /// Minimum days since last modification before considering data orphaned
    private let inactivityThresholdDays = 60

    func cancel() { isCancelled = true }
    func reset() { isCancelled = false }

    /// Scans for orphaned app data from uninstalled applications
    func scanForOrphanedData(progress: @escaping (String, Double) -> Void) async -> [CacheItem] {
        reset()

        // Build set of installed app bundle identifiers
        let installedBundleIds = await getInstalledAppBundleIds()
        var orphanedItems: [CacheItem] = []

        let totalDirs = librarySubdirs.count
        for (index, subdir) in librarySubdirs.enumerated() {
            guard !isCancelled else { break }

            let dirURL = homeDirectory.appendingPathComponent("Library/\(subdir)")
            guard fileManager.fileExists(atPath: dirURL.path) else { continue }

            progress("Checking \(subdir) for orphans...", Double(index) / Double(totalDirs))

            guard let contents = try? fileManager.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
                continue
            }

            for itemURL in contents {
                guard !isCancelled else { break }

                let name = itemURL.lastPathComponent

                // Skip non-bundle-id-like names and protected items
                guard looksLikeBundleId(name) else { continue }
                if Whitelist.isProtectedOrphan(name) { continue }
                if Whitelist.isProtectedCache(name) { continue }

                // Skip if an installed app matches this bundle ID
                if installedBundleIds.contains(name) { continue }
                if installedBundleIds.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) { continue }

                // mdfind Spotlight fallback - verify app truly doesn't exist
                if appExistsViaMdfind(name) { continue }

                // Check inactivity threshold
                if let modDate = try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    let daysSinceModified = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
                    if daysSinceModified < inactivityThresholdDays { continue }
                }

                // Calculate size
                let size = await calculateSize(itemURL)
                guard size > 0 else { continue }

                let item = CacheItem(
                    url: itemURL,
                    name: name,
                    size: size,
                    category: .orphanedData,
                    lastModified: try? fileManager.attributesOfItem(atPath: itemURL.path)[.modificationDate] as? Date,
                    displayName: extractAppName(from: name),
                    subtitle: subdir
                )
                orphanedItems.append(item)
            }
        }

        progress("Orphan scan complete", 1.0)
        return orphanedItems.sorted { $0.size > $1.size }
    }

    /// Gathers bundle IDs of all installed applications
    private func getInstalledAppBundleIds() async -> Set<String> {
        var bundleIds = Set<String>()

        let searchPaths = [
            URL(fileURLWithPath: "/Applications"),
            homeDirectory.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications"),
        ]

        // Check Setapp applications
        let setappDir = homeDirectory.appendingPathComponent("Library/Application Support/Setapp/Applications")
        if fileManager.fileExists(atPath: setappDir.path) {
            if let enumerator = fileManager.enumerator(
                at: setappDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) {
                for case let url as URL in enumerator {
                    if url.pathExtension == "app" {
                        enumerator.skipDescendants()
                        if let bundle = Bundle(url: url), let id = bundle.bundleIdentifier {
                            bundleIds.insert(id)
                        }
                    }
                }
            }
        }

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: searchPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) else { continue }

            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    enumerator.skipDescendants()
                    if let bundle = Bundle(url: url), let id = bundle.bundleIdentifier {
                        bundleIds.insert(id)
                    }
                }
            }
        }

        // Also check running apps
        await MainActor.run {
            for app in NSWorkspace.shared.runningApplications {
                if let id = app.bundleIdentifier {
                    bundleIds.insert(id)
                }
            }
        }

        // Add hardcoded system component bundle IDs that are not in /Applications
        let systemBundleIds: Set<String> = [
            "com.apple.ScreenSaver.Engine",
            "com.apple.dock",
            "com.apple.loginwindow",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
            "com.apple.Spotlight",
            "com.apple.accessibility.heard",
            "com.apple.FolderActionsDispatcher",
        ]
        bundleIds.formUnion(systemBundleIds)

        return bundleIds
    }

    // MARK: - Spotlight Fallback

    /// Uses mdfind (Spotlight) to verify if an app with the given bundle ID exists anywhere
    private func appExistsViaMdfind(_ bundleId: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemCFBundleIdentifier == '\(bundleId)'"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Orphaned LaunchDaemons

    /// Scans system-level LaunchDaemons/LaunchAgents for orphaned entries
    func scanOrphanedServices(installedBundleIds: Set<String>) async -> [CacheItem] {
        var orphans: [CacheItem] = []

        let serviceDirs = [
            homeDirectory.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]

        for dir in serviceDirs {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { continue }

            for plistURL in contents where plistURL.pathExtension == "plist" {
                guard !isCancelled else { break }

                let name = plistURL.deletingPathExtension().lastPathComponent

                // Skip system and protected items
                if name.hasPrefix("com.apple.") { continue }
                if Whitelist.isProtectedOrphan(name) { continue }

                // Extract bundle ID from plist name
                guard looksLikeBundleId(name) else { continue }

                // Check if any installed app matches
                if installedBundleIds.contains(name) { continue }
                if installedBundleIds.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) { continue }

                // mdfind fallback check
                if appExistsViaMdfind(name) { continue }

                let size = (try? fileManager.attributesOfItem(atPath: plistURL.path)[.size] as? Int64) ?? 0

                let item = CacheItem(
                    url: plistURL,
                    name: name,
                    size: size,
                    category: .orphanedData,
                    lastModified: try? fileManager.attributesOfItem(atPath: plistURL.path)[.modificationDate] as? Date,
                    displayName: extractAppName(from: name),
                    subtitle: dir.lastPathComponent
                )
                orphans.append(item)
            }
        }

        return orphans
    }

    private func looksLikeBundleId(_ name: String) -> Bool {
        // Bundle IDs typically contain dots: com.company.app
        let parts = name.split(separator: ".")
        return parts.count >= 2
    }

    private func extractAppName(from bundleId: String) -> String {
        // Extract meaningful name from bundle ID like "com.company.AppName"
        let parts = bundleId.split(separator: ".")
        if let last = parts.last {
            return String(last)
        }
        return bundleId
    }

    private func calculateSize(_ url: URL) async -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let sizeStr = output.split(separator: "\t").first,
               let sizeKB = Int64(sizeStr) {
                return sizeKB * 1024
            }
        } catch {}
        return 0
    }
}
