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
    var nodeType: NodeType?
    var roomId: String?
    var calibration: Calibration?

    enum CodingKeys: String, CodingKey {
        case mac, name, calibration
        case keyHex = "key_hex"
        case nodeType = "node_type"
        case roomId = "room_id"
    }
}

struct NodeUpdate: Codable, Sendable {
    var name: String?
    var nodeType: NodeType?
    var roomId: String?
    var calibration: Calibration?

    enum CodingKeys: String, CodingKey {
        case name, calibration
        case nodeType = "node_type"
        case roomId = "room_id"
    }
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

struct HubError: Codable, Sendable, Error, LocalizedError {
    let code: String
    let message: String

    // Without this, Swift bridges HubError to NSError using its default
    // fallback description — "The operation couldn't be completed.
    // (CarlApp.HubError error 1.)" — which is truly meaningless: the "1" is
    // NOT the HTTP status or anything else in `code`/`message`, just a fixed
    // placeholder for non-LocalizedError types. Every `error.localizedDescription`
    // call in the app (PlantDetailViewModel, HomeViewModel, AddPlantViewModel)
    // was silently showing that useless string instead of `message`.
    var errorDescription: String? { message }
}
