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

    // New fields
    var cpuLoadAverage: (one: Double, five: Double, fifteen: Double) = (0, 0, 0)
    var perCoreCPU: [Double] = []
    var gpuName: String = ""
    var batteryCycleCount: Int = 0
    var batteryTemperature: Double = 0
    var batteryCondition: String = "Unknown"
    var batteryIsPresent: Bool = false
    var fanRPM: [Int] = []
    var topProcesses: [TopProcess] = []
    var macModel: String = ""
    var chipName: String = ""
    var totalRAM: String = ""

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

    var healthScore: Int {
        var score = 100

        // Deduct for high CPU usage
        if cpuUsage > 80 { score -= 20 }
        else if cpuUsage > 50 { score -= 10 }

        // Deduct for high memory usage
        if memoryUsage > 90 { score -= 25 }
        else if memoryUsage > 75 { score -= 15 }
        else if memoryUsage > 60 { score -= 5 }

        // Deduct for low battery
        if !isCharging && batteryLevel < 20 { score -= 10 }

        return max(0, min(100, score))
    }

    var healthStatus: String {
        switch healthScore {
        case 90...100: return "Excellent"
        case 70..<90: return "Good"
        case 50..<70: return "Fair"
        default: return "Poor"
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
