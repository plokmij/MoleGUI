import Foundation
import SwiftUI

struct OptimizationAction: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let requiresAdmin: Bool
    var isSelected: Bool = true
    var result: SystemOptimizer.OptimizationResult?
}

@MainActor
class OptimizerViewModel: ObservableObject {
    @Published var securityStatus: SecurityChecker.SecurityStatus?
    @Published var systemHealth: SecurityChecker.SystemHealth?
    @Published var isChecking = false
    @Published var isOptimizing = false
    @Published var optimizeProgress: Double = 0
    @Published var optimizeStatus = ""
    @Published var results: [SystemOptimizer.OptimizationResult] = []
    @Published var showResults = false

    @Published var actions: [OptimizationAction] = [
        OptimizationAction(
            name: "Flush DNS Cache",
            description: "Clear DNS resolver cache to fix networking issues",
            icon: "network",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Refresh QuickLook",
            description: "Rebuild QuickLook thumbnail and icon caches",
            icon: "eye",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Clean Saved States",
            description: "Remove old application saved state data (30+ days)",
            icon: "doc.badge.clock",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Repair Preferences",
            description: "Detect and remove corrupted .plist preference files",
            icon: "wrench.and.screwdriver",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Vacuum Databases",
            description: "Optimize Mail, Safari, and Messages databases",
            icon: "cylinder",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Rebuild LaunchServices",
            description: "Fix duplicate entries in 'Open With' menus",
            icon: "list.bullet.rectangle",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Rebuild Font Cache",
            description: "Clear and rebuild the system font cache",
            icon: "textformat",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Relieve Memory Pressure",
            description: "Purge inactive memory to free up RAM",
            icon: "memorychip",
            requiresAdmin: true
        ),
        OptimizationAction(
            name: "Optimize Network",
            description: "Flush route table and ARP cache",
            icon: "wifi",
            requiresAdmin: true
        ),
        OptimizationAction(
            name: "Repair Disk Permissions",
            description: "Reset user permissions on the boot volume",
            icon: "lock.shield",
            requiresAdmin: false
        ),
        OptimizationAction(
            name: "Refresh Dock",
            description: "Restart Dock to fix display issues",
            icon: "dock.rectangle",
            requiresAdmin: false
        ),
    ]

    private let optimizer = SystemOptimizer()
    private let securityChecker = SecurityChecker()

    func checkStatus() {
        guard !isChecking else { return }
        isChecking = true

        Task {
            async let security = securityChecker.checkSecurity()
            async let health = securityChecker.checkSystemHealth()

            self.securityStatus = await security
            self.systemHealth = await health
            self.isChecking = false
        }
    }

    func toggleAction(_ actionId: UUID) {
        if let index = actions.firstIndex(where: { $0.id == actionId }) {
            actions[index].isSelected.toggle()
        }
    }

    func selectAll() {
        for i in actions.indices { actions[i].isSelected = true }
    }

    func deselectAll() {
        for i in actions.indices { actions[i].isSelected = false }
    }

    var selectedCount: Int {
        actions.filter(\.isSelected).count
    }

    func optimize() {
        guard !isOptimizing else { return }
        let selectedActions = actions.filter(\.isSelected)
        guard !selectedActions.isEmpty else { return }

        isOptimizing = true
        results = []
        optimizeProgress = 0

        Task {
            let total = Double(selectedActions.count)
            var completed = 0.0

            for action in selectedActions {
                optimizeStatus = action.name

                let result: SystemOptimizer.OptimizationResult
                switch action.name {
                case "Flush DNS Cache":
                    result = await optimizer.flushDNS()
                case "Refresh QuickLook":
                    result = await optimizer.refreshQuickLook()
                case "Clean Saved States":
                    result = await optimizer.cleanSavedStates()
                case "Repair Preferences":
                    result = await optimizer.repairPreferences()
                case "Vacuum Databases":
                    result = await optimizer.vacuumDatabases()
                case "Rebuild LaunchServices":
                    result = await optimizer.rebuildLaunchServices()
                case "Rebuild Font Cache":
                    result = await optimizer.rebuildFontCache()
                case "Relieve Memory Pressure":
                    result = await optimizer.relieveMemoryPressure()
                case "Optimize Network":
                    result = await optimizer.optimizeNetwork()
                case "Repair Disk Permissions":
                    result = await optimizer.repairDiskPermissions()
                case "Refresh Dock":
                    result = await optimizer.refreshDock()
                default:
                    result = SystemOptimizer.OptimizationResult(action: action.name, success: false, message: "Unknown action")
                }

                results.append(result)
                completed += 1
                optimizeProgress = completed / total
            }

            optimizeStatus = "Optimization complete"
            isOptimizing = false
            showResults = true
        }
    }
}
