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

        // Load static hardware info once (off main thread for system_profiler)
        if !hardwareInfoLoaded {
            hardwareInfoLoaded = true
            Task.detached { [weak self] in
                let gpu = Self.getGPUNameAsync()
                await self?.applyHardwareInfo(gpuName: gpu)
            }
            // Load non-blocking hardware info immediately
            stats.macModel = getModelName()
            stats.chipName = getChipName()
            stats.totalRAM = ByteFormatter.format(Int64(Foundation.ProcessInfo.processInfo.physicalMemory))
            let v = Foundation.ProcessInfo.processInfo.operatingSystemVersion
            stats.osVersion = "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        }

        // Initial update (non-blocking parts only, shell commands run async)
        updateStatsNonBlocking()
        scheduleAsyncStats()

        // Update every second
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStatsNonBlocking()
                self?.scheduleAsyncStats()
            }
    }

    private func applyHardwareInfo(gpuName: String) {
        stats.gpuName = gpuName
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        isMonitoring = false
    }

    private var previousDiskReadBytes: Int64 = 0
    private var previousDiskWriteBytes: Int64 = 0

    /// Updates stats that use only Mach/IOKit/sysctl (no shell commands) — safe on main thread
    private func updateStatsNonBlocking() {
        let (totalCPU, perCore) = getCPUUsage()
        stats.cpuUsage = totalCPU
        stats.perCoreCPU = perCore
        (stats.memoryUsed, stats.memoryTotal, stats.memoryUsage) = getMemoryUsage()
        stats.uptime = getUptime()
        stats.cpuLoadAverage = getLoadAverage()

        // Battery (IOKit — fast)
        let batteryInfo = getBatteryInfo()
        stats.batteryLevel = batteryInfo.level
        stats.isCharging = batteryInfo.isCharging
        stats.batteryCycleCount = batteryInfo.cycleCount
        stats.batteryTemperature = batteryInfo.temperature
        stats.batteryCondition = batteryInfo.condition
        stats.batteryIsPresent = batteryInfo.isPresent
        stats.batteryTimeRemaining = batteryInfo.timeRemaining
        stats.batteryMaxCapacity = batteryInfo.maxCapacity

        // Network stats (getifaddrs — fast)
        let (netIn, netOut) = getNetworkBytes()
        if previousNetworkIn > 0 {
            stats.networkDownSpeed = netIn - previousNetworkIn
            stats.networkUpSpeed = netOut - previousNetworkOut
        }
        previousNetworkIn = netIn
        previousNetworkOut = netOut

        // Update histories
        cpuHistory.addSample(stats.cpuUsage)
        memoryHistory.addSample(stats.memoryUsage)
        networkHistory.addSample(upload: stats.networkUpSpeed, download: stats.networkDownSpeed)
        diskIOHistory.addSample(read: stats.diskReadSpeed, write: stats.diskWriteSpeed)
    }

    /// Runs shell-based stats off the main thread and publishes results back
    private func scheduleAsyncStats() {
        let uptime = stats.uptime
        let prevDiskRead = previousDiskReadBytes
        let prevDiskWrite = previousDiskWriteBytes

        Task.detached { [weak self] in
            // Disk I/O (iostat) — every tick
            let (diskRead, diskWrite) = Self.getDiskIOBytesAsync()

            // Thermals — every 3 seconds
            var thermals: SystemMonitor.ThermalInfo?
            if Int(uptime) % 3 == 0 {
                thermals = Self.getThermalInfoAsync()
            }

            // Memory pressure, swap, top processes — every 5 seconds
            var memPressure: String?
            var swapInfo: (used: Int64, total: Int64)?
            var topProcs: [TopProcess]?
            if Int(uptime) % 5 == 0 {
                memPressure = Self.getMemoryPressureAsync()
                swapInfo = Self.getSwapInfoAsync()
                topProcs = Self.getTopProcessesAsync()
            }

            await self?.applyAsyncStats(
                diskRead: diskRead, diskWrite: diskWrite,
                prevDiskRead: prevDiskRead, prevDiskWrite: prevDiskWrite,
                thermals: thermals, memPressure: memPressure,
                swapInfo: swapInfo, topProcs: topProcs
            )
        }
    }

    private func applyAsyncStats(
        diskRead: Int64, diskWrite: Int64,
        prevDiskRead: Int64, prevDiskWrite: Int64,
        thermals: ThermalInfo?, memPressure: String?,
        swapInfo: (used: Int64, total: Int64)?, topProcs: [TopProcess]?
    ) {
        if prevDiskRead > 0 {
            stats.diskReadSpeed = max(0, diskRead - prevDiskRead)
            stats.diskWriteSpeed = max(0, diskWrite - prevDiskWrite)
        }
        previousDiskReadBytes = diskRead
        previousDiskWriteBytes = diskWrite

        if let thermals = thermals {
            stats.fanRPM = thermals.fanSpeeds
            stats.fanCount = thermals.fanSpeeds.count
            stats.cpuTemperature = thermals.cpuTemp
        }
        if let memPressure = memPressure {
            stats.memoryPressureLevel = memPressure
        }
        if let swapInfo = swapInfo {
            stats.swapUsedMB = swapInfo.used
            stats.swapTotalMB = swapInfo.total
        }
        if let topProcs = topProcs {
            stats.topProcesses = topProcs
        }
    }

    // MARK: - Hardware Info (static, loaded once)

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

    /// Runs system_profiler off the main thread
    private nonisolated static func getGPUNameAsync() -> String {
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
        var timeRemaining: Int = -1 // minutes
        var maxCapacity: Int = 100 // percentage
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

        // Get time remaining from IOPSGetTimeRemainingEstimate
        if let timeRemaining = description[kIOPSTimeToEmptyKey] as? Int, timeRemaining >= 0 {
            info.timeRemaining = timeRemaining
        }

        // Get extended battery info from IOKit
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }

            if let cycleCount = Self.getIORegistryValue(service: service, key: "CycleCount") as? Int {
                info.cycleCount = cycleCount
            }
            if let temp = Self.getIORegistryValue(service: service, key: "Temperature") as? Int {
                info.temperature = Double(temp) / 100.0
            }
            if let condition = Self.getIORegistryValue(service: service, key: "BatteryHealthCondition") as? String {
                info.condition = condition
            } else {
                info.condition = "Normal"
            }
            // Max capacity / design capacity for health percentage
            if let maxCap = Self.getIORegistryValue(service: service, key: "MaxCapacity") as? Int,
               let designCap = Self.getIORegistryValue(service: service, key: "DesignCapacity") as? Int,
               designCap > 0 {
                info.maxCapacity = min(100, (maxCap * 100) / designCap)
            }
        }

        return info
    }

    private nonisolated static func getIORegistryValue(service: io_service_t, key: String) -> Any? {
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

    // MARK: - Disk I/O

    private nonisolated static func getDiskIOBytesAsync() -> (read: Int64, write: Int64) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        process.arguments = ["-d", "-c", "1", "-K"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                // iostat output: last line has KB/t, tps, MB/s
                if let lastLine = lines.dropFirst(2).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    let parts = lastLine.split(separator: " ", omittingEmptySubsequences: true)
                    // Format varies, try to extract MB/s values
                    if parts.count >= 3 {
                        let mbRead = Double(parts[parts.count - 1]) ?? 0
                        let mbWrite = Double(parts.count >= 6 ? String(parts[parts.count - 4]) : "0") ?? 0
                        return (Int64(mbRead * 1024 * 1024), Int64(mbWrite * 1024 * 1024))
                    }
                }
            }
        } catch {}

        return (0, 0)
    }

    // MARK: - Thermal Info (Fan Speed & Temperature)

    private struct ThermalInfo {
        var cpuTemp: Double = 0
        var fanSpeeds: [Int] = []
    }

    private nonisolated static func getThermalInfoAsync() -> ThermalInfo {
        var info = ThermalInfo()

        // Try to get fan speed from IOKit
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("AppleSMCFanControl") ?? IOServiceMatching("SMCFanControl")
        if let matchDict = matchDict {
            if IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS {
                var service = IOIteratorNext(iterator)
                while service != IO_OBJECT_NULL {
                    // Try to read fan speeds
                    if let fanSpeed = Self.getIORegistryValue(service: service, key: "FanSpeed") as? [Int] {
                        info.fanSpeeds = fanSpeed
                    }
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }
                IOObjectRelease(iterator)
            }
        }

        // Fallback: use powermetrics or smc for temperature
        // Since direct SMC access requires privileges, we use a lightweight approach
        let tempProcess = Process()
        tempProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        tempProcess.arguments = ["-n", "powermetrics", "--samplers", "smc", "-i", "1", "-n", "1"]

        let tempPipe = Pipe()
        tempProcess.standardOutput = tempPipe
        tempProcess.standardError = FileHandle.nullDevice

        do {
            try tempProcess.run()
            tempProcess.waitUntilExit()
            let data = tempPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse CPU die temperature
                for line in output.components(separatedBy: .newlines) {
                    if line.contains("CPU die temperature") || line.contains("Die temperature") {
                        let parts = line.components(separatedBy: ":")
                        if let tempStr = parts.last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " C", with: ""),
                           let temp = Double(tempStr) {
                            info.cpuTemp = temp
                        }
                    }
                }
            }
        } catch {}

        return info
    }

    // MARK: - Memory Pressure

    private nonisolated static func getMemoryPressureAsync() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        process.arguments = ["-Q"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if output.contains("critical") { return "Critical" }
            if output.contains("warn") { return "Warning" }
            return "Normal"
        } catch {
            return "Normal"
        }
    }

    // MARK: - Swap Info

    private nonisolated static func getSwapInfoAsync() -> (used: Int64, total: Int64) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["vm.swapusage"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var used: Int64 = 0
            var total: Int64 = 0

            if let totalRange = output.range(of: "total = ") {
                let afterTotal = output[totalRange.upperBound...]
                if let mRange = afterTotal.range(of: "M") {
                    total = Int64(Double(afterTotal[..<mRange.lowerBound].trimmingCharacters(in: .whitespaces)) ?? 0)
                }
            }
            if let usedRange = output.range(of: "used = ") {
                let afterUsed = output[usedRange.upperBound...]
                if let mRange = afterUsed.range(of: "M") {
                    used = Int64(Double(afterUsed[..<mRange.lowerBound].trimmingCharacters(in: .whitespaces)) ?? 0)
                }
            }

            return (used, total)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - Top Processes

    private nonisolated static func getTopProcessesAsync() -> [TopProcess] {
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
