import SwiftUI
import FirebaseAuth

class AuthManager: ObservableObject {
    // New private cached user struct for offline support
    struct CachedAuthUser: Codable {
        let uid: String
        let email: String?
        var isEmailVerified: Bool
        var username: String?
        
        init(uid: String, email: String?, isEmailVerified: Bool, username: String? = nil) {
            self.uid = uid
            self.email = email
            self.isEmailVerified = isEmailVerified
            self.username = username
        }
        
        init(fromUser user: User, username: String? = nil) {
            self.uid = user.uid
            self.email = user.email
            self.isEmailVerified = user.isEmailVerified
            self.username = username
        }
    }

    // Published properties remain the same, but currentUser is now CachedAuthUser?
        @Published var currentUser: CachedAuthUser? {
        didSet {
            cacheCurrentUser()
        }
    }
    @Published var isSignedIn: Bool = false
    @Published var isEmailVerified: Bool = false
    
    private let userDefaultsKey = "CachedAuthUserKey"
    
    init() {
        // Load cached user for offline support
        loadCachedUser()
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                Task {
                    let username = await self?.fetchUsername(userId: user.uid)
                    DispatchQueue.main.async {
                        let cachedUser = CachedAuthUser(fromUser: user, username: username)
                        self?.currentUser = cachedUser
                        self?.isSignedIn = true
                        self?.isEmailVerified = user.isEmailVerified
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.currentUser = nil
                    self?.isSignedIn = false
                    self?.isEmailVerified = false
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func cacheCurrentUser() {
        guard let user = currentUser else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return
        }
        do {
            let data = try JSONEncoder().encode(user)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("AuthManager: Failed to cache user: \(error.localizedDescription)")
        }
    }
    
    private func loadCachedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let cachedUser = try? JSONDecoder().decode(CachedAuthUser.self, from: data) else {
            return
        }
        currentUser = cachedUser
        isSignedIn = true
        isEmailVerified = cachedUser.isEmailVerified
    }
    
    // MARK: - Auth Functions
    
    func createAccount(email: String, password: String, username: String) async throws {
        do {
            let authResult = try await AuthenticationManager.shared.createUser(email: email, password: password)
            try await UserManager.shared.createNewUser(auth: authResult, username: username)
            
            let cachedUser = CachedAuthUser(uid: authResult.uid,
                                            email: authResult.email,
                                            isEmailVerified: false,
                                            username: username)
            
            DispatchQueue.main.async {
                self.currentUser = cachedUser
                self.isSignedIn = true
                self.isEmailVerified = false
            }
        } catch {
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let authResult = try await AuthenticationManager.shared.signInUser(email: email, password: password)
            let username = await fetchUsername(userId: authResult.uid)
            let cachedUser = CachedAuthUser(uid: authResult.uid,
                                            email: authResult.email,
                                            isEmailVerified: false,
                                            username: username)
            
            DispatchQueue.main.async {
                self.currentUser = cachedUser
                self.isSignedIn = true
                
                // Reload user to update verification status
                Task {
                    do {
                        try await Auth.auth().currentUser?.reload()
                        DispatchQueue.main.async {
                            if let user = Auth.auth().currentUser {
                                self.isEmailVerified = user.isEmailVerified
                                // Update cached user accordingly
                                self.currentUser?.isEmailVerified = user.isEmailVerified
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.isEmailVerified = cachedUser.isEmailVerified
                            print("AuthManager: Reload failed, using cached email verification")
                        }
                    }
                }
            }
        } catch {
            throw error
        }
    }
    
    func refreshAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        let tokenResult = try await user.getIDTokenResult(forcingRefresh: true)
        return tokenResult.token
    }
    
    func signOut() {
        do {
            try AuthenticationManager.shared.SignOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isSignedIn = false
                self.isEmailVerified = false
            }
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        } catch {
            print("AuthManager: Sign out error: \(error.localizedDescription)")
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
        if let username = currentUser?.username {
            return username
        }
        guard let uid = currentUser?.uid else { return nil }
        return await fetchUsername(userId: uid)
    }
    
    func checkEmailVerification() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                self.isEmailVerified = false
            }
            return false
        }
        
        do {
            try await user.reload()
            DispatchQueue.main.async {
                self.isEmailVerified = user.isEmailVerified
                self.currentUser?.isEmailVerified = user.isEmailVerified
            }
            return user.isEmailVerified
        } catch {
            DispatchQueue.main.async {
                self.isEmailVerified = user.isEmailVerified
            }
            print("AuthManager: Reload failed, using cached email verification")
            return user.isEmailVerified
        }
    }
    
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        try await user.sendEmailVerification()
        print("Verification email sent to: \(user.email ?? "unknown email")")
    }
    
    // MARK: - Helper to fetch username
    
    private func fetchUsername(userId: String) async -> String? {
        do {
            let userData = try await UserManager.shared.getUser(userId: userId)
            return userData.username
        } catch {
            print("AuthManager: Failed to fetch username: \(error.localizedDescription)")
            return nil
        }
    }
}
