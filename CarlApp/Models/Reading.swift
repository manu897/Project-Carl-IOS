import Foundation

struct Reading: Codable, Hashable, Sendable {
    let timestamp: Date
    var temperatureC: Double?
    var humidityPct: Double?
    var pressureHpa: Double?
    var soilPct: Double?
    var illuminanceLux: Double?
    var batteryPct: Int?

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
