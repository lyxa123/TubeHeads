import SwiftUI
import FirebaseAuth
import LocalAuthentication

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var isEmailVerified = false
    @Published var isBiometricAvailable = false
    @Published var shouldRememberCredentials = false
    
    let biometricManager = BiometricAuthManager()
    
    init() {
        checkBiometricAvailability()
    }
    
    // Check if biometric authentication is available and if we have saved credentials
    func checkBiometricAvailability() {
        // Check if biometric is available on the device
        biometricManager.getBiometricType()
        isBiometricAvailable = biometricManager.biometricType != .none && biometricManager.hasSavedCredentials()
    }
    
    // Sign in with email and password
    func signIn(authManager: AuthManager) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            showError = true
            return
        }
        
        do {
            // Sign in with auth manager
            try await authManager.signIn(email: email, password: password)
            
            // Check if email is verified
            if let user = Auth.auth().currentUser {
                // Reload user to get the latest verification status
                try await user.reload()
                isEmailVerified = user.isEmailVerified
                
                if !isEmailVerified {
                    errorMessage = "Your email is not verified. Please verify your email before signing in."
                    showError = true
                } else if shouldRememberCredentials {
                    // Save credentials for biometric login if Remember Me is checked
                    biometricManager.saveUserCredentials(email: email, password: password)
                }
            }
            
            // Refresh token after sign in to ensure valid token
            if Auth.auth().currentUser != nil {
                print("SignInViewModel: Refreshing auth token after sign in")
                try? await authManager.refreshAuthToken()
            }
            
            return
        } catch {
            handleAuthError(error)
        }
    }
    
    // Sign in with biometric authentication
    func signInWithBiometric(authManager: AuthManager) async {
        var isAuthenticated = false
        
        // Wait for the biometric authentication to complete
        await withCheckedContinuation { continuation in
            biometricManager.authenticateWithBiometrics { success in
                isAuthenticated = success
                continuation.resume()
            }
        }
        
        if isAuthenticated {
            // Retrieve saved credentials
            if let credentials = biometricManager.retrieveUserCredentials() {
                email = credentials.email
                password = credentials.password
                
                // Use the retrieved credentials to sign in
                await signIn(authManager: authManager)
            } else {
                errorMessage = "No saved credentials found."
                showError = true
            }
        } else {
            errorMessage = biometricManager.errorMessage
            showError = true
        }
    }
    
    // Remove saved credentials for biometric login
    func removeBiometricCredentials() {
        biometricManager.removeCredentials()
        isBiometricAvailable = false
    }
    
    private func handleAuthError(_ error: Error) {
        print("SignInViewModel: Auth error: \(error.localizedDescription)")
        
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .userNotFound:
                errorMessage = "Account doesn't exist. Please sign up instead."
            case .wrongPassword:
                errorMessage = "Invalid password. Please try again."
            case .invalidEmail:
                errorMessage = "Invalid email format."
            default:
                errorMessage = "Authentication error: \(authError.localizedDescription)"
            }
        } else {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        showError = true
    }
} 