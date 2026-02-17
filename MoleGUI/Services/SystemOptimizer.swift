import Foundation

actor SystemOptimizer {
    struct OptimizationResult {
        let action: String
        let success: Bool
        let message: String
    }

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    // MARK: - DNS

    func flushDNS() async -> OptimizationResult {
        let result1 = runCommand("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        let result2 = runCommand("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        let success = result1 && result2
        return OptimizationResult(
            action: "Flush DNS Cache",
            success: success,
            message: success ? "DNS cache flushed successfully" : "Failed to flush DNS cache"
        )
    }

    // MARK: - QuickLook

    func refreshQuickLook() async -> OptimizationResult {
        let success = runCommand("/usr/bin/qlmanage", arguments: ["-r", "cache"])
        return OptimizationResult(
            action: "Refresh QuickLook",
            success: success,
            message: success ? "QuickLook cache refreshed" : "Failed to refresh QuickLook cache"
        )
    }

    // MARK: - Saved States

    func cleanSavedStates(olderThanDays: Int = 30) async -> OptimizationResult {
        let savedStateDir = homeDirectory.appendingPathComponent("Library/Saved Application State")
        var removedCount = 0

        guard let contents = try? fileManager.contentsOfDirectory(at: savedStateDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return OptimizationResult(action: "Clean Saved States", success: false, message: "Could not access Saved Application State directory")
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()

        for item in contents where item.pathExtension == "savedState" {
            if let values = try? item.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate < cutoff {
                try? fileManager.removeItem(at: item)
                removedCount += 1
            }
        }

        return OptimizationResult(
            action: "Clean Saved States",
            success: true,
            message: "Removed \(removedCount) old saved state\(removedCount == 1 ? "" : "s")"
        )
    }

    // MARK: - Preferences Repair

    func repairPreferences() async -> OptimizationResult {
        let prefsDir = homeDirectory.appendingPathComponent("Library/Preferences")
        var repairedCount = 0

        guard let contents = try? fileManager.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: nil) else {
            return OptimizationResult(action: "Repair Preferences", success: false, message: "Could not access Preferences directory")
        }

        for item in contents where item.pathExtension == "plist" {
            // Try to read plist; if it fails, it's corrupted
            if let data = try? Data(contentsOf: item) {
                do {
                    _ = try PropertyListSerialization.propertyList(from: data, format: nil)
                } catch {
                    // Corrupted plist - remove it so the app can recreate
                    try? fileManager.removeItem(at: item)
                    repairedCount += 1
                }
            }
        }

        return OptimizationResult(
            action: "Repair Preferences",
            success: true,
            message: repairedCount > 0 ? "Removed \(repairedCount) corrupted preference file\(repairedCount == 1 ? "" : "s")" : "All preference files are healthy"
        )
    }

    // MARK: - SQLite VACUUM

    func vacuumDatabases() async -> OptimizationResult {
        let databases = [
            ("Mail", homeDirectory.appendingPathComponent("Library/Mail/V10/MailData/Envelope Index")),
            ("Safari", homeDirectory.appendingPathComponent("Library/Safari/History.db")),
            ("Messages", homeDirectory.appendingPathComponent("Library/Messages/chat.db")),
        ]

        var vacuumedCount = 0
        for (name, dbPath) in databases {
            guard fileManager.fileExists(atPath: dbPath.path) else { continue }

            // Check if the app is running - skip if so
            if isAppRunning(name) { continue }

            let success = runCommand("/usr/bin/sqlite3", arguments: [dbPath.path, "VACUUM;"])
            if success { vacuumedCount += 1 }
        }

        return OptimizationResult(
            action: "Vacuum Databases",
            success: true,
            message: "Optimized \(vacuumedCount) database\(vacuumedCount == 1 ? "" : "s")"
        )
    }

    // MARK: - LaunchServices

    func rebuildLaunchServices() async -> OptimizationResult {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        let success = runCommand(lsregister, arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
        return OptimizationResult(
            action: "Rebuild LaunchServices",
            success: success,
            message: success ? "LaunchServices database rebuilt (fixes 'Open With' duplicates)" : "Failed to rebuild LaunchServices"
        )
    }

    // MARK: - Font Cache

    func rebuildFontCache() async -> OptimizationResult {
        let success = runCommand("/usr/bin/atsutil", arguments: ["databases", "-remove"])
        return OptimizationResult(
            action: "Rebuild Font Cache",
            success: success,
            message: success ? "Font cache cleared (will rebuild on next use)" : "Failed to clear font cache"
        )
    }

    // MARK: - Memory Pressure

    func relieveMemoryPressure() async -> OptimizationResult {
        let success = runCommand("/usr/bin/purge", arguments: [])
        return OptimizationResult(
            action: "Relieve Memory Pressure",
            success: success,
            message: success ? "Memory pressure relieved" : "Failed (may require admin privileges)"
        )
    }

    // MARK: - Network Optimization

    func optimizeNetwork() async -> OptimizationResult {
        // Flush route table
        let r1 = runCommand("/sbin/route", arguments: ["-n", "flush"])
        // Clear ARP cache
        _ = runCommand("/usr/sbin/arp", arguments: ["-a", "-d"])
        return OptimizationResult(
            action: "Optimize Network",
            success: r1,
            message: r1 ? "Route table and ARP cache flushed" : "Network optimization requires admin privileges"
        )
    }

    // MARK: - Disk Permissions

    func repairDiskPermissions() async -> OptimizationResult {
        let uid = String(getuid())
        let success = runCommand("/usr/sbin/diskutil", arguments: ["resetUserPermissions", "/", uid])
        return OptimizationResult(
            action: "Repair Disk Permissions",
            success: success,
            message: success ? "User permissions repaired" : "Failed to repair permissions"
        )
    }

    // MARK: - Spotlight

    func checkSpotlightHealth() async -> OptimizationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdutil")
        process.arguments = ["-s", "/"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if output.contains("Indexing enabled") {
                return OptimizationResult(action: "Spotlight Health", success: true, message: "Spotlight indexing is healthy")
            } else {
                return OptimizationResult(action: "Spotlight Health", success: false, message: "Spotlight indexing may need attention")
            }
        } catch {
            return OptimizationResult(action: "Spotlight Health", success: false, message: "Could not check Spotlight status")
        }
    }

    // MARK: - Dock Cache

    func refreshDock() async -> OptimizationResult {
        let success = runCommand("/usr/bin/killall", arguments: ["Dock"])
        return OptimizationResult(
            action: "Refresh Dock",
            success: success,
            message: success ? "Dock cache refreshed" : "Failed to refresh Dock"
        )
    }

    // MARK: - Spotlight Rebuild

    func rebuildSpotlight() async -> OptimizationResult {
        let r1 = runCommand("/usr/bin/mdutil", arguments: ["-E", "/"])
        return OptimizationResult(
            action: "Rebuild Spotlight Index",
            success: r1,
            message: r1 ? "Spotlight index rebuild initiated" : "Failed to rebuild Spotlight (may require admin)"
        )
    }

    // MARK: - Bluetooth Restart

    func restartBluetooth() async -> OptimizationResult {
        // Check if any HID or audio devices are connected via Bluetooth
        let btCheck = runCommandOutput("/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-detailLevel", "mini"])

        // Simple heuristic: skip if audio devices are actively connected
        if btCheck.contains("Connected: Yes") && (btCheck.contains("Audio") || btCheck.contains("HID")) {
            return OptimizationResult(
                action: "Restart Bluetooth",
                success: false,
                message: "Skipped: active Bluetooth HID/audio devices detected"
            )
        }

        let success = runCommand("/usr/bin/killall", arguments: ["-HUP", "bluetoothd"])
        return OptimizationResult(
            action: "Restart Bluetooth",
            success: success,
            message: success ? "Bluetooth daemon restarted" : "Failed to restart Bluetooth (may require admin)"
        )
    }

    // MARK: - Security Fixes

    func enableFirewall() async -> OptimizationResult {
        let success = runCommand("/usr/libexec/ApplicationFirewall/socketfilterfw", arguments: ["--setglobalstate", "on"])
        return OptimizationResult(
            action: "Enable Firewall",
            success: success,
            message: success ? "Firewall enabled" : "Failed to enable firewall (requires admin)"
        )
    }

    func enableGatekeeper() async -> OptimizationResult {
        let success = runCommand("/usr/sbin/spctl", arguments: ["--master-enable"])
        return OptimizationResult(
            action: "Enable Gatekeeper",
            success: success,
            message: success ? "Gatekeeper enabled" : "Failed to enable Gatekeeper (requires admin)"
        )
    }

    func enableTouchIdForSudo() async -> OptimizationResult {
        // Check for macOS Sonoma+ sudo_local support
        let sudoLocalPath = "/etc/pam.d/sudo_local"
        let sudoPath = "/etc/pam.d/sudo"

        // Check if already enabled
        if let content = try? String(contentsOfFile: sudoPath, encoding: .utf8),
           content.contains("pam_tid.so") {
            return OptimizationResult(
                action: "Touch ID for Sudo",
                success: true,
                message: "Touch ID for sudo is already enabled"
            )
        }

        if let content = try? String(contentsOfFile: sudoLocalPath, encoding: .utf8),
           content.contains("pam_tid.so") {
            return OptimizationResult(
                action: "Touch ID for Sudo",
                success: true,
                message: "Touch ID for sudo is already enabled (via sudo_local)"
            )
        }

        // For Sonoma+, use sudo_local
        if fileManager.fileExists(atPath: "/etc/pam.d/sudo_local.template") ||
           Foundation.ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 14 {
            let content = "auth       sufficient     pam_tid.so\n"
            do {
                try content.write(toFile: sudoLocalPath, atomically: true, encoding: .utf8)
                return OptimizationResult(
                    action: "Touch ID for Sudo",
                    success: true,
                    message: "Touch ID for sudo enabled via sudo_local"
                )
            } catch {
                return OptimizationResult(
                    action: "Touch ID for Sudo",
                    success: false,
                    message: "Failed: requires admin privileges"
                )
            }
        }

        return OptimizationResult(
            action: "Touch ID for Sudo",
            success: false,
            message: "Manual configuration required for pre-Sonoma macOS"
        )
    }

    // MARK: - macOS Update Check

    func checkForMacOSUpdates() async -> OptimizationResult {
        let output = runCommandOutput("/usr/sbin/softwareupdate", arguments: ["-l", "--no-scan"])

        if output.contains("No new software available") || output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return OptimizationResult(
                action: "macOS Update Check",
                success: true,
                message: "macOS is up to date"
            )
        }

        // Extract update names
        let lines = output.components(separatedBy: .newlines)
        let updates = lines.filter { $0.contains("*") || $0.contains("Label:") }
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let updateList = updates.isEmpty ? "Updates available" : updates.prefix(3).joined(separator: ", ")
        return OptimizationResult(
            action: "macOS Update Check",
            success: false,
            message: updateList
        )
    }

    // MARK: - Icon Services Cache

    func refreshIconServices() async -> OptimizationResult {
        let r1 = runCommand("/usr/bin/killall", arguments: ["Dock"])
        let r2 = runCommand("/usr/bin/killall", arguments: ["-KILL", "lsd"])
        let success = r1 || r2
        return OptimizationResult(
            action: "Refresh Icon Services",
            success: success,
            message: success ? "Icon services cache refreshed" : "Failed to refresh icon services"
        )
    }

    // MARK: - Helpers

    @discardableResult
    private func runCommand(_ path: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func isAppRunning(_ appName: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", appName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func runCommandOutput(_ path: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
