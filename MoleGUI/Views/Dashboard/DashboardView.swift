import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var monitorVM = MonitorViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("System Overview")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your Mac is running \(monitorVM.stats.healthStatus.lowercased())")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HealthScoreView(score: monitorVM.stats.healthScore)
                }
                .padding()

                // Quick Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
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
                        color: .green
                    )
                }
                .padding(.horizontal)

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(spacing: 16) {
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
                    .padding(.horizontal)
                }

                // Recent Activity
                if let lastScan = appState.lastScanDate {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)

                            Text("Last scan: \(lastScan, style: .relative) ago")
                                .foregroundStyle(.secondary)

                            Spacer()

                            if appState.totalSpaceReclaimed > 0 {
                                Text("Total reclaimed: \(ByteFormatter.format(appState.totalSpaceReclaimed))")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                .stroke(color.opacity(0.2), lineWidth: 8)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack {
                Text("\(score)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
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

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let history = history, !history.isEmpty {
                    MiniChart(data: history, color: color)
                        .frame(height: 30)
                } else if let percentage = percentage {
                    ProgressView(value: percentage / 100)
                        .tint(color)
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(color)
        }
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

    var body: some View {
        GroupBox {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
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
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
