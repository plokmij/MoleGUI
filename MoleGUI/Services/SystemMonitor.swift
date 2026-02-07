import Foundation
import Combine
import Darwin

@MainActor
class SystemMonitor: ObservableObject {
    @Published var stats = SystemStats()
    @Published var cpuHistory = CPUHistory()
    @Published var memoryHistory = MemoryHistory()
    @Published var networkHistory = NetworkHistory()
    @Published var isMonitoring = false

    private var timer: AnyCancellable?
    private var previousNetworkIn: Int64 = 0
    private var previousNetworkOut: Int64 = 0
    private var previousDiskRead: Int64 = 0
    private var previousDiskWrite: Int64 = 0

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

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
        stats.cpuUsage = getCPUUsage()
        (stats.memoryUsed, stats.memoryTotal, stats.memoryUsage) = getMemoryUsage()
        stats.uptime = getUptime()
        (stats.batteryLevel, stats.isCharging) = getBatteryInfo()

        // Network stats
        let (netIn, netOut) = getNetworkBytes()
        if previousNetworkIn > 0 {
            stats.networkDownSpeed = netIn - previousNetworkIn
            stats.networkUpSpeed = netOut - previousNetworkOut
        }
        previousNetworkIn = netIn
        previousNetworkOut = netOut

        // Update history
        cpuHistory.addSample(stats.cpuUsage)
        memoryHistory.addSample(stats.memoryUsage)
        networkHistory.addSample(upload: stats.networkUpSpeed, download: stats.networkDownSpeed)
    }

    private func getCPUUsage() -> Double {
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
            return 0
        }

        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0

        for i in 0..<Int(numCpus) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += info[offset + Int(CPU_STATE_USER)]
            totalSystem += info[offset + Int(CPU_STATE_SYSTEM)]
            totalIdle += info[offset + Int(CPU_STATE_IDLE)]
        }

        let total = totalUser + totalSystem + totalIdle
        guard total > 0 else { return 0 }

        let usage = Double(totalUser + totalSystem) / Double(total) * 100.0

        // Deallocate
        let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        return min(100, max(0, usage))
    }

    private func getMemoryUsage() -> (used: Int64, total: Int64, percentage: Double) {
        let processInfo = ProcessInfo.processInfo
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

    private func getBatteryInfo() -> (level: Int, isCharging: Bool) {
        // Use IOKit for battery info
        // This is a simplified version - real implementation would use IOPowerSources
        return (100, false)
    }

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
}
