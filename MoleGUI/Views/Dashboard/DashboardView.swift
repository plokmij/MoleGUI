import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var monitorVM = ViewModelContainer.shared.monitorViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Overview")
                            .font(.system(size: 24, weight: .bold))

                        Text("Your Mac is running \(monitorVM.stats.healthStatus.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HealthScoreView(score: monitorVM.stats.healthScore)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Quick Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    QuickStatCard(
                        title: "CPU",
                        value: String(format: "%.0f%%", monitorVM.stats.cpuUsage),
                        icon: "cpu",
                        color: .blue,
                        history: monitorVM.cpuHistory
                    )

                    QuickStatCard(
                        title: "Memory",
                        value: String(format: "%.0f%%", monitorVM.stats.memoryUsage),
                        icon: "memorychip",
                        color: .purple,
                        history: monitorVM.memoryHistory
                    )

                    QuickStatCard(
                        title: "Disk",
                        value: monitorVM.diskUsage?.formattedFree ?? "--",
                        subtitle: "Free",
                        icon: "internaldrive",
                        color: .orange,
                        percentage: monitorVM.diskUsage?.usedPercentage
                    )

                    QuickStatCard(
                        title: "Uptime",
                        value: monitorVM.stats.formattedUptime,
                        icon: "clock",
                        color: .green,
                        isUptime: true
                    )
                }
                .padding(.horizontal, 20)

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        QuickActionButton(
                            title: "Deep Clean",
                            subtitle: "Remove junk files",
                            icon: "bubbles.and.sparkles",
                            color: .blue
                        ) {
                            appState.selectedTab = .cleaner
                        }

                        QuickActionButton(
                            title: "Uninstall Apps",
                            subtitle: "Remove completely",
                            icon: "trash",
                            color: .red
                        ) {
                            appState.selectedTab = .uninstaller
                        }

                        QuickActionButton(
                            title: "Analyze Disk",
                            subtitle: "Visualize storage",
                            icon: "chart.pie",
                            color: .orange
                        ) {
                            appState.selectedTab = .analyzer
                        }

                        QuickActionButton(
                            title: "Purge Projects",
                            subtitle: "Clean dev artifacts",
                            icon: "folder.badge.minus",
                            color: .purple
                        ) {
                            appState.selectedTab = .purge
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Recent Activity
                if let lastScan = appState.lastScanDate {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)

                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)

                            Text("Last scan: \(lastScan, style: .relative) ago")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if appState.totalSpaceReclaimed > 0 {
                                Text("Total reclaimed: \(ByteFormatter.format(appState.totalSpaceReclaimed))")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            monitorVM.startMonitoring()
        }
        .onDisappear {
            monitorVM.stopMonitoring()
        }
    }
}

struct HealthScoreView: View {
    let score: Int

    var color: Color {
        switch score {
        case 90...100: return .green
        case 70..<90: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 6)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: score)

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Health")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 70, height: 70)
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color
    var history: [Double]?
    var percentage: Double?
    var isUptime: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let history = history, !history.isEmpty {
                MiniChart(data: history, color: color)
                    .frame(height: 30)
            } else if let percentage = percentage {
                ProgressView(value: percentage / 100)
                    .tint(color)
            } else if isUptime {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text("Running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 30, alignment: .bottom)
            } else {
                Spacer()
                    .frame(height: 30)
            }
        }
        .padding(12)
        .frame(minHeight: 110)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct MiniChart: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? .regularMaterial : .thinMaterial)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
