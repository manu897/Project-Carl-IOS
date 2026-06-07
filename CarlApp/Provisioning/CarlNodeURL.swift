import Foundation

/// Parsed payload from a sensor node's first-boot QR code:
///   `carl://node?mac=AA:BB:CC:DD:EE:FF&key=<32-hex>`
///
/// MACs are matched case-insensitively; output is uppercase with colons.
/// Keys are 16 bytes (32 lowercase hex chars).
struct CarlNodeURL: Equatable, Sendable {
    let mac: String     // "AA:BB:CC:DD:EE:FF"
    let keyHex: String  // 32 lowercase hex chars

    enum ParseError: LocalizedError {
        case wrongScheme
        case wrongHost
        case missingMac
        case missingKey
        case badMacFormat
        case badKeyLength
        case badKeyHex

        var errorDescription: String? {
            switch self {
            case .wrongScheme:   return "Not a Carl link. Expected a carl:// URL."
            case .wrongHost:     return "Not a node QR — expected carl://node?…"
            case .missingMac:    return "QR is missing the MAC parameter."
            case .missingKey:    return "QR is missing the key parameter."
            case .badMacFormat:  return "MAC address isn't in the expected AA:BB:CC:DD:EE:FF format."
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
        guard url.host?.lowercased() == "node" else { throw ParseError.wrongHost }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let mac = items.first(where: { $0.name == "mac" })?.value else { throw ParseError.missingMac }
        guard let key = items.first(where: { $0.name == "key" })?.value else { throw ParseError.missingKey }

        let normalisedMac = try normaliseMac(mac)
        let normalisedKey = try normaliseKey(key)
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
