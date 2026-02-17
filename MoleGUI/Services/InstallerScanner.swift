import Foundation

actor InstallerScanner {
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    private var isCancelled = false

    func cancel() { isCancelled = true }
    func reset() { isCancelled = false }

    /// All scan locations with their source labels
    private var scanLocations: [(url: URL, source: InstallerSource)] {
        [
            (homeDirectory.appendingPathComponent("Downloads"), .downloads),
            (homeDirectory.appendingPathComponent("Desktop"), .desktop),
            (homeDirectory.appendingPathComponent("Documents"), .documents),
            (homeDirectory.appendingPathComponent("Public"), .publicFolder),
            (homeDirectory.appendingPathComponent("Library/Downloads"), .libraryDownloads),
            (URL(fileURLWithPath: "/Users/Shared"), .shared),
            (homeDirectory.appendingPathComponent("Library/Caches/Homebrew/downloads"), .homebrew),
            // iCloud Downloads
            (homeDirectory.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Downloads"), .iCloud),
            // Mail Downloads
            (homeDirectory.appendingPathComponent("Library/Mail Downloads"), .mail),
            (homeDirectory.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"), .mail),
        ]
    }

    func scan(progress: @escaping (String, Double) -> Void) async -> [InstallerItem] {
        reset()

        var items: [InstallerItem] = []
        let locations = scanLocations
        let total = locations.count

        for (index, location) in locations.enumerated() {
            guard !isCancelled else { break }
            guard fileManager.fileExists(atPath: location.url.path) else { continue }

            progress("Scanning \(location.source.rawValue)...", Double(index) / Double(total))

            let found = scanDirectory(location.url, source: location.source)
            items.append(contentsOf: found)
        }

        progress("Scan complete", 1.0)
        return items.sorted { $0.size > $1.size }
    }

    private func scanDirectory(_ url: URL, source: InstallerSource) -> [InstallerItem] {
        var items: [InstallerItem] = []

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: nil
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else { break }

            let ext = fileURL.pathExtension.lowercased()
            guard InstallerFileType.nonZipExtensions.contains(ext) || ext == "zip" else { continue }

            // For .zip files, check if they contain installer payloads
            if ext == "zip" {
                guard isInstallerZip(fileURL) else { continue }
            }

            guard let fileType = InstallerFileType(rawValue: ".\(ext)") else { continue }

            let size: Int64
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                size = Int64(fileSize)
            } else {
                size = 0
            }

            guard size > 0 else { continue }

            let item = InstallerItem(
                url: fileURL,
                fileName: fileURL.lastPathComponent,
                size: size,
                source: source,
                fileType: fileType,
                isSelected: true
            )
            items.append(item)
        }

        return items
    }

    /// Inspects first entries of a ZIP to detect installer payloads
    private func isInstallerZip(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        process.arguments = ["-1", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return false }

            let lines = output.components(separatedBy: .newlines).prefix(50)
            let installerExtensions = ["app", "pkg", "dmg", "mpkg"]

            for line in lines {
                let ext = (line as NSString).pathExtension.lowercased()
                if installerExtensions.contains(ext) {
                    return true
                }
            }
        } catch {}

        return false
    }

    func deleteItems(_ items: [InstallerItem]) async throws -> Int64 {
        var freedSpace: Int64 = 0

        for item in items {
            guard !Whitelist.isProtected(item.url) else { continue }

            do {
                try await MainActor.run {
                    var trashedURL: NSURL?
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashedURL)
                }
                freedSpace += item.size
            } catch {
                continue
            }
        }

        return freedSpace
    }
}
