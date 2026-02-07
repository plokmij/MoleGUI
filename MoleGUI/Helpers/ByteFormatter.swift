import Foundation

enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    static func format(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }

        let doubleBytes = Double(bytes)
        var unitIndex = 0
        var size = doubleBytes

        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        } else if size >= 100 {
            return String(format: "%.0f %@", size, units[unitIndex])
        } else if size >= 10 {
            return String(format: "%.1f %@", size, units[unitIndex])
        } else {
            return String(format: "%.2f %@", size, units[unitIndex])
        }
    }

    static func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatted = format(bytesPerSecond)
        return "\(formatted)/s"
    }

    static func parse(_ string: String) -> Int64? {
        let trimmed = string.trimmingCharacters(in: .whitespaces).uppercased()

        let patterns: [(suffix: String, multiplier: Int64)] = [
            ("PB", 1024 * 1024 * 1024 * 1024 * 1024),
            ("TB", 1024 * 1024 * 1024 * 1024),
            ("GB", 1024 * 1024 * 1024),
            ("MB", 1024 * 1024),
            ("KB", 1024),
            ("B", 1)
        ]

        for (suffix, multiplier) in patterns {
            if trimmed.hasSuffix(suffix) {
                let numberPart = trimmed.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
                if let value = Double(numberPart) {
                    return Int64(value * Double(multiplier))
                }
            }
        }

        return Int64(trimmed)
    }
}
