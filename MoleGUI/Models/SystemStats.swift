import Foundation

struct SystemStats {
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var memoryUsed: Int64 = 0
    var memoryTotal: Int64 = 0
    var diskReadSpeed: Int64 = 0
    var diskWriteSpeed: Int64 = 0
    var networkUpSpeed: Int64 = 0
    var networkDownSpeed: Int64 = 0
    var batteryLevel: Int = 100
    var isCharging: Bool = false
    var uptime: TimeInterval = 0

    // Extended fields
    var cpuLoadAverage: (one: Double, five: Double, fifteen: Double) = (0, 0, 0)
    var perCoreCPU: [Double] = []
    var gpuName: String = ""
    var gpuUsage: Double = 0
    var gpuMemoryMB: Int64 = 0
    var batteryCycleCount: Int = 0
    var batteryTemperature: Double = 0
    var batteryCondition: String = "Unknown"
    var batteryIsPresent: Bool = false
    var batteryTimeRemaining: Int = -1 // minutes, -1 = unknown
    var batteryMaxCapacity: Int = 100 // percentage
    var fanRPM: [Int] = []
    var fanCount: Int = 0
    var cpuTemperature: Double = 0
    var gpuTemperature: Double = 0
    var topProcesses: [TopProcess] = []
    var macModel: String = ""
    var chipName: String = ""
    var totalRAM: String = ""
    var memoryPressureLevel: String = "Normal" // Normal/Warning/Critical
    var swapUsedMB: Int64 = 0
    var swapTotalMB: Int64 = 0
    var osVersion: String = ""

    var formattedMemoryUsed: String { ByteFormatter.format(memoryUsed) }
    var formattedMemoryTotal: String { ByteFormatter.format(memoryTotal) }
    var formattedDiskRead: String { ByteFormatter.formatSpeed(diskReadSpeed) }
    var formattedDiskWrite: String { ByteFormatter.formatSpeed(diskWriteSpeed) }
    var formattedNetworkUp: String { ByteFormatter.formatSpeed(networkUpSpeed) }
    var formattedNetworkDown: String { ByteFormatter.formatSpeed(networkDownSpeed) }

    var formattedUptime: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedLoadAverage: String {
        String(format: "%.2f / %.2f / %.2f", cpuLoadAverage.one, cpuLoadAverage.five, cpuLoadAverage.fifteen)
    }

    var formattedBatteryTemp: String {
        String(format: "%.1f\u{00B0}C", batteryTemperature)
    }

    var formattedBatteryTimeRemaining: String {
        guard batteryTimeRemaining >= 0 else { return "Calculating..." }
        let hours = batteryTimeRemaining / 60
        let minutes = batteryTimeRemaining % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        }
        return "\(minutes)m remaining"
    }

    var formattedCPUTemp: String {
        cpuTemperature > 0 ? String(format: "%.0f\u{00B0}C", cpuTemperature) : ""
    }

    var formattedSwap: String {
        swapTotalMB > 0 ? "\(swapUsedMB) MB / \(swapTotalMB) MB" : "\(swapUsedMB) MB"
    }

    // Weighted health score: CPU 30%, Memory 25%, Disk I/O 10%, Thermal 15%, Battery 10%, Pressure 10%
    var healthScore: Int {
        var score = 100.0

        // CPU (30% weight)
        if cpuUsage > 90 { score -= 30 }
        else if cpuUsage > 80 { score -= 20 }
        else if cpuUsage > 60 { score -= 10 }
        else if cpuUsage > 40 { score -= 5 }

        // Memory (25% weight)
        if memoryUsage > 95 { score -= 25 }
        else if memoryUsage > 85 { score -= 18 }
        else if memoryUsage > 75 { score -= 12 }
        else if memoryUsage > 60 { score -= 5 }

        // Thermal (15% weight)
        if cpuTemperature > 95 { score -= 15 }
        else if cpuTemperature > 85 { score -= 10 }
        else if cpuTemperature > 75 { score -= 5 }

        // Battery (10% weight)
        if batteryIsPresent && !isCharging && batteryLevel < 10 { score -= 10 }
        else if batteryIsPresent && !isCharging && batteryLevel < 20 { score -= 5 }

        // Memory Pressure (10% weight)
        if memoryPressureLevel == "Critical" { score -= 10 }
        else if memoryPressureLevel == "Warning" { score -= 5 }

        // Disk I/O (10% weight) - penalize if I/O is very high (sustained)
        let totalIO = diskReadSpeed + diskWriteSpeed
        if totalIO > 500 * 1024 * 1024 { score -= 10 } // > 500 MB/s
        else if totalIO > 200 * 1024 * 1024 { score -= 5 }

        return max(0, min(100, Int(score)))
    }

    var healthStatus: String {
        switch healthScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 55..<75: return "Fair"
        case 30..<55: return "Poor"
        default: return "Critical"
        }
    }
}

struct TopProcess: Identifiable {
    let id = UUID()
    let name: String
    let pid: Int
    let cpuPercent: Double
    let memoryMB: Double
}

struct CPUHistory {
    var samples: [Double] = []
    let maxSamples = 60

    mutating func addSample(_ value: Double) {
        samples.append(value)
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }
}

struct MemoryHistory {
    var samples: [Double] = []
    let maxSamples = 60

    mutating func addSample(_ value: Double) {
        samples.append(value)
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }
}

struct NetworkHistory {
    var uploadSamples: [Int64] = []
    var downloadSamples: [Int64] = []
    let maxSamples = 60

    mutating func addSample(upload: Int64, download: Int64) {
        uploadSamples.append(upload)
        downloadSamples.append(download)
        if uploadSamples.count > maxSamples {
            uploadSamples.removeFirst()
            downloadSamples.removeFirst()
        }
    }
}

struct DiskIOHistory {
    var readSamples: [Int64] = []
    var writeSamples: [Int64] = []
    let maxSamples = 60

    mutating func addSample(read: Int64, write: Int64) {
        readSamples.append(read)
        writeSamples.append(write)
        if readSamples.count > maxSamples {
            readSamples.removeFirst()
            writeSamples.removeFirst()
        }
    }
}
