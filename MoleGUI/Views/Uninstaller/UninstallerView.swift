import SwiftUI

struct UninstallerView: View {
    @StateObject private var viewModel = UninstallerViewModel()

    var body: some View {
        HSplitView {
            // App List
            VStack(spacing: 0) {
                if viewModel.isScanning {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text(viewModel.scanStatus)
                            .foregroundStyle(.secondary)
                            .padding(.top)
                        Spacer()
                    }
                } else if viewModel.apps.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "app.badge")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No Applications Found")
                            .font(.title3)

                        Button("Scan Applications") {
                            viewModel.startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else {
                    AppListView(viewModel: viewModel)
                }
            }
            .frame(minWidth: 350)

            // App Details
            AppDetailView(viewModel: viewModel)
                .frame(minWidth: 300)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search apps...")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(UninstallerViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onAppear {
            if viewModel.apps.isEmpty {
                viewModel.startScan()
            }
        }
        .alert("Uninstall \(viewModel.selectedApp?.name ?? "")?", isPresented: $viewModel.showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove App Only") {
                viewModel.uninstallSelectedApp(includeRemnants: false)
            }
            Button("Remove All", role: .destructive) {
                viewModel.uninstallSelectedApp(includeRemnants: true)
            }
        } message: {
            if let app = viewModel.selectedApp {
                Text("This will move \(app.name) and \(app.remnants.count) related items to Trash.")
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

struct AppListView: View {
    @ObservedObject var viewModel: UninstallerViewModel

    var body: some View {
        List(viewModel.filteredApps, selection: Binding(
            get: { viewModel.selectedApp?.id },
            set: { id in
                if let id = id, let app = viewModel.filteredApps.first(where: { $0.id == id }) {
                    viewModel.selectApp(app)
                }
            }
        )) { app in
            AppRow(app: app)
                .tag(app.id)
        }
        .listStyle(.inset)
    }
}

struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app")
                    .font(.title)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(app.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if app.remnants.count > 0 {
                        Text("+\(app.remnants.count) remnants")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Text(ByteFormatter.format(app.totalSize))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AppDetailView: View {
    @ObservedObject var viewModel: UninstallerViewModel

    var body: some View {
        if let app = viewModel.selectedApp {
            VStack(spacing: 0) {
                // App Header
                GroupBox {
                    VStack(spacing: 16) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        }

                        VStack(spacing: 4) {
                            Text(app.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let version = app.version {
                                Text("Version \(version)")
                                    .foregroundStyle(.secondary)
                            }

                            if let bundleId = app.bundleIdentifier {
                                Text(bundleId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 24) {
                            VStack {
                                Text(app.formattedSize)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Text("App Size")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if app.remnants.count > 0 {
                                VStack {
                                    Text(ByteFormatter.format(app.totalRemnantSize))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    Text("Remnants")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack {
                                Text(ByteFormatter.format(app.totalSize))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()

                // Remnants List
                if app.remnants.isEmpty {
                    VStack {
                        Spacer()
                        Text("No remnants found")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        Section("Related Files (\(app.remnants.count))") {
                            ForEach(app.remnants) { remnant in
                                HStack {
                                    Image(systemName: remnant.type.icon)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)

                                    VStack(alignment: .leading) {
                                        Text(remnant.name)
                                            .lineLimit(1)

                                        Text(remnant.type.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(remnant.formattedSize)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }

                Divider()

                // Actions
                HStack {
                    Button {
                        viewModel.revealInFinder(app)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        viewModel.confirmUninstall()
                    } label: {
                        Label("Uninstall", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isUninstalling)
                }
                .padding()
            }
        } else {
            VStack {
                Spacer()
                Image(systemName: "arrow.left")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Select an app to view details")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

#Preview {
    UninstallerView()
        .frame(width: 800, height: 600)
}
