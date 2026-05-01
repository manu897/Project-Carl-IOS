import Foundation

struct HubHealth: Codable, Sendable {
    let hubId: String
    let version: String
    let uptimeSeconds: Int64
    let nodeCount: Int
    let wifiRssiDbm: Int?

    enum CodingKeys: String, CodingKey {
        case hubId = "hub_id"
        case version
        case uptimeSeconds = "uptime_s"
        case nodeCount = "node_count"
        case wifiRssiDbm = "wifi_rssi_dbm"
    }
}

struct History: Codable, Sendable {
    let nodeId: String
    let range: Range
    let samples: [Reading]

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case range
        case samples
    }

    enum Range: String, Codable, CaseIterable, Sendable {
        case h24 = "24h"
        case d7 = "7d"
        case d30 = "30d"

        var label: String {
            switch self {
            case .h24: return "24h"
            case .d7: return "7d"
            case .d30: return "30d"
            }
        }
    }
}

struct NodeCreate: Codable, Sendable {
    let mac: String
    let keyHex: String
    let name: String
    var calibration: Calibration?

    enum CodingKeys: String, CodingKey {
        case mac, name, calibration
        case keyHex = "key_hex"
    }
}

struct NodeUpdate: Codable, Sendable {
    var name: String?
    var calibration: Calibration?
}

struct WifiCreds: Codable, Sendable {
    let ssid: String
    let psk: String
}

struct StreamFrame: Codable, Sendable {
    let type: Kind
    let nodeId: String
    let payload: Reading?

    enum Kind: String, Codable, Sendable {
        case reading, online, offline
    }

    enum CodingKeys: String, CodingKey {
        case type
        case nodeId = "node_id"
        case payload
    }
}

struct HubError: Codable, Sendable, Error {
    let code: String
    let message: String
}
