import SwiftUI
import UIKit

/// Thin `UIImagePickerController` wrapper. Supports either the user's photo
/// library or the device camera, selected at presentation time. The picked
/// image is delivered to the binding and the sheet dismisses.
struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case library
        case camera
    }

    @Binding var image: UIImage?
    let source: Source
    var onPick: ((UIImage) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        switch source {
        case .library: picker.sourceType = .photoLibrary
        case .camera:
            picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let chosen = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let chosen {
                parent.image = chosen
                parent.onPick?(chosen)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
