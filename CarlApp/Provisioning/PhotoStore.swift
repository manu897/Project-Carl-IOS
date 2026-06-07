import Foundation
import UIKit

/// File-backed plant-profile photo store. One JPEG per node id under
/// `Documents/plants/<id>.jpg`. Image is downscaled to ~1024 px long edge
/// before writing.
///
/// Cloud upload to Norman lives behind this same API (TODO when the
/// `PUT /v1/plants/{id}/profile-photo` endpoint ships) — call sites won't
/// have to change.
final class PhotoStore: @unchecked Sendable {
    static let shared = PhotoStore()

    private let folder: URL

    init(folder: URL? = nil) {
        let base = folder ?? Self.defaultFolder
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.folder = base
    }

    private static var defaultFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("plants", isDirectory: true)
    }

    func url(for nodeId: String) -> URL {
        folder.appendingPathComponent("\(nodeId).jpg")
    }

    func save(_ image: UIImage, for nodeId: String) throws {
        let resized = downscale(image, maxLongEdge: 1024)
        guard let data = resized.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "PhotoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't encode JPEG."])
        }
        try data.write(to: url(for: nodeId), options: .atomic)
    }

    func loadImage(for nodeId: String) -> UIImage? {
        let path = url(for: nodeId)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return UIImage(contentsOfFile: path.path)
    }

    func delete(for nodeId: String) {
        try? FileManager.default.removeItem(at: url(for: nodeId))
    }

    // MARK: - Private

    private func downscale(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > maxLongEdge else { return image }
        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
