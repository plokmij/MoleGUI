import SwiftUI

struct PurgeView: View {
    @ObservedObject private var viewModel = ViewModelContainer.shared.purgeViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Project Purge")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Remove build artifacts and dependencies")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !viewModel.artifacts.isEmpty {
                    VStack(alignment: .trailing) {
                        Text(viewModel.formattedSelectedSize)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)

                        Text("Selected to purge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            if viewModel.isScanning {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(viewModel.scanStatus)
                        .foregroundStyle(.secondary)
                    Text("Found \(viewModel.scanProgress) artifacts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if viewModel.artifacts.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 64))
                        .foregroundStyle(.purple.opacity(0.6))

                    Text("Clean Up Dev Artifacts")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Find and remove node_modules, target folders,\nbuild directories, and other project artifacts.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button("Scan Home Folder") {
                            viewModel.startScan()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Choose Folder...") {
                            viewModel.selectDirectory()
                        }
                    }

                    Spacer()
                }
            } else {
                PurgeResultsView(viewModel: viewModel)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !viewModel.artifacts.isEmpty {
                    Button("Select All") {
                        viewModel.selectAll()
                    }

                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }

                    Text("\(viewModel.selectedArtifacts.count) of \(viewModel.artifacts.count) selected")
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.artifacts.isEmpty {
                    Button("Purge Selected", role: .destructive) {
                        viewModel.showPurgeConfirmation = true
                    }
                    .disabled(viewModel.selectedArtifacts.isEmpty || viewModel.isPurging)
                } else {
                    Button("Scan Home Folder") {
                        viewModel.startScan()
                    }
                }
            }
        }
        .alert("Purge \(viewModel.selectedArtifacts.count) artifacts?", isPresented: $viewModel.showPurgeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Purge", role: .destructive) {
                viewModel.purgeSelected()
            }
        } message: {
            Text("This will move \(viewModel.selectedArtifacts.count) items (\(viewModel.formattedSelectedSize)) to Trash.")
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

struct PurgeResultsView: View {
    @ObservedObject var viewModel: PurgeViewModel

    var body: some View {
        List {
            ForEach(viewModel.groupedArtifacts) { group in
                Section {
                    ForEach(group.artifacts) { artifact in
                        ArtifactRow(
                            artifact: artifact,
                            isSelected: viewModel.selectedArtifacts.contains(artifact.id),
                            onToggle: { viewModel.toggleArtifact(artifact) },
                            onReveal: { viewModel.revealInFinder(artifact) }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: group.type.icon)
                            .foregroundStyle(colorForType(group.type))

                        Text(group.type.rawValue)
                            .fontWeight(.medium)

                        Spacer()

                        Text(group.formattedSize)
                            .foregroundStyle(.secondary)

                        Text("(\(group.artifacts.count))")
                            .foregroundStyle(.secondary)

                        Button {
                            viewModel.toggleGroup(group)
                        } label: {
                            let allSelected = Set(group.artifacts.map { $0.id }).isSubset(of: viewModel.selectedArtifacts)
                            Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(allSelected ? .purple : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func colorForType(_ type: ArtifactType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "cyan": return .cyan
        case "red": return .red
        case "yellow": return .yellow
        case "teal": return .teal
        default: return .gray
        }
    }
}

struct ArtifactRow: View {
    let artifact: ProjectArtifact
    let isSelected: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.projectName)
                    .fontWeight(.medium)

                Text(artifact.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(artifact.formattedSize)
                    .fontWeight(.medium)

                Text(artifact.age)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .contextMenu {
            Button("Show in Finder") {
                onReveal()
            }
        }
    }
}

#Preview {
    PurgeView()
        .frame(width: 700, height: 500)
}
