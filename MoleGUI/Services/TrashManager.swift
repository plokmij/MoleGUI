import Foundation
import AppKit

actor TrashManager {
    private let fileManager = FileManager.default

    enum TrashError: Error, LocalizedError {
        case moveToTrashFailed(URL, Error)
        case emptyTrashFailed(Error)
        case accessDenied
        case scriptError(String)

        var errorDescription: String? {
            switch self {
            case .moveToTrashFailed(let url, let error):
                return "Failed to move \(url.lastPathComponent) to Trash: \(error.localizedDescription)"
            case .emptyTrashFailed(let error):
                return "Failed to empty Trash: \(error.localizedDescription)"
            case .accessDenied:
                return "Access denied"
            case .scriptError(let message):
                return "Script error: \(message)"
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
        // Get size before emptying
        let size = await getTrashSize()

        // Use osascript to empty trash via Finder
        let script = "tell application \"Finder\" to empty trash"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw TrashError.emptyTrashFailed(NSError(domain: "TrashManager", code: Int(process.terminationStatus)))
            }
        } catch let error as TrashError {
            throw error
        } catch {
            throw TrashError.emptyTrashFailed(error)
        }

        return size
    }

    func getTrashSize() async -> Int64 {
        // Use osascript to get trash size from Finder
        let script = """
            tell application "Finder"
                set trashSize to 0
                try
                    set trashItems to items of trash
                    repeat with trashItem in trashItems
                        try
                            set trashSize to trashSize + (size of trashItem)
                        end try
                    end repeat
                end try
                return trashSize
            end tell
            """

        guard let output = runOsascript(script) else { return 0 }
        return Int64(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func getTrashItemCount() async -> Int {
        // Use osascript to get trash item count from Finder
        let script = "tell application \"Finder\" to return count of items of trash"

        guard let output = runOsascript(script) else { return 0 }
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func runOsascript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
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
