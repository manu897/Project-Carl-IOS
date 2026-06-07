import SwiftUI
import Charts

struct PlantDetailView: View {
    let plant: Plant
    @AppStorage(SettingsKeys.useMockHub) private var useMockHub: Bool = true
    @State private var viewModel: PlantDetailViewModel?
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let viewModel {
                    healthCard(viewModel: viewModel)
                    advancedDisclosure(viewModel: viewModel)
                }
            }
            .padding(16)
        }
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = PlantDetailViewModel(plant: plant, repository: AppEnvironment.makeRepository(useMockHub: useMockHub))
                await viewModel?.load()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        // Profile photo header — drives off the Norman-hosted URL once that
        // endpoint ships. Falls back to the green-leaf placeholder.
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
            if let img = PhotoStore.shared.loadImage(for: plant.id) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .frame(height: 180)
        .clipped()
    }

    private func healthCard(viewModel: PlantDetailViewModel) -> some View {
        let health = PlantHealth.assess(plant: plant, history: viewModel.samples)
        return VStack(spacing: 0) {
            HealthRow(label: "Status",
                      value: PlantHealth.summary(for: plant).label,
                      tint: statusTint(for: PlantHealth.summary(for: plant)))
            Divider()
            HealthRow(label: "Last watered", value: lastWateredText(health.daysSinceWatered))
            Divider()
            HealthRow(label: "Water again", value: waterAgainText(health.daysUntilWater))
            Divider()
            HealthRow(label: "Light", value: health.light.label, tint: levelTint(health.light))
            Divider()
            HealthRow(label: "Temperature", value: health.temperature.label, tint: levelTint(health.temperature))
            Divider()
            HealthRow(label: "Humidity", value: health.humidity.label, tint: levelTint(health.humidity))
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func advancedDisclosure(viewModel: PlantDetailViewModel) -> some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text(showAdvanced ? "Hide advanced" : "Show advanced")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if showAdvanced {
                advancedContent(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func advancedContent(viewModel: PlantDetailViewModel) -> some View {
        @Bindable var vm = viewModel
        VStack(alignment: .leading, spacing: 16) {
            metricsGrid

            Picker("Range", selection: $vm.range) {
                ForEach(History.Range.allCases, id: \.self) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.range) { _, _ in
                Task { await vm.load() }
            }

            if vm.isLoading && vm.samples.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if let message = vm.errorMessage {
                Text(message).foregroundStyle(.red)
            } else {
                ChartCard(title: "Soil moisture", samples: vm.samples, value: \.soilPct, unit: "%", tint: .blue)
                ChartCard(title: "Temperature", samples: vm.samples, value: \.temperatureC, unit: "°C", tint: .orange)
                ChartCard(title: "Humidity", samples: vm.samples, value: \.humidityPct, unit: "%", tint: .teal)
                ChartCard(title: "Light", samples: vm.samples, value: \.illuminanceLux, unit: "lx", tint: .yellow)
            }
        }
    }

    private var metricsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Metric(label: "Soil", value: plant.latest.soilPct.map { String(format: "%.0f%%", $0) } ?? "—")
                Metric(label: "Temperature", value: plant.latest.temperatureC.map { String(format: "%.1f°C", $0) } ?? "—")
            }
            GridRow {
                Metric(label: "Humidity", value: plant.latest.humidityPct.map { String(format: "%.0f%%", $0) } ?? "—")
                Metric(label: "Light", value: plant.latest.illuminanceLux.map { "\(Int($0)) lx" } ?? "—")
            }
            GridRow {
                Metric(label: "Battery", value: plant.batteryPct.map { "\($0)%" } ?? "—")
                Metric(label: "Pressure", value: plant.latest.pressureHpa.map { String(format: "%.0f hPa", $0) } ?? "—")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Formatting

    private func lastWateredText(_ days: Int?) -> String {
        guard let days else { return "Not detected" }
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    private func waterAgainText(_ days: Int?) -> String {
        guard let days else { return "—" }
        if days == 0 { return "Now" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private func statusTint(for summary: PlantHealth.Summary) -> Color {
        switch summary {
        case .healthy: return .green
        case .needsWater, .attention: return .orange
        case .lowBattery: return .red
        case .offline: return .gray
        }
    }

    private func levelTint(_ level: HealthLevel) -> Color {
        switch level {
        case .good: return .green
        case .low: return .blue
        case .high: return .orange
        case .unknown: return .secondary
        }
    }
}

// MARK: - Subviews

private struct HealthRow: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(tint)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChartCard: View {
    let title: String
    let samples: [Reading]
    let value: KeyPath<Reading, Double?>
    let unit: String
    let tint: Color

    private var points: [(Date, Double)] {
        samples.compactMap { reading in
            guard let v = reading[keyPath: value] else { return nil }
            return (reading.timestamp, v)
        }
    }

    private var stats: (min: Double, max: Double, avg: Double)? {
        let values = points.map(\.1)
        guard let min = values.min(), let max = values.max(), !values.isEmpty else { return nil }
        let avg = values.reduce(0, +) / Double(values.count)
        return (min, max, avg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                if let stats {
                    Text("Min \(format(stats.min)) · Avg \(format(stats.avg)) · Max \(format(stats.max))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Chart {
                ForEach(points, id: \.0) { ts, v in
                    LineMark(x: .value("Time", ts), y: .value(title, v))
                        .interpolationMethod(.monotone)
                }
                if let stats {
                    RuleMark(y: .value("Avg", stats.avg))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .foregroundStyle(tint)
            .chartYAxisLabel(unit)
            .frame(height: 140)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func format(_ value: Double) -> String {
        if unit == "lx" { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        PlantDetailView(plant: Plant(
            id: "preview",
            mac: "AA:BB:CC:DD:EE:01",
            name: "Bedroom Monstera",
            lastSeen: .now,
            online: true,
            batteryPct: 87,
            latest: Reading(timestamp: .now, temperatureC: 22.4, humidityPct: 48, pressureHpa: 1013, soilPct: 41, illuminanceLux: 312, batteryPct: 87),
            calibration: .default
        ))
    }
}
