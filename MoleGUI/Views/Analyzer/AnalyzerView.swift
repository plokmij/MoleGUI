import SwiftUI
import Charts

struct AnalyzerView: View {
    @StateObject private var viewModel = AnalyzerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header with disk usage
            HStack {
                VStack(alignment: .leading) {
                    Text("Disk Analyzer")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let usage = viewModel.diskUsage {
                        Text("\(usage.formattedFree) free of \(usage.formattedTotal)")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let usage = viewModel.diskUsage {
                    DiskUsageGauge(usage: usage)
                        .frame(width: 100, height: 100)
                }
            }
            .padding()

            Divider()

            if viewModel.isAnalyzing {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(viewModel.analyzeStatus)
                        .foregroundStyle(.secondary)
                    ProgressView(value: viewModel.analyzeProgress)
                        .frame(width: 200)
                    Spacer()
                }
            } else if viewModel.rootItem == nil {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.pie")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange.opacity(0.6))

                    Text("Analyze Your Storage")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Visualize what's taking up space on your disk")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button("Analyze Home Folder") {
                            viewModel.analyzeHome()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Choose Folder...") {
                            viewModel.selectDirectory()
                        }
                    }

                    Spacer()
                }
            } else {
                HSplitView {
                    // Chart View
                    VStack {
                        // Breadcrumb
                        BreadcrumbView(viewModel: viewModel)
                            .padding()

                        DiskChartView(viewModel: viewModel)
                            .padding()
                    }
                    .frame(minWidth: 400)

                    // File List
                    DiskItemListView(viewModel: viewModel)
                        .frame(minWidth: 300)
                }
            }

        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if viewModel.rootItem != nil {
                    Button {
                        viewModel.navigateBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(viewModel.currentPath.isEmpty)

                    Button {
                        viewModel.navigateToRoot()
                    } label: {
                        Label("Root", systemImage: "house")
                    }
                    .disabled(viewModel.currentPath.isEmpty)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button("Choose Folder...") {
                    viewModel.selectDirectory()
                }

                if viewModel.isAnalyzing {
                    Button("Cancel") {
                        viewModel.cancelAnalysis()
                    }
                } else {
                    Button {
                        if let dir = viewModel.selectedDirectory {
                            viewModel.analyze(directory: dir)
                        } else {
                            viewModel.analyzeHome()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadDiskUsage()
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

struct DiskUsageGauge: View {
    let usage: DiskUsageInfo

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: usage.usedPercentage / 100)
                .stroke(
                    usage.usedPercentage > 90 ? Color.red :
                        usage.usedPercentage > 75 ? Color.orange : Color.blue,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack {
                Text(String(format: "%.0f%%", usage.usedPercentage))
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Used")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BreadcrumbView: View {
    @ObservedObject var viewModel: AnalyzerViewModel

    var body: some View {
        HStack {
            ForEach(viewModel.breadcrumbs) { item in
                BreadcrumbItem(
                    item: item,
                    isFirst: viewModel.breadcrumbs.first?.id == item.id,
                    isLast: viewModel.breadcrumbs.last?.id == item.id,
                    onTap: {
                        if viewModel.breadcrumbs.first?.id == item.id {
                            viewModel.navigateToRoot()
                        } else {
                            viewModel.navigateTo(item)
                        }
                    }
                )
            }

            Spacer()
        }
    }
}

struct BreadcrumbItem: View {
    let item: DiskItem
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if !isFirst {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Button(item.name, action: onTap)
                .buttonStyle(.plain)
                .foregroundColor(isLast ? .primary : .blue)
        }
    }
}

struct DiskChartView: View {
    @ObservedObject var viewModel: AnalyzerViewModel

    var body: some View {
        if let current = viewModel.currentItem, let children = current.children {
            Chart {
                ForEach(Array(children.prefix(10))) { item in
                    BarMark(
                        x: .value("Size", item.size),
                        y: .value("Name", item.name)
                    )
                    .foregroundStyle(by: .value("Name", item.name))
                    .cornerRadius(4)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let size = value.as(Int64.self) {
                            Text(ByteFormatter.format(size))
                        }
                    }
                }
            }
            .frame(minHeight: 300)
        }
    }
}

struct DiskItemListView: View {
    @ObservedObject var viewModel: AnalyzerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let current = viewModel.currentItem {
                GroupBox {
                    HStack {
                        Text(current.name)
                            .font(.headline)
                        Spacer()
                        Text(current.formattedSize)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            List {
                if let children = viewModel.currentItem?.children {
                    ForEach(children) { item in
                        DiskItemRow(item: item, viewModel: viewModel)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

struct DiskItemRow: View {
    let item: DiskItem
    @ObservedObject var viewModel: AnalyzerViewModel

    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .foregroundStyle(item.color)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text(item.name)
                    .lineLimit(1)

                if item.isDirectory {
                    Text("\(item.children?.count ?? 0) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.formattedSize)
                .foregroundStyle(.secondary)

            if item.isDirectory && item.children != nil {
                Button {
                    viewModel.navigateTo(item)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button("Show in Finder") {
                viewModel.revealInFinder(item)
            }

            Divider()

            Button("Delete", role: .destructive) {
                viewModel.deleteItem(item)
            }
        }
    }
}

#Preview {
    AnalyzerView()
        .frame(width: 900, height: 600)
}
