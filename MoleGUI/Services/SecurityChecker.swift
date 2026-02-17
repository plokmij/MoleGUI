import Foundation

actor SecurityChecker {
    struct SecurityStatus {
        var fileVaultEnabled: Bool = false
        var firewallEnabled: Bool = false
        var gatekeeperEnabled: Bool = false
        var sipEnabled: Bool = false
        var touchIdForSudo: Bool = false

        var allSecure: Bool {
            fileVaultEnabled && firewallEnabled && gatekeeperEnabled && sipEnabled
        }

        var securityScore: Int {
            var score = 0
            if fileVaultEnabled { score += 25 }
            if firewallEnabled { score += 25 }
            if gatekeeperEnabled { score += 25 }
            if sipEnabled { score += 25 }
            return score
        }
    }

    struct SystemHealth {
        var diskUsedPercent: Double = 0
        var memoryPressure: String = "Normal"
        var swapUsedMB: Int64 = 0
        var loginItemsCount: Int = 0
        var cacheSize: Int64 = 0

        var diskWarning: Bool { diskUsedPercent > 85 }
        var memoryWarning: Bool { memoryPressure != "Normal" }
        var swapWarning: Bool { swapUsedMB > 1024 }
    }

    func checkSecurity() async -> SecurityStatus {
        var status = SecurityStatus()

        status.fileVaultEnabled = checkFileVault()
        status.firewallEnabled = checkFirewall()
        status.gatekeeperEnabled = checkGatekeeper()
        status.sipEnabled = checkSIP()
        status.touchIdForSudo = checkTouchIdSudo()

        return status
    }

    func checkSystemHealth() async -> SystemHealth {
        var health = SystemHealth()

        health.diskUsedPercent = getDiskUsage()
        health.memoryPressure = getMemoryPressure()
        health.swapUsedMB = getSwapUsage()
        health.loginItemsCount = getLoginItemsCount()

        return health
    }

    // MARK: - Security Checks

    private func checkFileVault() -> Bool {
        let output = runCommandOutput("/usr/bin/fdesetup", arguments: ["status"])
        return output.contains("FileVault is On")
    }

    private func checkFirewall() -> Bool {
        let output = runCommandOutput("/usr/libexec/ApplicationFirewall/socketfilterfw", arguments: ["--getglobalstate"])
        return output.contains("enabled")
    }

    private func checkGatekeeper() -> Bool {
        let output = runCommandOutput("/usr/sbin/spctl", arguments: ["--status"])
        return output.contains("assessments enabled")
    }

    private func checkSIP() -> Bool {
        let output = runCommandOutput("/usr/bin/csrutil", arguments: ["status"])
        return output.contains("enabled")
    }

    private func checkTouchIdSudo() -> Bool {
        let sudoPath = "/etc/pam.d/sudo"
        guard let content = try? String(contentsOfFile: sudoPath, encoding: .utf8) else { return false }
        return content.contains("pam_tid.so")
    }

    // MARK: - Health Checks

    private func getDiskUsage() -> Double {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            guard total > 0 else { return 0 }
            return Double(total - free) / Double(total) * 100.0
        } catch {
            return 0
        }
    }

    private func getMemoryPressure() -> String {
        let output = runCommandOutput("/usr/bin/memory_pressure", arguments: ["-Q"])
        if output.contains("critical") { return "Critical" }
        if output.contains("warn") { return "Warning" }
        return "Normal"
    }

    private func getSwapUsage() -> Int64 {
        let output = runCommandOutput("/usr/sbin/sysctl", arguments: ["vm.swapusage"])
        // Parse output like "vm.swapusage: total = 2048.00M  used = 123.45M  free = 1924.55M"
        guard let usedRange = output.range(of: "used = ") else { return 0 }
        let afterUsed = output[usedRange.upperBound...]
        guard let mRange = afterUsed.range(of: "M") else { return 0 }
        let numberStr = afterUsed[..<mRange.lowerBound].trimmingCharacters(in: .whitespaces)
        return Int64(Double(numberStr) ?? 0)
    }

    private func getLoginItemsCount() -> Int {
        let output = runCommandOutput("/usr/bin/osascript", arguments: [
            "-e", "tell application \"System Events\" to get the name of every login item"
        ])
        if output.isEmpty { return 0 }
        return output.components(separatedBy: ", ").count
    }

    // MARK: - Helpers

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
