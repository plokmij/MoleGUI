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
                        lastModified: try? FileManager.default.attributesOfItem(atPath: location.path.path)[.modificationDate] as? Date
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

    func scanForProjectArtifacts(in directory: URL, progress: @escaping (String, Int) -> Void) async throws -> [ProjectArtifact] {
        reset()

        var artifacts: [ProjectArtifact] = []
        let fileManager = FileManager.default

        let artifactNames = Set(ArtifactType.allCases.map { $0.rawValue })

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            let name = fileURL.lastPathComponent

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
