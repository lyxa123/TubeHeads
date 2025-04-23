import SwiftUI
import FirebaseAuth

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var showError = false
    
    func signIn(authManager: AuthManager) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            showError = true
            return
        }
        
        do {
            // Sign in with auth manager
            try await authManager.signIn(email: email, password: password)
            
            // Refresh token after sign in to ensure valid token
            if Auth.auth().currentUser != nil {
                print("SignInViewModel: Refreshing auth token after sign in")
                try? await authManager.refreshAuthToken()
            }
            
            // Debug auth state after signing in
            // authManager.debugAuthState()
            
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

struct SignInView: View {
    @StateObject private var viewModel = SignInViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showSignInView: Bool
    @State private var isLoading = false
    @State private var firebaseError: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            TextField("Email", text: $viewModel.email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            if viewModel.showError {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .padding(.vertical, 5)
            }
            
            if let error = firebaseError {
                Text("Firebase error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.vertical, 5)
                    .onAppear {
                        // Clear error after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            firebaseError = nil
                        }
                    }
            }
            
            Button {
                Task {
                    isLoading = true
                    
                    // Debug auth state before signing in
                    print("SignInView: Checking auth state before sign in")
                    // authManager.debugAuthState()
                    
                    do {
                        await viewModel.signIn(authManager: authManager)
                        
                        // Check for any Firestore-related errors
                        if Auth.auth().currentUser != nil {
                            do {
                                if let uid = Auth.auth().currentUser?.uid {
                                    // Try to access user data to verify Firestore permissions
                                    let _ = try await UserManager.shared.getUser(userId: uid)
                                    print("SignInView: Successfully accessed Firestore after sign in")
                                }
                            } catch {
                                firebaseError = "Firestore access error: \(error.localizedDescription)"
                                print("SignInView: \(firebaseError!)")
                            }
                        }
                        
                        isLoading = false
                        if !viewModel.showError {
                            showSignInView = false
                        }
                    } catch {
                        isLoading = false
                        print("SignInView: Error during sign in process: \(error.localizedDescription)")
                    }
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#f6bebe"))
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
            }
            .disabled(isLoading)
            
            NavigationLink {
                SignUpView(showSignInView: $showSignInView)
            } label: {
                Text("Don't have an account? Sign Up")
                    .foregroundColor(.blue)
                    .padding(.top, 15)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Sign In")
        .disabled(isLoading)
    }
} 