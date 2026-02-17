import SwiftUI

struct OptimizerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var viewModel = ViewModelContainer.shared.optimizerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("System Optimize")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Tune your Mac for peak performance")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let security = viewModel.securityStatus {
                        SecurityScoreBadge(score: security.securityScore)
                    }
                }
                .padding()

                // Security Status
                if let security = viewModel.securityStatus {
                    SecurityStatusSection(status: security)
                        .padding(.horizontal)
                }

                // System Health
                if let health = viewModel.systemHealth {
                    SystemHealthSection(health: health)
                        .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // Optimization Actions
                OptimizationActionsSection(viewModel: viewModel)
                    .padding(.horizontal)

                // Results
                if viewModel.showResults {
                    OptimizationResultsSection(results: viewModel.results)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !viewModel.actions.filter(\.isSelected).isEmpty {
                    Button("Select All") { viewModel.selectAll() }
                    Button("Deselect All") { viewModel.deselectAll() }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.checkStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button("Optimize") {
                    viewModel.optimize()
                }
                .disabled(viewModel.selectedCount == 0 || viewModel.isOptimizing)
            }
        }
        .onAppear {
            if viewModel.securityStatus == nil {
                viewModel.checkStatus()
            }
        }
    }
}

// MARK: - Security Score Badge

struct SecurityScoreBadge: View {
    let score: Int

    var color: Color {
        if score >= 100 { return .green }
        if score >= 75 { return .yellow }
        if score >= 50 { return .orange }
        return .red
    }

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)

                Text("\(score)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Text("Security")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Security Status Section

struct SecurityStatusSection: View {
    let status: SecurityChecker.SecurityStatus

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                SecurityRow(name: "FileVault Encryption", enabled: status.fileVaultEnabled)
                SecurityRow(name: "Firewall", enabled: status.firewallEnabled)
                SecurityRow(name: "Gatekeeper", enabled: status.gatekeeperEnabled)
                SecurityRow(name: "System Integrity Protection", enabled: status.sipEnabled)
                SecurityRow(name: "Touch ID for Sudo", enabled: status.touchIdForSudo)
            }
        } label: {
            Label("Security Status", systemImage: "shield.checkered")
                .foregroundStyle(.green)
        }
    }
}

struct SecurityRow: View {
    let name: String
    let enabled: Bool

    var body: some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(enabled ? .green : .yellow)

            Text(name)

            Spacer()

            Text(enabled ? "Enabled" : "Disabled")
                .foregroundStyle(enabled ? .green : .yellow)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - System Health Section

struct SystemHealthSection: View {
    let health: SecurityChecker.SystemHealth

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                HealthRow(
                    name: "Disk Usage",
                    value: String(format: "%.0f%%", health.diskUsedPercent),
                    warning: health.diskWarning
                )
                HealthRow(
                    name: "Memory Pressure",
                    value: health.memoryPressure,
                    warning: health.memoryWarning
                )
                HealthRow(
                    name: "Swap Usage",
                    value: "\(health.swapUsedMB) MB",
                    warning: health.swapWarning
                )
                HealthRow(
                    name: "Login Items",
                    value: "\(health.loginItemsCount)",
                    warning: health.loginItemsCount > 10
                )
            }
        } label: {
            Label("System Health", systemImage: "heart.text.square")
                .foregroundStyle(.blue)
        }
    }
}

struct HealthRow: View {
    let name: String
    let value: String
    let warning: Bool

    var body: some View {
        HStack {
            Image(systemName: warning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(warning ? .orange : .green)

            Text(name)

            Spacer()

            Text(value)
                .foregroundStyle(warning ? .orange : .secondary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Optimization Actions

struct OptimizationActionsSection: View {
    @ObservedObject var viewModel: OptimizerViewModel

    var body: some View {
        GroupBox {
            if viewModel.isOptimizing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(viewModel.optimizeStatus)
                        .foregroundStyle(.secondary)
                    ProgressView(value: viewModel.optimizeProgress)
                        .frame(width: 200)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 4) {
                    ForEach(viewModel.actions) { action in
                        HStack {
                            Button {
                                viewModel.toggleAction(action.id)
                            } label: {
                                Image(systemName: action.isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(action.isSelected ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)

                            Image(systemName: action.icon)
                                .foregroundStyle(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading) {
                                HStack(spacing: 4) {
                                    Text(action.name)
                                        .fontWeight(.medium)

                                    if action.requiresAdmin {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Text(action.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        } label: {
            Label("Optimization Actions", systemImage: "bolt.fill")
                .foregroundStyle(.purple)
        }
    }
}

// MARK: - Results Section

struct OptimizationResultsSection: View {
    let results: [SystemOptimizer.OptimizationResult]

    var body: some View {
        GroupBox {
            VStack(spacing: 6) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)

                        Text(result.action)
                            .fontWeight(.medium)

                        Spacer()

                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } label: {
            Label("Results", systemImage: "list.bullet.clipboard")
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    OptimizerView()
        .environmentObject(AppState())
        .frame(width: 800, height: 700)
}
