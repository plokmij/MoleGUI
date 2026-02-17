import Foundation

actor OperationLogger {
    static let shared = OperationLogger()

    private let logDirectory: URL
    private let logFile: URL
    private let maxLogSize: Int64 = 10 * 1024 * 1024 // 10 MB

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logDirectory = home.appendingPathComponent(".config/mole")
        logFile = logDirectory.appendingPathComponent("operations.log")
    }

    /// Logs a file operation with timestamp
    func log(_ operation: String, path: String, size: Int64? = nil, success: Bool = true) {
        ensureLogDirectory()

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let status = success ? "OK" : "FAIL"
        let sizeStr = size.map { " [\(ByteFormatter.format($0))]" } ?? ""
        let entry = "[\(timestamp)] \(status) \(operation): \(path)\(sizeStr)\n"

        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }

        rotateIfNeeded()
    }

    /// Logs a batch clean operation
    func logClean(items: [(path: String, size: Int64)], dryRun: Bool) {
        let prefix = dryRun ? "DRY-RUN" : "DELETE"
        for item in items {
            log(prefix, path: item.path, size: item.size)
        }
    }

    /// Returns recent log entries
    func recentEntries(count: Int = 100) -> [String] {
        guard let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return []
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }

    /// Clears the operation log
    func clearLog() {
        try? FileManager.default.removeItem(at: logFile)
    }

    private func ensureLogDirectory() {
        if !FileManager.default.fileExists(atPath: logDirectory.path) {
            try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let size = attrs[.size] as? Int64,
              size > maxLogSize else { return }

        let backupURL = logDirectory.appendingPathComponent("operations.log.1")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: logFile, to: backupURL)
    }
}
