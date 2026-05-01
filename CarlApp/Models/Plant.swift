import Foundation

struct Plant: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let mac: String
    var name: String
    var lastSeen: Date
    var online: Bool
    var batteryPct: Int?
    var latest: Reading
    var calibration: Calibration?

    enum CodingKeys: String, CodingKey {
        case id, mac, name, online, latest, calibration
        case lastSeen = "last_seen"
        case batteryPct = "battery_pct"
    }
}

extension Plant {
    enum Status {
        case ok, dry, lowBattery, offline
    }

    func status(now: Date = .now) -> Status {
        if !online { return .offline }
        let cal = calibration ?? .default
        if let battery = batteryPct, battery <= cal.batteryLowPct { return .lowBattery }
        if let soil = latest.soilPct, soil <= cal.soilDryPct { return .dry }
        let staleAfter = TimeInterval(cal.offlineAfterMinutes * 60)
        if now.timeIntervalSince(lastSeen) > staleAfter { return .offline }
        return .ok
    }
}
