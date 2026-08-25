import Foundation

enum NodeType: String, Codable, Hashable, Sendable {
    case plant
    case room
}

struct RoomEnv: Codable, Hashable, Sendable {
    let source: String
    let ts: Date
    let temperatureC: Double?
    let humidityPct: Double?
    let pressureHpa: Double?
    let illuminanceLux: Double?

    enum CodingKeys: String, CodingKey {
        case source, ts
        case temperatureC = "temperature_c"
        case humidityPct = "humidity_pct"
        case pressureHpa = "pressure_hpa"
        case illuminanceLux = "illuminance_lux"
    }
}

struct Plant: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let mac: String
    var name: String
    var nodeType: NodeType
    var roomId: String
    var lastSeen: Date
    var online: Bool
    var batteryPct: Int?
    var latest: Reading
    var calibration: Calibration?
    var room: RoomEnv?

    var isRoom: Bool { nodeType == .room }

    enum CodingKeys: String, CodingKey {
        case id, mac, name, online, latest, calibration, room
        case nodeType = "node_type"
        case roomId = "room_id"
        case lastSeen = "last_seen"
        case batteryPct = "battery_pct"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mac = try container.decode(String.self, forKey: .mac)
        name = try container.decode(String.self, forKey: .name)
        nodeType = try container.decodeIfPresent(NodeType.self, forKey: .nodeType) ?? .plant
        roomId = try container.decodeIfPresent(String.self, forKey: .roomId) ?? ""
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        online = try container.decode(Bool.self, forKey: .online)
        batteryPct = try container.decodeIfPresent(Int.self, forKey: .batteryPct)
        latest = try container.decode(Reading.self, forKey: .latest)
        calibration = try container.decodeIfPresent(Calibration.self, forKey: .calibration)
        room = try container.decodeIfPresent(RoomEnv.self, forKey: .room)
    }

    init(id: String, mac: String, name: String, nodeType: NodeType = .plant, roomId: String = "",
         lastSeen: Date, online: Bool, batteryPct: Int?, latest: Reading,
         calibration: Calibration? = nil, room: RoomEnv? = nil) {
        self.id = id
        self.mac = mac
        self.name = name
        self.nodeType = nodeType
        self.roomId = roomId
        self.lastSeen = lastSeen
        self.online = online
        self.batteryPct = batteryPct
        self.latest = latest
        self.calibration = calibration
        self.room = room
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
        // Room nodes have no soil sensor — skip the dry check.
        if !isRoom, let soil = latest.soilPct, soil <= cal.soilDryPct { return .dry }
        let staleAfter = TimeInterval(cal.offlineAfterMinutes * 60)
        if now.timeIntervalSince(lastSeen) > staleAfter { return .offline }
        return .ok
    }
}
