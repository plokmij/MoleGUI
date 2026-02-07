import Foundation
import SwiftUI

@MainActor
class UninstallerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus = ""
    @Published var apps: [InstalledApp] = []
    @Published var selectedApp: InstalledApp?
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .size
    @Published var isUninstalling = false
    @Published var error: String?
    @Published var showConfirmation = false

    // Multi-select state
    @Published var selectedAppIds: Set<UUID> = []
    @Published var showBulkConfirmation = false

    private let analyzer = AppBundleAnalyzer()

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case lastUsed = "Last Used"
    }

    var filteredApps: [InstalledApp] {
        var filtered = apps

        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortOrder {
        case .name:
            filtered.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            filtered.sort { $0.totalSize > $1.totalSize }
        case .lastUsed:
            filtered.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }

        return filtered
    }

    var totalAppsSize: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }

    // MARK: - Multi-select computed properties

    var selectedAppsForDeletion: [InstalledApp] {
        apps.filter { selectedAppIds.contains($0.id) }
    }

    var selectedTotalSize: Int64 {
        selectedAppsForDeletion.reduce(0) { $0 + $1.totalSize }
    }

    var hasSelection: Bool {
        !selectedAppIds.isEmpty
    }

    var allVisibleSelected: Bool {
        !filteredApps.isEmpty && filteredApps.allSatisfy { selectedAppIds.contains($0.id) }
    }

    // MARK: - Multi-select methods

    func toggleAppSelection(_ app: InstalledApp) {
        if selectedAppIds.contains(app.id) {
            selectedAppIds.remove(app.id)
        } else {
            selectedAppIds.insert(app.id)
        }
    }

    func isAppSelected(_ app: InstalledApp) -> Bool {
        selectedAppIds.contains(app.id)
    }

    func selectAllApps() {
        for app in filteredApps {
            selectedAppIds.insert(app.id)
        }
    }

    func deselectAllApps() {
        selectedAppIds.removeAll()
    }

    func confirmBulkUninstall() {
        guard hasSelection else { return }
        showBulkConfirmation = true
    }

    func uninstallSelectedApps(includeRemnants: Bool = true) {
        guard hasSelection else { return }
        guard !isUninstalling else { return }

        isUninstalling = true
        showBulkConfirmation = false
        error = nil

        let appsToDelete = selectedAppsForDeletion

        Task {
            var failedApps: [String] = []

            for app in appsToDelete {
                do {
                    _ = try await analyzer.uninstallApp(app, includeRemnants: includeRemnants)
                    // Remove from list on success
                    apps.removeAll { $0.id == app.id }
                    selectedAppIds.remove(app.id)
                } catch {
                    failedApps.append(app.name)
                }
            }

            isUninstalling = false

            if !failedApps.isEmpty {
                self.error = "Failed to uninstall: \(failedApps.joined(separator: ", "))"
            }

            // Clear single selection if it was deleted
            if let selected = selectedApp, !apps.contains(where: { $0.id == selected.id }) {
                selectedApp = nil
            }
        }
    }

    func startScan() {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        scanStatus = "Scanning applications..."
        apps = []
        error = nil
        selectedApp = nil
        selectedAppIds.removeAll()

        Task {
            do {
                let scannedApps = try await analyzer.scanInstalledApps { [weak self] status, progress in
                    Task { @MainActor in
                        self?.scanStatus = status
                        self?.scanProgress = progress
                    }
                }

                self.apps = scannedApps
                self.isScanning = false
                self.scanStatus = "Found \(scannedApps.count) applications"
            } catch {
                self.error = error.localizedDescription
                self.isScanning = false
                self.scanStatus = "Scan failed"
            }
        }
    }

    func selectApp(_ app: InstalledApp) {
        selectedApp = app

        // Load remnants lazily if not already loaded
        if app.remnants.isEmpty, app.bundleIdentifier != nil {
            Task {
                let remnants = await analyzer.loadRemnantsForApp(app)
                // Update the app in our list with remnants
                if let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].remnants = remnants
                    // Update selected app if still the same
                    if selectedApp?.id == app.id {
                        selectedApp = apps[index]
                    }
                }
            }
        }
    }

    func confirmUninstall() {
        guard selectedApp != nil else { return }
        showConfirmation = true
    }

    func uninstallSelectedApp(includeRemnants: Bool = true) {
        guard let app = selectedApp else { return }
        guard !isUninstalling else { return }

        isUninstalling = true
        showConfirmation = false
        error = nil

        Task {
            do {
                _ = try await analyzer.uninstallApp(app, includeRemnants: includeRemnants)

                // Remove from list
                apps.removeAll { $0.id == app.id }
                selectedApp = nil
                isUninstalling = false
            } catch {
                self.error = error.localizedDescription
                self.isUninstalling = false
            }
        }
    }

    func revealInFinder(_ app: InstalledApp) {
        NSWorkspace.shared.selectFile(app.url.path, inFileViewerRootedAtPath: "/Applications")
    }
}
