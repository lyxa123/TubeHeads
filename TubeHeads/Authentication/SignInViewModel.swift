import SwiftUI
import FirebaseAuth

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var isEmailVerified = false
    
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