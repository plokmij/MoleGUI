import Foundation

actor DiskAnalyzer {
    private let fileManager = FileManager.default
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func reset() {
        isCancelled = false
    }

    func getDiskUsage() -> DiskUsageInfo {
        guard let attributes = try? fileManager.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) else {
            return DiskUsageInfo(totalSpace: 0, freeSpace: 0, usedSpace: 0)
        }

        let totalSpace = (attributes[.systemSize] as? Int64) ?? 0
        let freeSpace = (attributes[.systemFreeSize] as? Int64) ?? 0
        let usedSpace = totalSpace - freeSpace

        return DiskUsageInfo(totalSpace: totalSpace, freeSpace: freeSpace, usedSpace: usedSpace)
    }

    func analyzeDirectory(
        _ url: URL,
        maxDepth: Int = 3,
        progress: @escaping (String, Double) -> Void
    ) async throws -> DiskItem {
        reset()

        progress("Analyzing \(url.lastPathComponent)...", 0)

        let rootItem = try await analyzeRecursive(url: url, depth: 0, maxDepth: maxDepth, progress: progress)

        progress("Analysis complete", 1.0)

        return rootItem
    }

    private func analyzeRecursive(
        url: URL,
        depth: Int,
        maxDepth: Int,
        progress: @escaping (String, Double) -> Void
    ) async throws -> DiskItem {
        guard !isCancelled else {
            throw FileScanner.ScanError.scanCancelled
        }

        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDirectory = resourceValues.isDirectory ?? false

        if !isDirectory {
            return DiskItem(
                url: url,
                name: url.lastPathComponent,
                size: Int64(resourceValues.fileSize ?? 0),
                isDirectory: false,
                children: nil,
                depth: depth
            )
        }

        // For directories, get children
        var children: [DiskItem]?
        var totalSize: Int64 = 0

        if depth < maxDepth {
            let contents = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            var childItems: [DiskItem] = []

            for childURL in contents {
                guard !isCancelled else {
                    throw FileScanner.ScanError.scanCancelled
                }

                if depth == 0 {
                    progress("Analyzing \(childURL.lastPathComponent)...", Double(childItems.count) / Double(contents.count))
                }

                let childItem = try await analyzeRecursive(
                    url: childURL,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    progress: progress
                )
                childItems.append(childItem)
                totalSize += childItem.size
            }

            children = childItems.sorted { $0.size > $1.size }
        } else {
            // At max depth, just calculate size without children
            totalSize = try await calculateSize(of: url)
        }

        return DiskItem(
            url: url,
            name: url.lastPathComponent,
            size: totalSize,
            isDirectory: true,
            children: children,
            depth: depth
        )
    }

    private func calculateSize(of url: URL) async throws -> Int64 {
        var totalSize: Int64 = 0

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
                throw FileScanner.ScanError.scanCancelled
            }

            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               resourceValues.isDirectory == false {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }

    func getLargestItems(in item: DiskItem, count: Int = 10) -> [DiskItem] {
        var allItems: [DiskItem] = []
        collectItems(from: item, into: &allItems)
        return Array(allItems.sorted { $0.size > $1.size }.prefix(count))
    }

    private func collectItems(from item: DiskItem, into items: inout [DiskItem]) {
        if !item.isDirectory {
            items.append(item)
        }

        if let children = item.children {
            for child in children {
                collectItems(from: child, into: &items)
            }
        }
    }

    func getItemsByCategory(in item: DiskItem) -> [(category: String, size: Int64, color: String)] {
        var categories: [String: Int64] = [:]

        collectByCategory(from: item, into: &categories)

        let categoryColors: [String: String] = [
            "Applications": "blue",
            "Documents": "green",
            "Media": "red",
            "Archives": "orange",
            "Code": "purple",
            "Other": "gray"
        ]

        return categories.map { (category: $0.key, size: $0.value, color: categoryColors[$0.key] ?? "gray") }
            .sorted { $0.size > $1.size }
    }

    private func collectByCategory(from item: DiskItem, into categories: inout [String: Int64]) {
        if !item.isDirectory {
            let category = categorize(item)
            categories[category, default: 0] += item.size
        }

        if let children = item.children {
            for child in children {
                collectByCategory(from: child, into: &categories)
            }
        }
    }

    private func categorize(_ item: DiskItem) -> String {
        let ext = item.url.pathExtension.lowercased()

        switch ext {
        case "app": return "Applications"
        case "doc", "docx", "pdf", "txt", "rtf", "pages", "xls", "xlsx", "ppt", "pptx", "key", "numbers":
            return "Documents"
        case "jpg", "jpeg", "png", "gif", "heic", "mp4", "mov", "mp3", "wav", "m4a":
            return "Media"
        case "zip", "tar", "gz", "rar", "7z", "dmg", "pkg":
            return "Archives"
        case "swift", "js", "ts", "py", "rb", "go", "rs", "c", "cpp", "h", "java", "kt":
            return "Code"
        default:
            return "Other"
        }
    }
}
