import Foundation
import SwiftUI

@MainActor
class AnalyzerViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analyzeProgress: Double = 0
    @Published var analyzeStatus = ""
    @Published var rootItem: DiskItem?
    @Published var currentPath: [DiskItem] = []
    @Published var diskUsage: DiskUsageInfo?
    @Published var error: String?
    @Published var selectedDirectory: URL?
    @Published var loadingItemId: UUID?

    private let analyzer = DiskAnalyzer()
    private let trashManager = TrashManager()

    var currentItem: DiskItem? {
        currentPath.last ?? rootItem
    }

    var breadcrumbs: [DiskItem] {
        if let root = rootItem {
            return [root] + currentPath
        }
        return currentPath
    }

    var largestItems: [DiskItem] {
        guard let current = currentItem else { return [] }
        return current.children?.prefix(10).map { $0 } ?? []
    }

    func loadDiskUsage() {
        Task {
            diskUsage = await analyzer.getDiskUsage()
        }
    }

    func analyzeHome() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        analyze(directory: homeURL)
    }

    func analyze(directory: URL) {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        analyzeProgress = 0
        analyzeStatus = "Analyzing..."
        rootItem = nil
        currentPath = []
        error = nil
        selectedDirectory = directory

        Task {
            do {
                let result = try await analyzer.analyzeDirectory(directory, maxDepth: 3) { [weak self] status, progress in
                    Task { @MainActor in
                        self?.analyzeStatus = status
                        self?.analyzeProgress = progress
                    }
                }

                self.rootItem = result
                self.isAnalyzing = false
                self.analyzeStatus = "Analysis complete"
            } catch {
                self.error = error.localizedDescription
                self.isAnalyzing = false
                self.analyzeStatus = "Analysis failed"
            }
        }
    }

    func cancelAnalysis() {
        Task {
            await analyzer.cancel()
            isAnalyzing = false
            analyzeStatus = "Analysis cancelled"
        }
    }

    func navigateTo(_ item: DiskItem) {
        guard item.isDirectory else { return }

        // Check if navigating back to an item already in the path
        if let index = currentPath.firstIndex(where: { $0.id == item.id }) {
            currentPath = Array(currentPath.prefix(index + 1))
            return
        }

        // If children are already loaded, navigate directly
        if item.children != nil {
            currentPath.append(item)
            return
        }

        // Lazy load children for this directory
        loadingItemId = item.id
        Task {
            do {
                let children = try await analyzer.analyzeDirectoryShallow(item.url)
                var updatedItem = item
                updatedItem.children = children
                updateItemInTree(updatedItem)
                currentPath.append(updatedItem)
            } catch {
                self.error = error.localizedDescription
            }
            loadingItemId = nil
        }
    }

    /// Updates an item in the tree structure (rootItem or currentPath)
    private func updateItemInTree(_ updatedItem: DiskItem) {
        // Update in rootItem's children
        if var root = rootItem {
            if updateItemRecursive(&root, with: updatedItem) {
                rootItem = root
            }
        }

        // Update in currentPath
        for i in currentPath.indices {
            if var pathItem = currentPath[i].children {
                for j in pathItem.indices {
                    if pathItem[j].id == updatedItem.id {
                        pathItem[j] = updatedItem
                        currentPath[i].children = pathItem
                        return
                    }
                }
            }
        }
    }

    /// Recursively searches and updates an item in the tree
    private func updateItemRecursive(_ parent: inout DiskItem, with updatedItem: DiskItem) -> Bool {
        guard var children = parent.children else { return false }

        for i in children.indices {
            if children[i].id == updatedItem.id {
                children[i] = updatedItem
                parent.children = children
                return true
            }
            if updateItemRecursive(&children[i], with: updatedItem) {
                parent.children = children
                return true
            }
        }
        return false
    }

    func navigateBack() {
        guard !currentPath.isEmpty else { return }
        currentPath.removeLast()
    }

    func navigateToRoot() {
        currentPath = []
    }

    func deleteItem(_ item: DiskItem) {
        Task {
            do {
                _ = try await trashManager.moveToTrash([item.url])

                // Refresh current view
                if let directory = selectedDirectory {
                    analyze(directory: directory)
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func revealInFinder(_ item: DiskItem) {
        Task {
            await trashManager.revealInFinder(item.url)
        }
    }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to analyze"

        if panel.runModal() == .OK, let url = panel.url {
            analyze(directory: url)
        }
    }
}
