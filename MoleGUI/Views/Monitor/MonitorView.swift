import SwiftUI
import Charts

struct MonitorView: View {
    @ObservedObject private var viewModel = ViewModelContainer.shared.monitorViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hardware Info Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("System Monitor")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if !viewModel.stats.macModel.isEmpty {
                            Text("\(viewModel.stats.macModel) \u{2022} \(viewModel.stats.chipName) \u{2022} \(viewModel.stats.totalRAM) RAM")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Real-time system performance")
                                .foregroundStyle(.secondary)
                        }
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
                        subtitle: "Load: \(viewModel.stats.formattedLoadAverage)",
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

                // Battery Section (if present)
                if viewModel.stats.batteryIsPresent {
                    BatteryInfoCard(stats: viewModel.stats)
                        .padding(.horizontal)
                }

                // GPU Section
                if !viewModel.stats.gpuName.isEmpty {
                    GroupBox {
                        HStack {
                            Image(systemName: "gpu")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            Text("GPU")
                                .fontWeight(.medium)
                            Spacer()
                            Text(viewModel.stats.gpuName)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Label("Graphics", systemImage: "display")
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal)
                }

                // Per-Core CPU
                if !viewModel.perCoreCPU.isEmpty {
                    PerCoreCPUCard(cores: viewModel.perCoreCPU)
                        .padding(.horizontal)
                }

                // Top Processes
                if !viewModel.topProcesses.isEmpty {
                    TopProcessesCard(processes: viewModel.topProcesses)
                        .padding(.horizontal)
                }

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

// MARK: - Battery Info Card

struct BatteryInfoCard: View {
    let stats: SystemStats

    var batteryColor: Color {
        if stats.isCharging { return .green }
        if stats.batteryLevel > 50 { return .green }
        if stats.batteryLevel > 20 { return .yellow }
        return .red
    }

    var body: some View {
        GroupBox {
            HStack(spacing: 20) {
                // Battery gauge
                ZStack {
                    Circle()
                        .stroke(batteryColor.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: Double(stats.batteryLevel) / 100.0)
                        .stroke(batteryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 60)

                    VStack(spacing: 0) {
                        Image(systemName: stats.isCharging ? "bolt.fill" : "battery.100percent")
                            .font(.caption)
                            .foregroundStyle(batteryColor)
                        Text("\(stats.batteryLevel)%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Status:")
                            .foregroundStyle(.secondary)
                        Text(stats.isCharging ? "Charging" : "On Battery")
                    }
                    HStack {
                        Text("Condition:")
                            .foregroundStyle(.secondary)
                        Text(stats.batteryCondition)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("Cycles:")
                            .foregroundStyle(.secondary)
                        Text("\(stats.batteryCycleCount)")
                    }
                    if stats.batteryTemperature > 0 {
                        HStack {
                            Text("Temp:")
                                .foregroundStyle(.secondary)
                            Text(stats.formattedBatteryTemp)
                        }
                    }
                }
            }
        } label: {
            Label("Battery", systemImage: "battery.100percent")
                .foregroundStyle(batteryColor)
        }
    }
}

// MARK: - Per-Core CPU Card

struct PerCoreCPUCard: View {
    let cores: [Double]

    var body: some View {
        GroupBox {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(cores.count, 8)), spacing: 8) {
                ForEach(Array(cores.enumerated()), id: \.offset) { index, usage in
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(height: geo.size.height)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(height: max(1, geo.size.height * CGFloat(usage / 100.0)))
                            }
                        }
                        .frame(height: 40)

                        Text("\(index)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Label("Per-Core CPU", systemImage: "cpu")
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Top Processes Card

struct TopProcessesCard: View {
    let processes: [TopProcess]

    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Process")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("PID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)

                    Text("CPU %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)

                    Text("Memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.bottom, 4)

                Divider()

                ForEach(processes) { process in
                    HStack {
                        Text(process.name)
                            .font(.callout)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(process.pid)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)

                        Text(String(format: "%.1f%%", process.cpuPercent))
                            .font(.callout)
                            .foregroundStyle(process.cpuPercent > 50 ? .red : (process.cpuPercent > 20 ? .orange : .primary))
                            .frame(width: 60, alignment: .trailing)

                        Text(String(format: "%.0f MB", process.memoryMB))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        } label: {
            Label("Top Processes", systemImage: "list.number")
                .foregroundStyle(.orange)
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
        .frame(width: 800, height: 900)
}
