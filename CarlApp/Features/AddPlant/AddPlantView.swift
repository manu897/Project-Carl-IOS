import SwiftUI
import UIKit

struct AddPlantView: View {
    @State private var viewModel: AddPlantViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called after the user successfully adds a plant so the parent (Home)
    /// can refresh its list.
    var onAdded: (() -> Void)?

    @State private var showingScanner = false
    @State private var showingImageSource = false
    @State private var imagePickerSource: ImagePicker.Source?

    init(repository: any PlantRepository, onAdded: (() -> Void)? = nil) {
        _viewModel = State(initialValue: AddPlantViewModel(repository: repository))
        self.onAdded = onAdded
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                nodeSection
                detailsSection
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add a Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Add") { submit() }
                            .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerSheet { code in
                    showingScanner = false
                    viewModel.applyScanned(code)
                }
            }
            .confirmationDialog("Plant photo", isPresented: $showingImageSource, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { imagePickerSource = .camera }
                }
                Button("Choose from Library") { imagePickerSource = .library }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $imagePickerSource) { source in
                ImagePicker(image: $viewModel.photo, source: source)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            HStack {
                photoView
                Spacer()
                Button(viewModel.photo == nil ? "Add Photo" : "Replace Photo") {
                    showingImageSource = true
                }
            }
        } header: {
            Text("Plant photo")
        } footer: {
            Text("Optional. A picture helps you tell your plants apart at a glance.")
        }
    }

    private var photoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
            if let img = viewModel.photo {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 64, height: 64)
        .clipped()
    }

    private var nodeSection: some View {
        Section {
            Button {
                showingScanner = true
            } label: {
                Label("Scan node QR", systemImage: "qrcode.viewfinder")
            }
            TextField("MAC (AA:BB:CC:DD:EE:FF)", text: $viewModel.mac)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
            SecureField("Key (32 hex characters)", text: $viewModel.keyHex)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
        } header: {
            Text("Sensor node")
        } footer: {
            Text("Scan the QR on your sensor's first-boot screen, or type the MAC and key manually.")
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("e.g. Kitchen Basil", text: $viewModel.name)
        } header: {
            Text("Plant name")
        }
    }

    // MARK: - Actions

    private func submit() {
        Task {
            let ok = await viewModel.submit()
            if ok {
                onAdded?()
                dismiss()
            }
        }
    }
}

// MARK: - Scanner sheet

private struct ScannerSheet: View {
    var onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRScannerView(
                    onCode: { code in onCode(code) },
                    onError: { msg in error = msg }
                )
                .ignoresSafeArea()
                if let error {
                    Text(error)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                } else {
                    Text("Point your camera at the node's QR code")
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension ImagePicker.Source: Identifiable {
    var id: String {
        switch self {
        case .library: return "library"
        case .camera:  return "camera"
        }
    }
}
