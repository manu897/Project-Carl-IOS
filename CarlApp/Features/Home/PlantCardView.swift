import SwiftUI

struct PlantCardView: View {
    let plant: Plant

    var body: some View {
        HStack(spacing: 14) {
            photoPlaceholder
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(plant.name)
                        .font(.headline)
                    if plant.isRoom {
                        Text("Room")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                summaryLine
                Text("Last seen \(plant.lastSeen.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            StatusPill(summary: PlantHealth.summary(for: plant))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var photoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
            if let img = PhotoStore.shared.loadImage(for: plant.id) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: plant.isRoom ? "sensor.fill" : "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(plant.isRoom ? .blue : .green)
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
    }

    @ViewBuilder
    private var summaryLine: some View {
        switch PlantHealth.summary(for: plant) {
        case .healthy:
            Text(plant.isRoom ? "Monitoring room" : "Looking healthy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .needsWater:
            Text("Soil is dry — time to water")
                .font(.subheadline)
                .foregroundStyle(.orange)
        case .lowBattery:
            Text("Sensor battery is low")
                .font(.subheadline)
                .foregroundStyle(.red)
        case .offline:
            Text("Hasn't reported recently")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .attention(let reason):
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }
}

struct StatusPill: View {
    let summary: PlantHealth.Summary

    var body: some View {
        Text(summary.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch summary {
        case .healthy: return .green
        case .needsWater: return .orange
        case .lowBattery: return .red
        case .offline: return .gray
        case .attention: return .orange
        }
    }
}
