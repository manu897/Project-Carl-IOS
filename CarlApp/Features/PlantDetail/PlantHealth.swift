import Foundation

// Generic indoor-houseplant defaults. Per-species ranges live with the plant
// metadata once the catalog ships; until then, every plant uses these.
enum HealthRanges {
    static let temperatureC: ClosedRange<Double> = 18...26
    static let humidityPct: ClosedRange<Double> = 40...70
    static let illuminanceLux: ClosedRange<Double> = 200...2000
}

enum HealthLevel: String {
    case good
    case low
    case high
    case unknown

    var label: String {
        switch self {
        case .good: return "Good"
        case .low: return "Low"
        case .high: return "High"
        case .unknown: return "—"
        }
    }
}

struct PlantHealth {
    let temperature: HealthLevel
    let humidity: HealthLevel
    let light: HealthLevel
    /// Days since the most recent watering event detected in history.
    /// `nil` means no watering event was found in the available window.
    let daysSinceWatered: Int?
    /// Days until the soil reaches the dry threshold at the current drying rate.
    /// `nil` means the rate is non-positive (soil rising/flat) or unknown.
    let daysUntilWater: Int?

    enum Summary {
        case healthy
        case needsWater
        case offline
        case lowBattery
        case attention(reason: String)

        var label: String {
            switch self {
            case .healthy: return "Healthy"
            case .needsWater: return "Needs water"
            case .offline: return "Offline"
            case .lowBattery: return "Battery low"
            case .attention(let reason): return reason
            }
        }
    }

    static func summary(for plant: Plant) -> Summary {
        switch plant.status() {
        case .offline: return .offline
        case .lowBattery: return .lowBattery
        case .dry: return .needsWater
        case .ok: return .healthy
        }
    }

    static func assess(plant: Plant, history: [Reading]) -> PlantHealth {
        PlantHealth(
            temperature: classify(plant.latest.temperatureC, in: HealthRanges.temperatureC),
            humidity: classify(plant.latest.humidityPct, in: HealthRanges.humidityPct),
            light: classify(plant.latest.illuminanceLux, in: HealthRanges.illuminanceLux),
            daysSinceWatered: detectLastWatering(history: history),
            daysUntilWater: predictDaysUntilDry(plant: plant, history: history)
        )
    }

    private static func classify(_ value: Double?, in range: ClosedRange<Double>) -> HealthLevel {
        guard let value else { return .unknown }
        if range.contains(value) { return .good }
        return value < range.lowerBound ? .low : .high
    }

    /// Detect a watering by looking for a soil-moisture rising edge: a sample
    /// where soil_pct jumped by ≥ 10 points within roughly an hour. Returns
    /// integer days since that event. Conservative — better to say "—" than
    /// invent a date.
    private static func detectLastWatering(history: [Reading], now: Date = .now) -> Int? {
        let sorted = history.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 2 else { return nil }

        var lastEvent: Date?
        for i in 1..<sorted.count {
            guard let prev = sorted[i - 1].soilPct,
                  let curr = sorted[i].soilPct else { continue }
            let dt = sorted[i].timestamp.timeIntervalSince(sorted[i - 1].timestamp)
            guard dt > 0, dt <= 90 * 60 else { continue }
            if curr - prev >= 10 {
                lastEvent = sorted[i].timestamp
            }
        }
        guard let lastEvent else { return nil }
        let days = now.timeIntervalSince(lastEvent) / 86_400
        return Int(days.rounded())
    }

    /// Linear extrapolation: project current drying rate to the dry threshold.
    /// Uses the last ~12 hours of samples for a stable rate.
    private static func predictDaysUntilDry(plant: Plant, history: [Reading], now: Date = .now) -> Int? {
        guard let currentSoil = plant.latest.soilPct else { return nil }
        let dryThreshold = (plant.calibration ?? .default).soilDryPct
        if currentSoil <= dryThreshold { return 0 }

        let cutoff = now.addingTimeInterval(-12 * 3600)
        let window = history
            .filter { $0.timestamp >= cutoff && $0.soilPct != nil }
            .sorted { $0.timestamp < $1.timestamp }
        guard let first = window.first, let last = window.last,
              let firstSoil = first.soilPct, let lastSoil = last.soilPct,
              first.timestamp != last.timestamp else { return nil }

        let hours = last.timestamp.timeIntervalSince(first.timestamp) / 3600
        let dropPerDay = (firstSoil - lastSoil) / hours * 24
        guard dropPerDay > 0.1 else { return nil }

        let daysUntilDry = (currentSoil - dryThreshold) / dropPerDay
        return max(0, Int(daysUntilDry.rounded()))
    }
}
