import Foundation
import SwiftUI

@MainActor
class PurgeViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress = 0
    @Published var scanStatus = ""
    @Published var artifacts: [ProjectArtifact] = []
    @Published var groupedArtifacts: [ProjectGroup] = []
    @Published var selectedArtifacts: Set<UUID> = []
    @Published var isPurging = false
    @Published var error: String?
    @Published var scanDirectory: URL?

    private let scanner = FileScanner()
    private let trashManager = TrashManager()

    var totalSize: Int64 {
        artifacts.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        artifacts
            .filter { selectedArtifacts.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteFormatter.format(totalSize)
    }

    var formattedSelectedSize: String {
        ByteFormatter.format(selectedSize)
    }

    func startScan(in directory: URL? = nil) {
        let targetDirectory = directory ?? FileManager.default.homeDirectoryForCurrentUser

        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        scanStatus = "Scanning for project artifacts..."
        artifacts = []
        groupedArtifacts = []
        selectedArtifacts = []
        error = nil
        scanDirectory = targetDirectory

        Task {
            do {
                let foundArtifacts = try await scanner.scanForProjectArtifacts(in: targetDirectory) { [weak self] status, count in
                    Task { @MainActor in
                        self?.scanStatus = status
                        self?.scanProgress = count
                    }
                }

                self.artifacts = foundArtifacts
                self.groupArtifacts()
                self.selectAll()
                self.isScanning = false
                self.scanStatus = "Found \(foundArtifacts.count) artifacts"
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

    private func groupArtifacts() {
        var groups: [ArtifactType: [ProjectArtifact]] = [:]

        for artifact in artifacts {
            if groups[artifact.artifactType] == nil {
                groups[artifact.artifactType] = []
            }
            groups[artifact.artifactType]?.append(artifact)
        }

        groupedArtifacts = groups.map { type, items in
            ProjectGroup(type: type, artifacts: items)
        }.sorted { $0.totalSize > $1.totalSize }
    }

    func toggleArtifact(_ artifact: ProjectArtifact) {
        if selectedArtifacts.contains(artifact.id) {
            selectedArtifacts.remove(artifact.id)
        } else {
            selectedArtifacts.insert(artifact.id)
        }
    }

    func toggleGroup(_ group: ProjectGroup) {
        let groupIds = Set(group.artifacts.map { $0.id })
        let allSelected = groupIds.isSubset(of: selectedArtifacts)

        if allSelected {
            selectedArtifacts.subtract(groupIds)
        } else {
            selectedArtifacts.formUnion(groupIds)
        }
    }

    func selectAll() {
        selectedArtifacts = Set(artifacts.map { $0.id })
    }

    func deselectAll() {
        selectedArtifacts.removeAll()
    }

    func purgeSelected() {
        let toPurge = artifacts.filter { selectedArtifacts.contains($0.id) }
        guard !toPurge.isEmpty else { return }
        guard !isPurging else { return }

        isPurging = true
        error = nil

        Task {
            do {
                let urls = toPurge.map { $0.url }
                _ = try await trashManager.moveToTrash(urls)

                // Remove purged items from list
                artifacts.removeAll { selectedArtifacts.contains($0.id) }
                groupArtifacts()
                selectedArtifacts.removeAll()
                isPurging = false
            } catch {
                self.error = error.localizedDescription
                self.isPurging = false
            }
        }
    }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to scan for project artifacts"

        if panel.runModal() == .OK, let url = panel.url {
            startScan(in: url)
        }
    }

    func revealInFinder(_ artifact: ProjectArtifact) {
        NSWorkspace.shared.selectFile(artifact.url.path, inFileViewerRootedAtPath: artifact.url.deletingLastPathComponent().path)
    }
}
