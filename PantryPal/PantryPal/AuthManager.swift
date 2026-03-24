import Foundation
import Combine
@preconcurrency import FirebaseAuth

@MainActor
final class AuthManager: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userEmail: String = ""
    @Published var userID: String? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    private var handle: AuthStateDidChangeListenerHandle?

    /// Nickname saved to Firebase Auth profile, falls back to email prefix.
    var displayName: String {
        Auth.auth().currentUser?.displayName?.isEmpty == false
            ? Auth.auth().currentUser!.displayName!
            : userEmail.components(separatedBy: "@").first?.capitalized ?? "there"
    }

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // Extract values on whatever thread Firebase calls back on,
            // then hop to the main actor to update published properties.
            let uid      = user?.uid
            let email    = user?.email ?? ""
            let signedIn = user != nil
            Task { @MainActor [weak self] in
                self?.isSignedIn = signedIn
                self?.userEmail  = email
                self?.userID     = uid
            }
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading    = true
        errorMessage = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            print("🔴 SIGN IN ERROR: \(error)")
            print("🔴 CODE: \((error as NSError).code)")
            print("🔴 DOMAIN: \((error as NSError).domain)")
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, nickname: String) async {
        isLoading    = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // Save nickname to Firebase Auth profile
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = nickname
            try await changeRequest.commitChanges()
            // Auth state listener fires automatically → user is taken straight into the app
        } catch {
            print("🔴 SIGN UP ERROR: \(error)")
            print("🔴 CODE: \((error as NSError).code)")
            print("🔴 DOMAIN: \((error as NSError).domain)")
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    // MARK: - Reset Password

    func resetPassword(email: String) async -> Bool {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch {
            errorMessage = friendlyError(error)
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Friendly Error Messages
    // Uses raw NSError codes from Firebase Auth to avoid enum API version issues.
    // Full list: https://firebase.google.com/docs/auth/ios/errors

    private func friendlyError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17007: return "That email is already registered. Try signing in."
        case 17008: return "Please enter a valid email address."
        case 17009: return "Incorrect password. Please try again."
        case 17010: return "Too many attempts. Please wait a moment and try again."
        case 17011: return "Email not found. Please check your email or create a new account."
        case 17020: return "Network error. Check your connection and try again."
        case 17026: return "Password must be at least 6 characters."
        case 17004: return "Invalid credentials. Please check your email and password."
        default:    return error.localizedDescription
        }
    }
}
