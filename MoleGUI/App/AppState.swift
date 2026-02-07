import SwiftUI
import Combine

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case cleaner = "Deep Clean"
    case uninstaller = "Uninstaller"
    case analyzer = "Disk Analyzer"
    case monitor = "Monitor"
    case purge = "Project Purge"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .cleaner: return "bubbles.and.sparkles"
        case .uninstaller: return "trash"
        case .analyzer: return "chart.pie"
        case .monitor: return "cpu"
        case .purge: return "folder.badge.minus"
        case .settings: return "gearshape"
        }
    }

    var description: String {
        switch self {
        case .dashboard: return "System overview"
        case .cleaner: return "Remove caches & junk"
        case .uninstaller: return "Remove apps completely"
        case .analyzer: return "Visualize disk usage"
        case .monitor: return "Real-time system stats"
        case .purge: return "Clean dev artifacts"
        case .settings: return "Preferences"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: NavigationTab = .dashboard
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date?
    @Published var totalSpaceReclaimed: Int64 = 0

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("enableDryRun") var enableDryRun: Bool = true
    @AppStorage("showHiddenFiles") var showHiddenFiles: Bool = false
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadPersistedState()
    }

    private func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: "lastScanDate"),
           let date = try? JSONDecoder().decode(Date.self, from: data) {
            lastScanDate = date
        }
        totalSpaceReclaimed = Int64(UserDefaults.standard.integer(forKey: "totalSpaceReclaimed"))
    }

    func saveState() {
        if let date = lastScanDate,
           let data = try? JSONEncoder().encode(date) {
            UserDefaults.standard.set(data, forKey: "lastScanDate")
        }
        UserDefaults.standard.set(Int(totalSpaceReclaimed), forKey: "totalSpaceReclaimed")
    }

    func addReclaimedSpace(_ bytes: Int64) {
        totalSpaceReclaimed += bytes
        saveState()
    }

    func updateLastScan() {
        lastScanDate = Date()
        saveState()
    }
}
