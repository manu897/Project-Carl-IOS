import Foundation

/// Parsed payload from a sensor node's first-boot QR code:
///   `CARL://<12-hex-MAC>/<32-hex-key>`
///
/// e.g. `CARL://aabbccddeeff/4b1f9c8a3e2d6f70b15c4d8a9e3f2c10`
///
/// MACs are matched case-insensitively; output is uppercase with colons.
/// Keys are 16 bytes (32 lowercase hex chars). This mirrors what the
/// firmware actually renders — see `Project-Carl/firmware/node-sensor/src/ui/oled.cpp`
/// and `Project-Carl/tools/provision.py`.
struct CarlNodeURL: Equatable, Sendable {
    let mac: String     // "AA:BB:CC:DD:EE:FF"
    let keyHex: String  // 32 lowercase hex chars

    enum ParseError: LocalizedError, Equatable {
        case wrongScheme
        case missingMac
        case missingKey
        case badMacFormat
        case badKeyLength
        case badKeyHex

        var errorDescription: String? {
            switch self {
            case .wrongScheme:   return "Not a Carl link. Expected a CARL:// URL."
            case .missingMac:    return "QR is missing the node's MAC address."
            case .missingKey:    return "QR is missing the key."
            case .badMacFormat:  return "MAC address isn't in the expected 12-hex-character format."
            case .badKeyLength:  return "Key must be exactly 32 hex characters (16 bytes)."
            case .badKeyHex:     return "Key contains non-hex characters."
            }
        }
    }

    static func parse(_ raw: String) throws -> CarlNodeURL {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ParseError.wrongScheme
        }
        guard url.scheme?.lowercased() == "carl" else { throw ParseError.wrongScheme }
        guard let host = url.host, !host.isEmpty else { throw ParseError.missingMac }

        let keyPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !keyPath.isEmpty else { throw ParseError.missingKey }

        let normalisedMac = try normaliseMac(host)
        let normalisedKey = try normaliseKey(keyPath)
        return CarlNodeURL(mac: normalisedMac, keyHex: normalisedKey)
    }

    /// Build a CarlNodeURL from manually-entered fields. Same validation as `parse`.
    static func from(mac: String, key: String) throws -> CarlNodeURL {
        CarlNodeURL(mac: try normaliseMac(mac), keyHex: try normaliseKey(key))
    }

    // MARK: - Private

    private static let macPattern = #"^[0-9A-Fa-f]{2}([:-]?[0-9A-Fa-f]{2}){5}$"#

    private static func normaliseMac(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: macPattern, options: .regularExpression) != nil else {
            throw ParseError.badMacFormat
        }
        let hex = trimmed.replacingOccurrences(of: ":", with: "")
                         .replacingOccurrences(of: "-", with: "")
                         .uppercased()
        // Re-pair into AA:BB:… form.
        return stride(from: 0, to: hex.count, by: 2).map { i in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: 2)
            return String(hex[start..<end])
        }.joined(separator: ":")
    }

    private static func normaliseKey(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 32 else { throw ParseError.badKeyLength }
        guard trimmed.range(of: #"^[0-9A-Fa-f]{32}$"#, options: .regularExpression) != nil else {
            throw ParseError.badKeyHex
        }
        return trimmed.lowercased()
    }
}
