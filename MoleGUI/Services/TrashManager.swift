import Foundation
import AppKit

actor TrashManager {
    private let fileManager = FileManager.default

    enum TrashError: Error, LocalizedError {
        case moveToTrashFailed(URL, Error)
        case emptyTrashFailed(Error)
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .moveToTrashFailed(let url, let error):
                return "Failed to move \(url.lastPathComponent) to Trash: \(error.localizedDescription)"
            case .emptyTrashFailed(let error):
                return "Failed to empty Trash: \(error.localizedDescription)"
            case .accessDenied:
                return "Access denied"
            }
        }
    }

    func moveToTrash(_ urls: [URL]) async throws -> Int64 {
        var totalSize: Int64 = 0

        for url in urls {
            // Skip protected paths
            guard !Whitelist.isProtected(url) else {
                continue
            }

            do {
                // Calculate size before moving
                let size = try await getSize(of: url)

                // Move to trash on main thread
                try await MainActor.run {
                    var trashedURL: NSURL?
                    try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
                }

                totalSize += size
            } catch {
                throw TrashError.moveToTrashFailed(url, error)
            }
        }

        return totalSize
    }

    func emptyTrash() async throws -> Int64 {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")

        guard fileManager.fileExists(atPath: trashURL.path) else {
            return 0
        }

        // Calculate size before emptying
        let size = try await getSize(of: trashURL)

        // Get all items in trash
        let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)

        for item in contents {
            do {
                try fileManager.removeItem(at: item)
            } catch {
                throw TrashError.emptyTrashFailed(error)
            }
        }

        return size
    }

    func getTrashSize() async -> Int64 {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        return (try? await getSize(of: trashURL)) ?? 0
    }

    func getTrashItemCount() -> Int {
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")

        guard let contents = try? fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil) else {
            return 0
        }

        return contents.count
    }

    private func getSize(of url: URL) async throws -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? Int64) ?? 0
        }

        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }

    func revealInFinder(_ url: URL) async {
        await MainActor.run {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
}
