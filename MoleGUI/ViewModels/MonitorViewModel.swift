import Foundation
import SwiftUI
import Combine

@MainActor
class MonitorViewModel: ObservableObject {
    @Published var systemMonitor = SystemMonitor()
    @Published var diskUsage: DiskUsageInfo?

    private let diskAnalyzer = DiskAnalyzer()
    private var cancellables = Set<AnyCancellable>()

    var stats: SystemStats {
        systemMonitor.stats
    }

    var cpuHistory: [Double] {
        systemMonitor.cpuHistory.samples
    }

    var memoryHistory: [Double] {
        systemMonitor.memoryHistory.samples
    }

    var networkUpHistory: [Int64] {
        systemMonitor.networkHistory.uploadSamples
    }

    var networkDownHistory: [Int64] {
        systemMonitor.networkHistory.downloadSamples
    }

    init() {
        // Forward updates from systemMonitor
        systemMonitor.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        systemMonitor.startMonitoring()
        loadDiskUsage()
    }

    func stopMonitoring() {
        systemMonitor.stopMonitoring()
    }

    func loadDiskUsage() {
        Task {
            diskUsage = await diskAnalyzer.getDiskUsage()
        }
    }

    func refreshDiskUsage() {
        loadDiskUsage()
    }
}
