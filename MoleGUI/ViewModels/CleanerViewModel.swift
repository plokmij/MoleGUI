import Foundation
import SwiftUI

@MainActor
class CleanerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus = ""
    @Published var results: [CacheCategoryResult] = []
    @Published var selectedCategories: Set<CacheCategory> = Set(CacheCategory.allCases)
    @Published var isCleaning = false
    @Published var cleanResult: CacheManager.CleanResult?
    @Published var error: String?

    private let scanner = FileScanner()
    private let cacheManager = CacheManager()

    var totalSize: Int64 {
        results.reduce(0) { $0 + $1.totalSize }
    }

    var selectedSize: Int64 {
        results
            .filter { selectedCategories.contains($0.category) }
            .reduce(0) { $0 + $1.totalSize }
    }

    var formattedTotalSize: String {
        ByteFormatter.format(totalSize)
    }

    var formattedSelectedSize: String {
        ByteFormatter.format(selectedSize)
    }

    func startScan() {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        scanStatus = "Starting scan..."
        results = []
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

    func toggleCategory(_ category: CacheCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func selectAll() {
        selectedCategories = Set(results.map { $0.category })
    }

    func deselectAll() {
        selectedCategories.removeAll()
    }

    func clean(dryRun: Bool = false) {
        guard !isCleaning else { return }

        let categoriesToClean = results.filter { selectedCategories.contains($0.category) }
        guard !categoriesToClean.isEmpty else { return }

        isCleaning = true
        error = nil

        Task {
            do {
                let result = try await cacheManager.cleanCategories(categoriesToClean, dryRun: dryRun)
                self.cleanResult = result

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
