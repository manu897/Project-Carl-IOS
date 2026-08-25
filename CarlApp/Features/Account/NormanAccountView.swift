import SwiftUI

/// Sign in / create an account with Norman so plants stay visible when away
/// from the hub's Wi-Fi. Entirely optional — the app works LAN-only without it.
struct NormanAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var auth: NormanAuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var mode: Mode = .login

    private enum Mode: String, CaseIterable {
        case login = "Sign In"
        case register = "Create Account"
    }

    var body: some View {
        NavigationStack {
            Form {
                if auth.isSignedIn {
                    signedInSection
                } else {
                    signedOutSections
                }
            }
            .navigationTitle("Cloud Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var signedInSection: some View {
        Section {
            LabeledContent("Signed in as", value: auth.email ?? "—")
            Button("Sign Out", role: .destructive) {
                auth.signOut()
            }
        } footer: {
            Text("Plants will keep showing while you're on your home Wi-Fi even if you sign out — signing out only turns off the away-from-home fallback.")
        }
    }

    @ViewBuilder
    private var signedOutSections: some View {
        Section {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        Section {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
        } footer: {
            Text(mode == .login
                 ? "Sign in to see your plants when you're away from home Wi-Fi."
                 : "Create a Norman account to enable the away-from-home fallback. This doesn't affect your hub or plants — it just mirrors readings to the cloud.")
        }

        if let error = auth.errorMessage {
            Section {
                Text(error).foregroundStyle(.red)
            }
        }

        Section {
            Button {
                submit()
            } label: {
                if auth.isWorking {
                    ProgressView()
                } else {
                    Text(mode.rawValue)
                }
            }
            .disabled(!canSubmit || auth.isWorking)
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8
    }

    private func submit() {
        Task {
            switch mode {
            case .login:
                await auth.login(email: email, password: password)
            case .register:
                await auth.register(email: email, password: password)
            }
        }
    }
}

#Preview {
    NormanAccountView(auth: NormanAuthManager())
}
