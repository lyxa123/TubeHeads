import SwiftUI
import FirebaseAuth

class AuthManager: ObservableObject {
    @Published var currentUser: AuthDataResultModel?
    @Published var isSignedIn: Bool = false
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.currentUser = AuthDataResultModel(user: user)
                self?.isSignedIn = true
            } else {
                self?.currentUser = nil
                self?.isSignedIn = false
            }
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
} 