import Foundation

extension JSONDecoder {
    /// JSON decoder tuned for the Carl hub HTTP API.
    ///
    /// Accepts two timestamp shapes for `ts` / `last_seen`:
    /// - ISO 8601 (what the hub will emit once Phase 3d adds SNTP)
    /// - Integer-as-string seconds-ago (the Phase 3a–3c output, pre-RTC sync)
    ///
    /// Forward-compatible: the moment hub firmware starts returning ISO 8601,
    /// no iOS change is needed. The relative-seconds path stays around as a
    /// fallback for older hub builds.
    static func carlHub() -> JSONDecoder {
        let decoder = JSONDecoder()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            if let date = iso.date(from: raw) ?? isoWithFractional.date(from: raw) {
                return date
            }
            if let seconds = Int(raw) {
                return Date().addingTimeInterval(-Double(seconds))
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse \"\(raw)\" as ISO 8601 timestamp or seconds-ago integer"
            )
        }
        return decoder
    }
}
