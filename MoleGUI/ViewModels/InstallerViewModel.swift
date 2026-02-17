import Foundation
import SwiftUI

@MainActor
class InstallerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus = ""
    @Published var items: [InstallerItem] = []
    @Published var selectedItems: Set<UUID> = []
    @Published var isDeleting = false
    @Published var error: String?

    private let scanner = InstallerScanner()

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        items.filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteFormatter.format(totalSize)
    }

    var formattedSelectedSize: String {
        ByteFormatter.format(selectedSize)
    }

    var hasSelection: Bool {
        !selectedItems.isEmpty
    }

    var itemsBySource: [(source: InstallerSource, items: [InstallerItem])] {
        let grouped = Dictionary(grouping: items) { $0.source }
        return InstallerSource.allCases
            .compactMap { source in
                guard let items = grouped[source], !items.isEmpty else { return nil }
                return (source: source, items: items)
            }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        scanStatus = "Starting scan..."
        items = []
        selectedItems = []
        error = nil

        Task {
            let found = await scanner.scan { [weak self] status, progress in
                Task { @MainActor in
                    self?.scanStatus = status
                    self?.scanProgress = progress
                }
            }

            self.items = found
            self.selectedItems = Set(found.map(\.id))
            self.isScanning = false
            self.scanStatus = "Scan complete"
        }
    }

    func toggleItem(_ itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
    }

    func selectAll() {
        selectedItems = Set(items.map(\.id))
    }

    func deselectAll() {
        selectedItems.removeAll()
    }

    func invertSelection() {
        let allIds = Set(items.map(\.id))
        selectedItems = allIds.subtracting(selectedItems)
    }

    func deleteSelected(appState: AppState) {
        guard !isDeleting, hasSelection else { return }
        isDeleting = true
        error = nil

        let toDelete = items.filter { selectedItems.contains($0.id) }

        Task {
            do {
                let freedSpace = try await scanner.deleteItems(toDelete)
                appState.addReclaimedSpace(freedSpace)
                // Rescan after deletion
                startScan()
            } catch {
                self.error = error.localizedDescription
            }
            self.isDeleting = false
        }
    }
}
