import Foundation

final class SpeciesStore: @unchecked Sendable {
    static let shared = SpeciesStore()

    private let folder: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        return enc
    }()

    init(folder: URL? = nil) {
        let base = folder ?? Self.defaultFolder
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.folder = base
    }

    private static var defaultFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("plants", isDirectory: true)
    }

    private func url(for nodeId: String) -> URL {
        folder.appendingPathComponent("\(nodeId)-species.json")
    }

    func save(_ species: SpeciesInfo, for nodeId: String) throws {
        let data = try encoder.encode(species)
        try data.write(to: url(for: nodeId), options: .atomic)
    }

    func load(for nodeId: String) -> SpeciesInfo? {
        let path = url(for: nodeId)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? decoder.decode(SpeciesInfo.self, from: data)
    }

    func delete(for nodeId: String) {
        try? FileManager.default.removeItem(at: url(for: nodeId))
    }
}
