import Foundation

struct Calibration: Codable, Hashable, Sendable {
    var soilDryPct: Double = 25.0
    var soilWetPct: Double = 65.0
    var batteryLowPct: Int = 15
    var offlineAfterMinutes: Int = 30

    enum CodingKeys: String, CodingKey {
        case soilDryPct = "soil_dry_pct"
        case soilWetPct = "soil_wet_pct"
        case batteryLowPct = "battery_low_pct"
        case offlineAfterMinutes = "offline_after_minutes"
    }

    static let `default` = Calibration()
}
