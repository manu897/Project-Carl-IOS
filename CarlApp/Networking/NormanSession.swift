import Foundation

/// Pure, thread-safe accessor for the signed-in Norman account. Kept separate
/// from `NormanAuthManager` (which is `@MainActor`, UI-facing) so background
/// contexts — `NormanClient`'s token provider, the background alerts refresh —
/// can read the token without hopping to the main actor.
enum NormanSession {
    private static let tokenKey = "accessToken"
    private static let emailDefaultsKey = "NormanSession.email"

    static var token: String? {
        KeychainStore.get(tokenKey)
    }

    static var email: String? {
        get { UserDefaults.standard.string(forKey: emailDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: emailDefaultsKey) }
    }

    static var isSignedIn: Bool {
        token != nil
    }

    static func save(token: String, email: String) {
        KeychainStore.set(token, for: tokenKey)
        Self.email = email
        UserDefaults.standard.set(true, forKey: SettingsKeys.normanSignedIn)
    }

    static func clear() {
        KeychainStore.delete(tokenKey)
        email = nil
        UserDefaults.standard.set(false, forKey: SettingsKeys.normanSignedIn)
    }
}
