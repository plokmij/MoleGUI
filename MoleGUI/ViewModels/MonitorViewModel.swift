import Foundation
import SwiftUI
import Combine

@MainActor
class MonitorViewModel: ObservableObject {
    @Published var systemMonitor = SystemMonitor()
    @Published var diskUsage: DiskUsageInfo?
    @Published var trashSize: Int64 = 0
    @Published var trashItemCount: Int = 0
    @Published var isEmptyingTrash = false
    @Published var showEmptyTrashConfirmation = false
    @Published var trashError: String?

    private let diskAnalyzer = DiskAnalyzer()
    private let trashManager = TrashManager()
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

    var diskIOReadHistory: [Int64] {
        systemMonitor.diskIOHistory.readSamples
    }

    var diskIOWriteHistory: [Int64] {
        systemMonitor.diskIOHistory.writeSamples
    }

    var perCoreCPU: [Double] {
        systemMonitor.stats.perCoreCPU
    }

    var topProcesses: [TopProcess] {
        systemMonitor.stats.topProcesses
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

    func loadTrashInfo() {
        Task {
            trashSize = await trashManager.getTrashSize()
            trashItemCount = await trashManager.getTrashItemCount()
        }
    }

    func emptyTrash(appState: AppState) {
        isEmptyingTrash = true
        trashError = nil
        Task {
            do {
                let freedSpace = try await trashManager.emptyTrash()
                appState.addReclaimedSpace(freedSpace)
                loadTrashInfo()
            } catch {
                trashError = error.localizedDescription
            }
            isEmptyingTrash = false
        }
    }
}
