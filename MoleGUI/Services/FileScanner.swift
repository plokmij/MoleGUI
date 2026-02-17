import Foundation

actor FileScanner {
    enum ScanError: Error, LocalizedError {
        case accessDenied(URL)
        case scanCancelled
        case invalidPath(URL)

        var errorDescription: String? {
            switch self {
            case .accessDenied(let url):
                return "Access denied to \(url.path)"
            case .scanCancelled:
                return "Scan was cancelled"
            case .invalidPath(let url):
                return "Invalid path: \(url.path)"
            }
        }
    }

    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func reset() {
        isCancelled = false
    }

    func scanDirectory(_ url: URL, maxDepth: Int = 10) async throws -> (files: [URL], totalSize: Int64) {
        reset()

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScanError.invalidPath(url)
        }

        var files: [URL] = []
        var totalSize: Int64 = 0

        try await scanRecursive(url: url, depth: 0, maxDepth: maxDepth, files: &files, totalSize: &totalSize)

        return (files, totalSize)
    }

    private func scanRecursive(
        url: URL,
        depth: Int,
        maxDepth: Int,
        files: inout [URL],
        totalSize: inout Int64
    ) async throws {
        guard !isCancelled else {
            throw ScanError.scanCancelled
        }

        guard depth < maxDepth else { return }

        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])

                if resourceValues.isDirectory == false {
                    files.append(fileURL)
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }

            // Yield periodically to allow UI updates
            if files.count % 100 == 0 {
                await Task.yield()
            }
        }
    }

    func calculateDirectorySize(_ url: URL) async throws -> Int64 {
        reset()

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            return 0
        }

        // Use `du -sk` for fast size calculation (like Mole does)
        // This is much faster than enumerating all files
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
                return sizeKB * 1024 // Convert KB to bytes
            }
        } catch {
            // Fallback: return 0 if du fails
        }

        return 0
    }

    func scanForCaches(locations: [CacheLocation], progress: @escaping (String, Double) -> Void) async throws -> [CacheCategoryResult] {
        reset()

        var results: [CacheCategory: [CacheItem]] = [:]

        // Add sandboxed app caches (generic scan)
        let sandboxedItems = await scanSandboxedAppCaches()
        if !sandboxedItems.isEmpty {
            results[.applicationCache] = (results[.applicationCache] ?? []) + sandboxedItems
        }

        // Add old macOS installers to system-level category
        let installerItems = await scanOldMacOSInstallers()
        if !installerItems.isEmpty {
            results[.systemLevel] = (results[.systemLevel] ?? []) + installerItems
        }

        let totalLocations = locations.count
        var scannedLocations = 0

        for location in locations {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            guard location.exists else {
                scannedLocations += 1
                continue
            }

            progress("Scanning \(location.path.lastPathComponent)...", Double(scannedLocations) / Double(totalLocations))

            // Check if this is a location that should be expanded into individual devices
            if location.expandDevices {
                let deviceItems: [CacheItem]
                if location.path.lastPathComponent == "Devices" && location.category == .xcodeData {
                    deviceItems = try await scanSimulatorDevices(at: location.path)
                } else if location.path.lastPathComponent == "avd" && location.category == .androidData {
                    deviceItems = try await scanAndroidAVDs(at: location.path)
                } else {
                    deviceItems = []
                }

                if !deviceItems.isEmpty {
                    if results[location.category] == nil {
                        results[location.category] = []
                    }
                    results[location.category]?.append(contentsOf: deviceItems)
                }
            } else {
                let size = try await calculateDirectorySize(location.path)

                if size > 0 {
                    let item = CacheItem(
                        url: location.path,
                        name: location.path.lastPathComponent,
                        size: size,
                        category: location.category,
                        lastModified: try? FileManager.default.attributesOfItem(atPath: location.path.path)[.modificationDate] as? Date,
                        requiresAdmin: location.requiresAdmin,
                        riskLevel: location.riskLevel
                    )

                    if results[location.category] == nil {
                        results[location.category] = []
                    }
                    results[location.category]?.append(item)
                }
            }

            scannedLocations += 1
        }

        progress("Scan complete", 1.0)

        return results.map { category, items in
            CacheCategoryResult(category: category, items: items)
        }.sorted { $0.totalSize > $1.totalSize }
    }

    // MARK: - Sandboxed App Caches

    /// Scans ~/Library/Containers/*/Data/Library/Caches for sandboxed app caches
    private func scanSandboxedAppCaches() async -> [CacheItem] {
        let containersDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
        var items: [CacheItem] = []

        guard let containers = try? FileManager.default.contentsOfDirectory(at: containersDir, includingPropertiesForKeys: nil) else {
            return []
        }

        // Collect known cache paths so we don't double-count
        let knownPaths = Set(CachePaths.allLocations.map { $0.path.path })

        for container in containers {
            guard !isCancelled else { break }

            let cachesDir = container
                .appendingPathComponent("Data/Library/Caches")

            guard FileManager.default.fileExists(atPath: cachesDir.path) else { continue }

            // Skip if already covered by explicit cache paths
            if knownPaths.contains(cachesDir.path) { continue }

            let size = try? await calculateDirectorySize(cachesDir)
            guard let size = size, size > 100_000 else { continue } // Skip tiny caches

            let bundleId = container.lastPathComponent
            let displayName = bundleId.split(separator: ".").last.map(String.init) ?? bundleId

            let item = CacheItem(
                url: cachesDir,
                name: bundleId,
                size: size,
                category: .applicationCache,
                lastModified: try? FileManager.default.attributesOfItem(atPath: cachesDir.path)[.modificationDate] as? Date,
                displayName: displayName,
                subtitle: "Sandboxed"
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Homebrew Integration

    /// Runs `brew cleanup` and `brew autoremove` with a 7-day cooldown
    func runBrewCleanup() async -> (success: Bool, message: String) {
        let cooldownFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mole/brew_cleanup_timestamp")

        // Check 7-day cooldown
        if FileManager.default.fileExists(atPath: cooldownFile.path),
           let content = try? String(contentsOf: cooldownFile, encoding: .utf8),
           let timestamp = Double(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let lastRun = Date(timeIntervalSince1970: timestamp)
            let daysSince = Calendar.current.dateComponents([.day], from: lastRun, to: Date()).day ?? 0
            if daysSince < 7 {
                return (true, "Homebrew cleanup ran \(daysSince) day(s) ago (7-day cooldown)")
            }
        }

        // Check if brew is installed
        let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            ? "/opt/homebrew/bin/brew"
            : "/usr/local/bin/brew"
        guard FileManager.default.fileExists(atPath: brewPath) else {
            return (false, "Homebrew not installed")
        }

        let r1 = runCommand(brewPath, arguments: ["cleanup", "--prune=all"])
        let r2 = runCommand(brewPath, arguments: ["autoremove"])

        // Write timestamp
        let configDir = cooldownFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? String(Date().timeIntervalSince1970).write(to: cooldownFile, atomically: true, encoding: .utf8)

        if r1 || r2 {
            return (true, "Homebrew cleanup and autoremove complete")
        }
        return (false, "Homebrew cleanup failed")
    }

    @discardableResult
    private func runCommand(_ path: String, arguments: [String], timeout: TimeInterval = 120) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()

            // Wait with timeout
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
            }
            if process.isRunning {
                process.terminate()
                return false
            }

            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - .DS_Store Cleanup

    /// Recursively removes .DS_Store files from home directory, with exclusions
    func cleanDSStoreFiles(in directory: URL? = nil) async -> (count: Int, size: Int64) {
        let targetDir = directory ?? FileManager.default.homeDirectoryForCurrentUser
        var removedCount = 0
        var removedSize: Int64 = 0

        let excludedDirs: Set<String> = [
            "MobileSync",
            "Developer",
            "node_modules",
            ".git",
            ".Trash",
            "Library/Developer",
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: targetDir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else { return (0, 0) }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else { break }

            let name = fileURL.lastPathComponent

            // Skip excluded directories
            if excludedDirs.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            if name == ".DS_Store" {
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
                if (try? FileManager.default.removeItem(at: fileURL)) != nil {
                    removedCount += 1
                    removedSize += size
                }
            }
        }

        return (removedCount, removedSize)
    }

    /// Scans iOS Simulator devices and returns individual CacheItems for each device
    func scanSimulatorDevices(at url: URL) async throws -> [CacheItem] {
        let fileManager = FileManager.default
        var devices: [CacheItem] = []

        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }

        for deviceFolder in contents {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            // Skip non-directories
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: deviceFolder.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let plistURL = deviceFolder.appendingPathComponent("device.plist")
            guard fileManager.fileExists(atPath: plistURL.path) else {
                continue
            }

            // Parse device.plist
            guard let plistData = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
                continue
            }

            // Skip deleted devices
            if let isDeleted = plist["isDeleted"] as? Bool, isDeleted {
                continue
            }

            let deviceName = plist["name"] as? String ?? "Unknown Device"
            let runtime = plist["runtime"] as? String ?? ""
            let lastBootedAt = plist["lastBootedAt"] as? Date

            // Parse runtime string like "com.apple.CoreSimulator.SimRuntime.iOS-18-4"
            let iosVersion = parseRuntimeVersion(runtime)

            let size = try await calculateDirectorySize(deviceFolder)
            guard size > 0 else { continue }

            let displayName = deviceName
            let subtitle = iosVersion.isEmpty ? nil : iosVersion

            let item = CacheItem(
                url: deviceFolder,
                name: deviceFolder.lastPathComponent,
                size: size,
                category: .xcodeData,
                lastModified: lastBootedAt,
                displayName: displayName,
                subtitle: subtitle
            )

            devices.append(item)
        }

        // Sort by last booted date (most recent first)
        return devices.sorted { item1, item2 in
            guard let date1 = item1.lastModified else { return false }
            guard let date2 = item2.lastModified else { return true }
            return date1 > date2
        }
    }

    /// Parses runtime string like "com.apple.CoreSimulator.SimRuntime.iOS-18-4" into "iOS 18.4"
    private func parseRuntimeVersion(_ runtime: String) -> String {
        // Extract the last component after the final dot
        guard let lastComponent = runtime.split(separator: ".").last else {
            return ""
        }

        // Parse patterns like "iOS-18-4", "tvOS-18-2", "watchOS-11-2"
        let parts = lastComponent.split(separator: "-")
        guard parts.count >= 2 else {
            return String(lastComponent)
        }

        let platform = parts[0]
        let versionParts = parts.dropFirst().map { String($0) }
        let version = versionParts.joined(separator: ".")

        return "\(platform) \(version)"
    }

    /// Scans Android AVD (emulator) devices and returns individual CacheItems
    func scanAndroidAVDs(at url: URL) async throws -> [CacheItem] {
        let fileManager = FileManager.default
        var avds: [CacheItem] = []

        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }

        for item in contents {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            // Look for .avd directories
            guard item.pathExtension == "avd" else {
                continue
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Parse config.ini inside the .avd folder
            let configURL = item.appendingPathComponent("config.ini")
            var displayName: String?
            var apiLevel: String?

            if fileManager.fileExists(atPath: configURL.path),
               let configContent = try? String(contentsOf: configURL, encoding: .utf8) {
                let config = parseIniFile(configContent)
                displayName = config["avd.ini.displayname"] ?? config["hw.device.name"]
                apiLevel = config["image.sysdir.1"].flatMap { extractAPILevel(from: $0) }
                    ?? config["tag.id"].flatMap { "API \($0)" }
            }

            // Fallback to folder name without .avd extension
            if displayName == nil {
                displayName = item.deletingPathExtension().lastPathComponent
            }

            let size = try await calculateDirectorySize(item)
            guard size > 0 else { continue }

            let subtitle = apiLevel

            let cacheItem = CacheItem(
                url: item,
                name: item.lastPathComponent,
                size: size,
                category: .androidData,
                lastModified: try? fileManager.attributesOfItem(atPath: item.path)[.modificationDate] as? Date,
                displayName: displayName,
                subtitle: subtitle
            )

            avds.append(cacheItem)
        }

        // Sort by size (largest first)
        return avds.sorted { $0.size > $1.size }
    }

    /// Parses an INI file content into a dictionary
    private func parseIniFile(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else {
                continue
            }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        return result
    }

    /// Extracts API level from sysdir path like "system-images/android-34/google_apis/arm64-v8a/"
    private func extractAPILevel(from sysdir: String) -> String? {
        let components = sysdir.components(separatedBy: "/")
        for component in components {
            if component.hasPrefix("android-") {
                let level = component.replacingOccurrences(of: "android-", with: "")
                return "API \(level)"
            }
        }
        return nil
    }

    // MARK: - Unavailable Simulator Cleanup

    /// Runs `xcrun simctl delete unavailable` to remove unavailable simulator runtimes
    func deleteUnavailableSimulators() async -> (success: Bool, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "delete", "unavailable"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let success = process.terminationStatus == 0
            return (success, success ? "Removed unavailable simulators" : "Failed to remove unavailable simulators")
        } catch {
            return (false, "xcrun simctl not available")
        }
    }

    // MARK: - Old macOS Installer Apps

    /// Scans for old macOS installer apps (14+ days old)
    func scanOldMacOSInstallers() async -> [CacheItem] {
        let applicationsDir = URL(fileURLWithPath: "/Applications")
        var items: [CacheItem] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: applicationsDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
        ) else { return [] }

        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        for item in contents {
            let name = item.lastPathComponent
            guard name.hasPrefix("Install macOS") && name.hasSuffix(".app") else { continue }

            if let values = try? item.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate < cutoff {
                let size = try? await calculateDirectorySize(item)
                guard let size = size, size > 0 else { continue }

                let cacheItem = CacheItem(
                    url: item,
                    name: name,
                    size: size,
                    category: .systemLevel,
                    lastModified: modDate,
                    displayName: name.replacingOccurrences(of: ".app", with: "")
                )
                items.append(cacheItem)
            }
        }

        return items
    }

    func scanForProjectArtifacts(in directory: URL, progress: @escaping (String, Int) -> Void) async throws -> [ProjectArtifact] {
        reset()

        var artifacts: [ProjectArtifact] = []
        let fileManager = FileManager.default

        let artifactNames = Set(ArtifactType.allCases.map { $0.rawValue })

        // Don't skip hidden files since many artifact types start with dot
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        // Directories to skip entirely (not project dirs)
        let skipDirs: Set<String> = [".git", ".svn", ".hg", "Library", ".Trash", ".cache", ".npm", ".cargo"]

        for case let fileURL as URL in enumerator {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            let name = fileURL.lastPathComponent

            // Skip non-project system directories
            if skipDirs.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            // Skip scanning inside artifact directories
            if artifactNames.contains(name) {
                enumerator.skipDescendants()

                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])

                    guard resourceValues.isDirectory == true else { continue }

                    if let artifactType = ArtifactType.detect(from: name) {
                        progress("Found \(name)", artifacts.count)

                        let size = try await calculateDirectorySize(fileURL)
                        let projectName = fileURL.deletingLastPathComponent().lastPathComponent

                        let artifact = ProjectArtifact(
                            url: fileURL,
                            projectName: projectName,
                            artifactType: artifactType,
                            size: size,
                            lastModified: resourceValues.contentModificationDate
                        )

                        artifacts.append(artifact)
                    }
                } catch {
                    continue
                }
            }
        }

        return artifacts.sorted { $0.size > $1.size }
    }
}
