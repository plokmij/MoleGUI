import SwiftUI

struct CleanerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var viewModel = ViewModelContainer.shared.cleanerViewModel
    @State private var showDryRunResult = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Deep Clean")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Remove caches, logs, and temporary files")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !viewModel.results.isEmpty {
                    VStack(alignment: .trailing) {
                        Text(viewModel.formattedSelectedSize)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)

                        Text("Selected to clean")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            if viewModel.isScanning {
                ScanningView(status: viewModel.scanStatus, progress: viewModel.scanProgress)
            } else if viewModel.results.isEmpty {
                EmptyStateView(viewModel: viewModel)
            } else {
                CleanerResultsView(viewModel: viewModel)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !viewModel.results.isEmpty {
                    Button("Select All") {
                        viewModel.selectAll()
                    }

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.results.isEmpty {
                    Button {
                        viewModel.startScan()
                    } label: {
                        Label("Scan Again", systemImage: "arrow.clockwise")
                    }

                    if appState.enableDryRun {
                        Button("Preview") {
                            viewModel.clean(dryRun: true)
                            showDryRunResult = true
                        }
                        .disabled(!viewModel.hasAnySelection)
                    }

                    Button("Clean") {
                        viewModel.clean(dryRun: false)
                    }
                    .disabled(!viewModel.hasAnySelection || viewModel.isCleaning)
                } else {
                    Button("Scan") {
                        viewModel.startScan()
                    }
                }
            }
        }
        .alert("Dry Run Result", isPresented: $showDryRunResult) {
            Button("OK", role: .cancel) {}
            Button("Clean Now") {
                viewModel.clean(dryRun: false)
            }
        } message: {
            if let result = viewModel.cleanResult {
                Text("Would remove \(result.deletedCount) items (\(ByteFormatter.format(result.deletedSize)))")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

struct ScanningView: View {
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

struct EmptyStateView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubbles.and.sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.6))

            Text("Ready to Clean")
                .font(.title2)
                .fontWeight(.medium)

            Text("Scan your Mac to find junk files, caches,\nand other items that can be safely removed.")
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

struct CleanerResultsView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        List {
            ForEach(viewModel.results) { categoryResult in
                CategoryRow(
                    categoryResult: categoryResult,
                    isFullySelected: viewModel.isCategoryFullySelected(categoryResult.category),
                    isPartiallySelected: viewModel.isCategoryPartiallySelected(categoryResult.category),
                    selectedItems: viewModel.selectedItems,
                    onToggleCategory: { viewModel.toggleCategory(categoryResult.category) },
                    onToggleItem: { itemId in viewModel.toggleItem(itemId) }
                )
            }
        }
        .listStyle(.inset)
    }
}

struct CategoryRow: View {
    let categoryResult: CacheCategoryResult
    let isFullySelected: Bool
    let isPartiallySelected: Bool
    let selectedItems: Set<UUID>
    let onToggleCategory: () -> Void
    let onToggleItem: (UUID) -> Void

    @State private var isExpanded = false

    private var selectedSize: Int64 {
        categoryResult.items
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(categoryResult.items) { item in
                ItemRow(
                    item: item,
                    isSelected: selectedItems.contains(item.id),
                    onToggle: { onToggleItem(item.id) }
                )
            }
        } label: {
            HStack {
                // Mixed-state checkbox for category
                Button(action: onToggleCategory) {
                    Image(systemName: isFullySelected ? "checkmark.square.fill" :
                            (isPartiallySelected ? "minus.square.fill" : "square"))
                        .foregroundStyle(isFullySelected || isPartiallySelected ? .blue : .secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Image(systemName: categoryResult.category.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text(categoryResult.category.rawValue)
                    .fontWeight(.medium)

                Spacer()

                Text(ByteFormatter.format(selectedSize))
                    .foregroundStyle(isFullySelected || isPartiallySelected ? .primary : .secondary)
                    .fontWeight(isFullySelected || isPartiallySelected ? .medium : .regular)

                Text("(\(categoryResult.items.count) items)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

struct ItemRow: View {
    let item: CacheItem
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

            Image(systemName: "doc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                if let displayName = item.displayName {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .lineLimit(1)
                        if let subtitle = item.subtitle {
                            Text("(\(subtitle))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(item.name)
                        .lineLimit(1)
                }

                Text(item.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.formattedSize)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CleanerView()
        .environmentObject(AppState())
        .frame(width: 700, height: 500)
}
