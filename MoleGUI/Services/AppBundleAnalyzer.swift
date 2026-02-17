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

    /// Cache of Homebrew cask names to app names
    private var brewCaskMap: [String: String]?

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

        // Check if installed via Homebrew cask
        let caskInfo = detectBrewCask(appName: name)

        // Don't scan remnants during initial load - defer to when app is selected
        var app = InstalledApp(
            url: url,
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            size: size,
            icon: icon,
            lastUsed: lastUsed
        )
        app.isBrewCask = caskInfo != nil
        app.brewCaskName = caskInfo

        return app
    }

    /// Detects if an app was installed via Homebrew cask
    private func detectBrewCask(appName: String) -> String? {
        // Lazy-load the brew cask map
        if brewCaskMap == nil {
            brewCaskMap = loadBrewCaskMap()
        }

        let lowerName = appName.lowercased()
        return brewCaskMap?[lowerName]
    }

    /// Loads map of app name -> cask name from Homebrew Caskroom
    private func loadBrewCaskMap() -> [String: String] {
        var map: [String: String] = [:]

        let caskroom = URL(fileURLWithPath: "/opt/homebrew/Caskroom")
        let altCaskroom = URL(fileURLWithPath: "/usr/local/Caskroom")

        let targetDir = fileManager.fileExists(atPath: caskroom.path) ? caskroom :
            (fileManager.fileExists(atPath: altCaskroom.path) ? altCaskroom : nil)

        guard let dir = targetDir,
              let casks = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return map
        }

        for cask in casks {
            let caskName = cask.lastPathComponent
            // Map common cask names to app names
            let appName = caskName.replacingOccurrences(of: "-", with: " ")
            map[appName.lowercased()] = caskName
            map[caskName.lowercased()] = caskName
        }

        return map
    }

    /// Uninstalls a Homebrew cask app
    func uninstallBrewCask(_ caskName: String) async throws -> Bool {
        let brewPath = fileManager.fileExists(atPath: "/opt/homebrew/bin/brew")
            ? "/opt/homebrew/bin/brew"
            : "/usr/local/bin/brew"

        guard fileManager.fileExists(atPath: brewPath) else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["uninstall", "--cask", caskName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
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
