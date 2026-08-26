import Foundation

/// File-backed cache of the last successful plant list, so the app can show
/// something instantly on launch instead of a blank spinner — then refresh
/// once the real fetch (LAN or cloud) resolves. This is intentionally the
/// *last* tier after LAN and cloud, not a replacement for either: history
/// charts always fetch fresh on demand, this only covers the home-list
/// summary view.
final class PlantCacheStore: @unchecked Sendable {
    static let shared = PlantCacheStore()

    struct Snapshot: Codable, Sendable {
        let plants: [Plant]
        let fetchedAt: Date
    }

    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.decoder = .carlHub()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    private static var defaultFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("plants-cache.json")
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(Snapshot.self, from: data)
    }

    func save(_ plants: [Plant], fetchedAt: Date) {
        let snapshot = Snapshot(plants: plants, fetchedAt: fetchedAt)
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
