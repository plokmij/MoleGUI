import SwiftUI
import Charts

struct MonitorView: View {
    @ObservedObject private var viewModel = ViewModelContainer.shared.monitorViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("System Monitor")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Real-time system performance")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Uptime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.stats.formattedUptime)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding()

                // Gauges Row
                HStack(spacing: 20) {
                    SystemGaugeView(
                        title: "CPU",
                        value: viewModel.stats.cpuUsage,
                        unit: "%",
                        color: .blue,
                        icon: "cpu"
                    )

                    SystemGaugeView(
                        title: "Memory",
                        value: viewModel.stats.memoryUsage,
                        unit: "%",
                        subtitle: "\(viewModel.stats.formattedMemoryUsed) / \(viewModel.stats.formattedMemoryTotal)",
                        color: .purple,
                        icon: "memorychip"
                    )

                    if let disk = viewModel.diskUsage {
                        SystemGaugeView(
                            title: "Disk",
                            value: disk.usedPercentage,
                            unit: "%",
                            subtitle: "\(disk.formattedUsed) / \(disk.formattedTotal)",
                            color: .orange,
                            icon: "internaldrive"
                        )
                    }
                }
                .padding(.horizontal)

                // Charts
                VStack(spacing: 20) {
                    // CPU History Chart
                    ChartCard(title: "CPU Usage", icon: "cpu", color: .blue) {
                        Chart {
                            ForEach(Array(viewModel.cpuHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Time", index),
                                    y: .value("CPU", value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.4), .blue.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("CPU", value)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                                AxisValueLabel {
                                    Text("\(value.as(Int.self) ?? 0)%")
                                        .font(.caption2)
                                }
                            }
                        }
                        .frame(height: 120)
                    }

                    // Memory History Chart
                    ChartCard(title: "Memory Usage", icon: "memorychip", color: .purple) {
                        Chart {
                            ForEach(Array(viewModel.memoryHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Time", index),
                                    y: .value("Memory", value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.4), .purple.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("Memory", value)
                                )
                                .foregroundStyle(.purple)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                                AxisValueLabel {
                                    Text("\(value.as(Int.self) ?? 0)%")
                                        .font(.caption2)
                                }
                            }
                        }
                        .frame(height: 120)
                    }

                    // Network Chart
                    ChartCard(title: "Network Activity", icon: "network", color: .green) {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "arrow.down")
                                        .foregroundStyle(.green)
                                    Text(viewModel.stats.formattedNetworkDown)
                                        .fontWeight(.medium)
                                }
                                Text("Download")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "arrow.up")
                                        .foregroundStyle(.blue)
                                    Text(viewModel.stats.formattedNetworkUp)
                                        .fontWeight(.medium)
                                }
                                Text("Upload")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Chart {
                                ForEach(Array(viewModel.networkDownHistory.enumerated()), id: \.offset) { index, value in
                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Down", value)
                                    )
                                    .foregroundStyle(.green)
                                }

                                ForEach(Array(viewModel.networkUpHistory.enumerated()), id: \.offset) { index, value in
                                    LineMark(
                                        x: .value("Time", index),
                                        y: .value("Up", value)
                                    )
                                    .foregroundStyle(.blue)
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(width: 200, height: 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

struct SystemGaugeView: View {
    let title: String
    let value: Double
    let unit: String
    var subtitle: String?
    let color: Color
    let icon: String

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: min(value / 100, 1.0))
                        .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: value)

                    VStack {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(color)

                        Text(String(format: "%.0f%@", value, unit))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .frame(width: 120, height: 120)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } label: {
            Text(title)
                .font(.headline)
        }
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            content()
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    MonitorView()
        .frame(width: 800, height: 700)
}
