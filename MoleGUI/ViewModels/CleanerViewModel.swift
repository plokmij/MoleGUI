import Foundation
import SwiftUI

@MainActor
class CleanerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus = ""
    @Published var results: [CacheCategoryResult] = []
    @Published var selectedItems: Set<UUID> = []
    @Published var isCleaning = false
    @Published var cleanResult: CacheManager.CleanResult?
    @Published var brewCleanupResult: String?
    @Published var error: String?

    private let scanner = FileScanner()
    private let cacheManager = CacheManager()

    var totalSize: Int64 {
        results.reduce(0) { $0 + $1.totalSize }
    }

    var selectedSize: Int64 {
        results.flatMap { $0.items }
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteFormatter.format(totalSize)
    }

    var formattedSelectedSize: String {
        ByteFormatter.format(selectedSize)
    }

    var hasAnySelection: Bool {
        !selectedItems.isEmpty
    }

    func startScan() {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        scanStatus = "Starting scan..."
        results = []
        selectedItems = []
        error = nil

        Task {
            do {
                let scanResults = try await scanner.scanForCaches(
                    locations: CachePaths.allLocations
                ) { [weak self] status, progress in
                    Task { @MainActor in
                        self?.scanStatus = status
                        self?.scanProgress = progress
                    }
                }

                self.results = scanResults
                // Select all items by default
                self.selectedItems = Set(scanResults.flatMap { $0.items }.map { $0.id })
                self.isScanning = false
                self.scanStatus = "Scan complete"
            } catch {
                self.error = error.localizedDescription
                self.isScanning = false
                self.scanStatus = "Scan failed"
            }
        }
    }

    func cancelScan() {
        Task {
            await scanner.cancel()
            isScanning = false
            scanStatus = "Scan cancelled"
        }
    }

    func toggleItem(_ itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
    }

    func toggleCategory(_ category: CacheCategory) {
        guard let categoryResult = results.first(where: { $0.category == category }) else { return }
        let categoryItemIds = Set(categoryResult.items.map { $0.id })

        if isCategoryFullySelected(category) {
            // Deselect all items in category
            selectedItems.subtract(categoryItemIds)
        } else {
            // Select all items in category
            selectedItems.formUnion(categoryItemIds)
        }
    }

    func isCategoryFullySelected(_ category: CacheCategory) -> Bool {
        guard let categoryResult = results.first(where: { $0.category == category }) else { return false }
        return categoryResult.items.allSatisfy { selectedItems.contains($0.id) }
    }

    func isCategoryPartiallySelected(_ category: CacheCategory) -> Bool {
        guard let categoryResult = results.first(where: { $0.category == category }) else { return false }
        let selectedCount = categoryResult.items.filter { selectedItems.contains($0.id) }.count
        return selectedCount > 0 && selectedCount < categoryResult.items.count
    }

    func selectAll() {
        selectedItems = Set(results.flatMap { $0.items }.map { $0.id })
    }

    func deselectAll() {
        selectedItems.removeAll()
    }

    func clean(dryRun: Bool = false) {
        guard !isCleaning else { return }
        guard !selectedItems.isEmpty else { return }

        isCleaning = true
        error = nil
        brewCleanupResult = nil

        // Get all selected items
        let allItemsToClean = results.flatMap { $0.items }
            .filter { selectedItems.contains($0.id) }

        // Split into regular and admin-required items
        let regularItems = allItemsToClean.filter { !$0.requiresAdmin }
        let adminItems = allItemsToClean.filter { $0.requiresAdmin }

        // Check if any Homebrew items are selected
        let hasHomebrewItems = allItemsToClean.contains { $0.category == .homebrewCache }

        Task {
            do {
                // Clean regular items
                let result = try await cacheManager.cleanItems(regularItems, dryRun: dryRun)

                // Clean admin items with privilege escalation
                var adminResult: CacheManager.CleanResult?
                if !adminItems.isEmpty {
                    adminResult = try await cacheManager.cleanWithPrivileges(adminItems, dryRun: dryRun)
                }

                // Merge results
                let totalDeleted = result.deletedCount + (adminResult?.deletedCount ?? 0)
                let totalSize = result.deletedSize + (adminResult?.deletedSize ?? 0)
                let allErrors = result.errors + (adminResult?.errors ?? [])
                let totalSkipped = result.skippedRunning + (adminResult?.skippedRunning ?? 0)

                self.cleanResult = CacheManager.CleanResult(
                    deletedCount: totalDeleted,
                    deletedSize: totalSize,
                    errors: allErrors,
                    skippedRunning: totalSkipped
                )

                // Run brew cleanup if Homebrew items were selected and not dry run
                if hasHomebrewItems && !dryRun {
                    let brewResult = await scanner.runBrewCleanup()
                    self.brewCleanupResult = brewResult.message
                }

                if !dryRun {
                    // Refresh scan results after cleaning
                    startScan()
                }

                self.isCleaning = false
            } catch {
                self.error = error.localizedDescription
                self.isCleaning = false
            }
        }
    }
}
