import Foundation
import AppKit

actor AppBundleAnalyzer {
    private let fileManager = FileManager.default
    private let scanner = FileScanner()

    func scanInstalledApps(progress: @escaping (String, Double) -> Void) async throws -> [InstalledApp] {
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        var apps: [InstalledApp] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let appBundles = contents.filter { $0.pathExtension == "app" }
        let totalApps = appBundles.count
        var processedApps = 0

        for appURL in appBundles {
            progress("Scanning \(appURL.lastPathComponent)...", Double(processedApps) / Double(totalApps))

            if let app = await analyzeAppBundle(at: appURL) {
                apps.append(app)
            }

            processedApps += 1
        }

        // Also scan user Applications folder
        let userAppsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        if fileManager.fileExists(atPath: userAppsURL.path),
           let userContents = try? fileManager.contentsOfDirectory(
            at: userAppsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
           ) {
            let userAppBundles = userContents.filter { $0.pathExtension == "app" }

            for appURL in userAppBundles {
                if let app = await analyzeAppBundle(at: appURL) {
                    apps.append(app)
                }
            }
        }

        progress("Scan complete", 1.0)

        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    private func analyzeAppBundle(at url: URL) async -> InstalledApp? {
        let bundle = Bundle(url: url)

        let name = url.deletingPathExtension().lastPathComponent
        let bundleIdentifier = bundle?.bundleIdentifier
        let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String

        // Get app icon
        let icon: NSImage? = await MainActor.run {
            NSWorkspace.shared.icon(forFile: url.path)
        }

        // Calculate app size using fast du command
        let size = (try? await scanner.calculateDirectorySize(url)) ?? 0

        // Get last used date
        let lastUsed = try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        // Don't scan remnants during initial load - defer to when app is selected
        let app = InstalledApp(
            url: url,
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            size: size,
            icon: icon,
            lastUsed: lastUsed
        )

        return app
    }

    /// Load remnants for an app on-demand (called when app is selected)
    func loadRemnantsForApp(_ app: InstalledApp) async -> [AppRemnant] {
        guard let bundleId = app.bundleIdentifier else { return [] }
        return await findRemnants(bundleIdentifier: bundleId, appName: app.name)
    }

    func findRemnants(bundleIdentifier: String, appName: String) async -> [AppRemnant] {
        var remnants: [AppRemnant] = []

        let remnantURLs = AppRemnantPaths.findRemnants(for: bundleIdentifier, appName: appName)

        for url in remnantURLs {
            let size = (try? await scanner.calculateDirectorySize(url)) ?? 0

            // Determine remnant type based on path
            let type = determineRemnantType(from: url)

            remnants.append(AppRemnant(url: url, type: type, size: size))
        }

        return remnants.sorted { $0.size > $1.size }
    }

    private func determineRemnantType(from url: URL) -> RemnantType {
        let path = url.path

        if path.contains("Application Support") { return .applicationSupport }
        if path.contains("/Caches/") { return .caches }
        if path.contains("/Preferences/") { return .preferences }
        if path.contains("/Logs/") { return .logs }
        if path.contains("/LaunchAgents/") { return .launchAgents }
        if path.contains("/LaunchDaemons/") { return .launchDaemons }
        if path.contains("/Containers/") { return .containers }
        if path.contains("/Saved Application State/") { return .savedState }

        return .other
    }

    func uninstallApp(_ app: InstalledApp, includeRemnants: Bool = true) async throws -> Int64 {
        var totalRemoved: Int64 = 0

        // Check if app is protected
        if let bundleId = app.bundleIdentifier, Whitelist.isProtectedApp(bundleId) {
            throw NSError(
                domain: "AppBundleAnalyzer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot uninstall protected system app"]
            )
        }

        // Move app to trash
        var trashedURL: NSURL?
        try fileManager.trashItem(at: app.url, resultingItemURL: &trashedURL)
        totalRemoved += app.size

        // Remove remnants if requested
        if includeRemnants {
            for remnant in app.remnants {
                do {
                    try fileManager.trashItem(at: remnant.url, resultingItemURL: nil)
                    totalRemoved += remnant.size
                } catch {
                    // Continue even if some remnants fail
                    continue
                }
            }
        }

        return totalRemoved
    }
}
