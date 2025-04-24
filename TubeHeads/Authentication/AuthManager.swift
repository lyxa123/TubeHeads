import SwiftUI
import FirebaseAuth

class AuthManager: ObservableObject {
    @Published var currentUser: AuthDataResultModel?
    @Published var isSignedIn: Bool = false
    @Published var isEmailVerified: Bool = false
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.currentUser = AuthDataResultModel(user: user)
                self?.isSignedIn = true
                self?.isEmailVerified = user.isEmailVerified
            } else {
                self?.currentUser = nil
                self?.isSignedIn = false
                self?.isEmailVerified = false
            }
        }
    }
    
    // Simple debug function to check authentication state
    func debugAuthState() {
        if Auth.auth().currentUser != nil {
            print("User is signed in")
        } else {
            print("No user is currently signed in")
        }
    }
    
    func createAccount(email: String, password: String, username: String) async throws {
        do {
            let authResult = try await AuthenticationManager.shared.createUser(email: email, password: password)
            try await UserManager.shared.createNewUser(auth: authResult, username: username)
            
            currentUser = authResult
            isSignedIn = true
        } catch {
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let authResult = try await AuthenticationManager.shared.signInUser(email: email, password: password)
            currentUser = authResult
            isSignedIn = true
            
            // Check email verification status
            if let user = Auth.auth().currentUser {
                // Reload user to get the latest verification status
                try await user.reload()
                isEmailVerified = user.isEmailVerified
            }
        } catch {
            throw error
        }
    }
    
    func refreshAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        
        do {
            let tokenResult = try await user.getIDTokenResult(forcingRefresh: true)
            return tokenResult.token
        } catch {
            throw error
        }
    }
    
    func signOut() {
        do {
            try AuthenticationManager.shared.SignOut()
            currentUser = nil
            isSignedIn = false
            isEmailVerified = false
        } catch {
            // Silently handle sign out errors
        }
    }
    
    func resetPassword(email: String) async throws {
        try await AuthenticationManager.shared.resetPassword(email: email)
    }
    
    func updatePassword(password: String) async throws {
        try await AuthenticationManager.shared.updatePassword(password: password)
    }
    
    func updateEmail(email: String) async throws {
        try await AuthenticationManager.shared.updateEmail(email: email)
    }
    
    func getCurrentUsername() async -> String? {
        guard let userId = currentUser?.uid else { return nil }
        
        do {
            let userData = try await UserManager.shared.getUser(userId: userId)
            return userData.username
        } catch {
            return "User" // Return a default value so the app can continue
        }
    }
    
    func checkEmailVerification() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            return false
        }
        
        do {
            // Reload user to get the latest verification status
            try await user.reload()
            
            // Update the published property
            isEmailVerified = user.isEmailVerified
            
            // Log verification status for debugging
            print("Email verification status: \(user.isEmailVerified)")
            
            return user.isEmailVerified
        } catch {
            print("Error reloading user: \(error.localizedDescription)")
            return false
        }
    }
    
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        
        do {
            try await user.sendEmailVerification()
            print("Verification email sent to: \(user.email ?? "unknown email")")
        } catch {
            print("Error sending verification email: \(error.localizedDescription)")
            throw error
        }
    }
} 