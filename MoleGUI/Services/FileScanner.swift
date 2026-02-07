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

        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }

        var totalSize: Int64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else {
                throw ScanError.scanCancelled
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return totalSize
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

            scannedLocations += 1
        }

        progress("Scan complete", 1.0)

        return results.map { category, items in
            CacheCategoryResult(category: category, items: items)
        }.sorted { $0.totalSize > $1.totalSize }
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
