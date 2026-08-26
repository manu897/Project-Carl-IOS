import Foundation

struct Reading: Codable, Hashable, Sendable {
    var timestamp: Date
    var temperatureC: Double? = nil
    var humidityPct: Double? = nil
    var pressureHpa: Double? = nil
    var soilPct: Double? = nil
    var illuminanceLux: Double? = nil
    var batteryPct: Int? = nil

    enum CodingKeys: String, CodingKey {
        case timestamp = "ts"
        case temperatureC = "temperature_c"
        case humidityPct = "humidity_pct"
        case pressureHpa = "pressure_hpa"
        case soilPct = "soil_pct"
        case illuminanceLux = "illuminance_lux"
        case batteryPct = "battery_pct"
    }
}
