import Foundation

actor CacheManager {
    enum CleanError: Error, LocalizedError {
        case deletionFailed(URL, Error)
        case accessDenied(URL)
        case protectedPath(URL)

        var errorDescription: String? {
            switch self {
            case .deletionFailed(let url, let error):
                return "Failed to delete \(url.path): \(error.localizedDescription)"
            case .accessDenied(let url):
                return "Access denied to \(url.path)"
            case .protectedPath(let url):
                return "Cannot delete protected path: \(url.path)"
            }
        }
    }

    struct CleanResult {
        let deletedCount: Int
        let deletedSize: Int64
        let errors: [CleanError]

        var hadErrors: Bool { !errors.isEmpty }
    }

    private let fileManager = FileManager.default

    func cleanItems(_ items: [CacheItem], dryRun: Bool = false) async throws -> CleanResult {
        var deletedCount = 0
        var deletedSize: Int64 = 0
        var errors: [CleanError] = []

        for item in items where item.isSelected {
            // Check if path is protected
            if Whitelist.isProtected(item.url) {
                errors.append(.protectedPath(item.url))
                continue
            }

            if dryRun {
                deletedCount += 1
                deletedSize += item.size
            } else {
                do {
                    try await deleteItem(item.url)
                    deletedCount += 1
                    deletedSize += item.size
                } catch {
                    errors.append(.deletionFailed(item.url, error))
                }
            }
        }

        return CleanResult(deletedCount: deletedCount, deletedSize: deletedSize, errors: errors)
    }

    func cleanCategories(_ categories: [CacheCategoryResult], dryRun: Bool = false) async throws -> CleanResult {
        var totalDeleted = 0
        var totalSize: Int64 = 0
        var allErrors: [CleanError] = []

        for category in categories {
            let result = try await cleanItems(category.items, dryRun: dryRun)
            totalDeleted += result.deletedCount
            totalSize += result.deletedSize
            allErrors.append(contentsOf: result.errors)
        }

        return CleanResult(deletedCount: totalDeleted, deletedSize: totalSize, errors: allErrors)
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

        try fileManager.removeItem(at: url)
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

        return size
    }
}
