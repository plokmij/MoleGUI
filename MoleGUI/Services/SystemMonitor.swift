import Foundation
import Combine
import Darwin
import IOKit
import IOKit.ps

@MainActor
class SystemMonitor: ObservableObject {
    @Published var stats = SystemStats()
    @Published var cpuHistory = CPUHistory()
    @Published var memoryHistory = MemoryHistory()
    @Published var networkHistory = NetworkHistory()
    @Published var diskIOHistory = DiskIOHistory()
    @Published var isMonitoring = false

    private var timer: AnyCancellable?
    private var previousNetworkIn: Int64 = 0
    private var previousNetworkOut: Int64 = 0
    private var hardwareInfoLoaded = false

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Load static hardware info once
        if !hardwareInfoLoaded {
            loadHardwareInfo()
            hardwareInfoLoaded = true
        }

        // Initial update
        updateStats()

        // Update every second
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        isMonitoring = false
    }

    private func updateStats() {
        let (totalCPU, perCore) = getCPUUsage()
        stats.cpuUsage = totalCPU
        stats.perCoreCPU = perCore
        (stats.memoryUsed, stats.memoryTotal, stats.memoryUsage) = getMemoryUsage()
        stats.uptime = getUptime()
        stats.cpuLoadAverage = getLoadAverage()

        // Battery
        let batteryInfo = getBatteryInfo()
        stats.batteryLevel = batteryInfo.level
        stats.isCharging = batteryInfo.isCharging
        stats.batteryCycleCount = batteryInfo.cycleCount
        stats.batteryTemperature = batteryInfo.temperature
        stats.batteryCondition = batteryInfo.condition
        stats.batteryIsPresent = batteryInfo.isPresent

        // Network stats
        let (netIn, netOut) = getNetworkBytes()
        if previousNetworkIn > 0 {
            stats.networkDownSpeed = netIn - previousNetworkIn
            stats.networkUpSpeed = netOut - previousNetworkOut
        }
        previousNetworkIn = netIn
        previousNetworkOut = netOut

        // Top processes (update every 5 seconds to reduce overhead)
        if Int(stats.uptime) % 5 == 0 {
            stats.topProcesses = getTopProcesses()
        }

        // Update histories
        cpuHistory.addSample(stats.cpuUsage)
        memoryHistory.addSample(stats.memoryUsage)
        networkHistory.addSample(upload: stats.networkUpSpeed, download: stats.networkDownSpeed)
        diskIOHistory.addSample(read: stats.diskReadSpeed, write: stats.diskWriteSpeed)
    }

    // MARK: - Hardware Info (static, loaded once)

    private func loadHardwareInfo() {
        stats.macModel = getModelName()
        stats.chipName = getChipName()
        stats.totalRAM = ByteFormatter.format(Int64(Foundation.ProcessInfo.processInfo.physicalMemory))
        stats.gpuName = getGPUName()
    }

    private func getModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func getChipName() -> String {
        #if arch(arm64)
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let result = String(cString: brand)
        return result.isEmpty ? "Apple Silicon" : result
        #else
        return "Intel"
        #endif
    }

    private func getGPUName() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPDisplaysDataType", "-detailLevel", "mini"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Chipset Model:") || trimmed.hasPrefix("Chip:") {
                        return trimmed.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    }
                }
            }
        } catch {}
        return ""
    }

    // MARK: - CPU

    private func getCPUUsage() -> (total: Double, perCore: [Double]) {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let err = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &cpuInfo,
            &numCpuInfo
        )

        guard err == KERN_SUCCESS, let info = cpuInfo else {
            return (0, [])
        }

        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0
        var perCore: [Double] = []

        for i in 0..<Int(numCpus) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = info[offset + Int(CPU_STATE_USER)]
            let system = info[offset + Int(CPU_STATE_SYSTEM)]
            let idle = info[offset + Int(CPU_STATE_IDLE)]

            totalUser += user
            totalSystem += system
            totalIdle += idle

            let coreTotal = user + system + idle
            if coreTotal > 0 {
                perCore.append(Double(user + system) / Double(coreTotal) * 100.0)
            } else {
                perCore.append(0)
            }
        }

        let total = totalUser + totalSystem + totalIdle
        let usage = total > 0 ? Double(totalUser + totalSystem) / Double(total) * 100.0 : 0

        // Deallocate
        let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        return (min(100, max(0, usage)), perCore)
    }

    // MARK: - Load Average

    private func getLoadAverage() -> (one: Double, five: Double, fifteen: Double) {
        var loadavg = [Double](repeating: 0, count: 3)
        getloadavg(&loadavg, 3)
        return (loadavg[0], loadavg[1], loadavg[2])
    }

    // MARK: - Memory

    private func getMemoryUsage() -> (used: Int64, total: Int64, percentage: Double) {
        let processInfo = Foundation.ProcessInfo.processInfo
        let totalMemory = Int64(processInfo.physicalMemory)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, totalMemory, 0)
        }

        let pageSize = Int64(vm_kernel_page_size)
        let activeMemory = Int64(vmStats.active_count) * pageSize
        let wiredMemory = Int64(vmStats.wire_count) * pageSize
        let compressedMemory = Int64(vmStats.compressor_page_count) * pageSize

        let usedMemory = activeMemory + wiredMemory + compressedMemory
        let percentage = Double(usedMemory) / Double(totalMemory) * 100.0

        return (usedMemory, totalMemory, min(100, max(0, percentage)))
    }

    // MARK: - Uptime

    private func getUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let now = Date().timeIntervalSince1970
            return now - Double(boottime.tv_sec)
        }

        return 0
    }

    // MARK: - Battery (IOKit)

    private struct BatteryInfo {
        var level: Int = 100
        var isCharging: Bool = false
        var cycleCount: Int = 0
        var temperature: Double = 0
        var condition: String = "Unknown"
        var isPresent: Bool = false
    }

    private func getBatteryInfo() -> BatteryInfo {
        var info = BatteryInfo()

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
            return info
        }

        info.isPresent = true

        if let capacity = description[kIOPSCurrentCapacityKey] as? Int {
            info.level = capacity
        }
        if let isCharging = description[kIOPSIsChargingKey] as? Bool {
            info.isCharging = isCharging
        }

        // Get extended battery info from IOKit
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }

            if let cycleCount = getIORegistryValue(service: service, key: "CycleCount") as? Int {
                info.cycleCount = cycleCount
            }
            if let temp = getIORegistryValue(service: service, key: "Temperature") as? Int {
                info.temperature = Double(temp) / 100.0
            }
            if let condition = getIORegistryValue(service: service, key: "BatteryHealthCondition") as? String {
                info.condition = condition
            } else {
                info.condition = "Normal"
            }
        }

        return info
    }

    private func getIORegistryValue(service: io_service_t, key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    // MARK: - Network

    private func getNetworkBytes() -> (bytesIn: Int64, bytesOut: Int64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }

        var bytesIn: Int64 = 0
        var bytesOut: Int64 = 0

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee

            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = interface.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    bytesIn += Int64(networkData.ifi_ibytes)
                    bytesOut += Int64(networkData.ifi_obytes)
                }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }

        freeifaddrs(ifaddr)

        return (bytesIn, bytesOut)
    }

    // MARK: - Top Processes

    private func getTopProcesses() -> [TopProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["aux"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var processes: [TopProcess] = []
            let lines = output.components(separatedBy: .newlines).dropFirst() // Skip header

            for line in lines {
                let parts = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
                guard parts.count >= 11 else { continue }

                let cpuPercent = Double(parts[2]) ?? 0
                guard cpuPercent > 0.1 else { continue } // Skip idle processes

                let pid = Int(parts[1]) ?? 0
                let memPercent = Double(parts[3]) ?? 0
                let totalMemBytes = Foundation.ProcessInfo.processInfo.physicalMemory
                let totalMem = Double(totalMemBytes) / (1024 * 1024)
                let memMB = totalMem * memPercent / 100.0
                let name = String(parts[10])
                    .components(separatedBy: "/").last ?? String(parts[10])

                processes.append(TopProcess(
                    name: name,
                    pid: pid,
                    cpuPercent: cpuPercent,
                    memoryMB: memMB
                ))
            }

            return Array(processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(8))
        } catch {
            return []
        }
    }
}
