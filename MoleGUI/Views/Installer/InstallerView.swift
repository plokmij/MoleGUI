import SwiftUI

struct InstallerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var viewModel = ViewModelContainer.shared.installerViewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Installer Cleanup")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Find and remove leftover installer files")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !viewModel.items.isEmpty {
                    VStack(alignment: .trailing) {
                        Text(viewModel.formattedSelectedSize)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)

                        Text("Selected to remove")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            if viewModel.isScanning {
                InstallerScanningView(status: viewModel.scanStatus, progress: viewModel.scanProgress)
            } else if viewModel.items.isEmpty {
                InstallerEmptyView(viewModel: viewModel)
            } else {
                InstallerResultsView(viewModel: viewModel)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !viewModel.items.isEmpty {
                    Button("Select All") { viewModel.selectAll() }
                    Button("Deselect All") { viewModel.deselectAll() }
                    Button("Invert") { viewModel.invertSelection() }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.items.isEmpty {
                    Button {
                        viewModel.startScan()
                    } label: {
                        Label("Scan Again", systemImage: "arrow.clockwise")
                    }

                    Button("Delete Selected", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(!viewModel.hasSelection || viewModel.isDeleting)
                } else {
                    Button("Scan") {
                        viewModel.startScan()
                    }
                }
            }
        }
        .alert("Delete Installer Files?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                viewModel.deleteSelected(appState: appState)
            }
        } message: {
            let count = viewModel.selectedItems.count
            Text("Move \(count) installer file\(count == 1 ? "" : "s") (\(viewModel.formattedSelectedSize)) to Trash?")
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

// MARK: - Scanning View

struct InstallerScanningView: View {
    let status: String
    let progress: Double

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(status)
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
                .frame(width: 200)
            Spacer()
        }
    }
}

// MARK: - Empty State

struct InstallerEmptyView: View {
    @ObservedObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.6))

            Text("Find Installer Files")
                .font(.title2)
                .fontWeight(.medium)

            Text("Scan for .dmg, .pkg, .iso, and other installer\nfiles that can be removed after installation.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Start Scan") {
                viewModel.startScan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }
}

// MARK: - Results View

struct InstallerResultsView: View {
    @ObservedObject var viewModel: InstallerViewModel

    var body: some View {
        List {
            ForEach(viewModel.itemsBySource, id: \.source) { group in
                Section {
                    ForEach(group.items) { item in
                        InstallerItemRow(
                            item: item,
                            isSelected: viewModel.selectedItems.contains(item.id),
                            onToggle: { viewModel.toggleItem(item.id) }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: group.source.icon)
                        Text(group.source.rawValue)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(group.items.count) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Item Row

struct InstallerItemRow: View {
    let item: InstallerItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            Image(systemName: item.fileType.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .lineLimit(1)

                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.fileType.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.1))
                .cornerRadius(4)

            Text(item.formattedSize)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    InstallerView()
        .environmentObject(AppState())
        .frame(width: 700, height: 500)
}
