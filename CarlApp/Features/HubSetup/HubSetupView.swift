import SwiftUI

struct HubSetupView: View {
    @State private var viewModel = HubSetupViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Hub Wi-Fi Setup")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .instructions:
            instructionsView
        case .form, .submitting:
            formView
        case .success:
            successView
        case .failed(let message):
            failedView(message)
        }
    }

    // MARK: - Stages

    private var instructionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepCard(
                    number: "1",
                    title: "Power on your Carl hub",
                    body: "On first boot the hub broadcasts a Wi-Fi network named **Carl-Hub-Setup** for one minute."
                )
                stepCard(
                    number: "2",
                    title: "Join Carl-Hub-Setup from iOS Settings",
                    body: "Open the Settings app → Wi-Fi → tap **Carl-Hub-Setup**. There's no password."
                )
                stepCard(
                    number: "3",
                    title: "Come back here",
                    body: "Once your iPhone is on the hub's network, tap **Continue** below to send your home Wi-Fi credentials."
                )

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open iOS Wi-Fi Settings", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)

                Button {
                    viewModel.startForm()
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    private var formView: some View {
        Form {
            Section {
                TextField("Home Wi-Fi name (SSID)", text: $viewModel.ssid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $viewModel.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Home Wi-Fi")
            } footer: {
                Text("The hub will reboot and join this network. It then becomes reachable at carl-hub.local.")
            }

            Section {
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    HStack {
                        if viewModel.stage == .submitting {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(viewModel.stage == .submitting ? "Sending…" : "Send to hub")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.canSubmit)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Hub is rebooting")
                .font(.title2.weight(.semibold))
            Text("Once your phone reconnects to your home Wi-Fi, return to My Plants and pull down to refresh.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("Couldn't reach the hub")
                .font(.title2.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Try again") { viewModel.reset() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Building blocks

    private func stepCard(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(number)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(try! AttributedString(markdown: body))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HubSetupView()
}
