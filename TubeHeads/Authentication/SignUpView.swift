import SwiftUI
import FirebaseAuth

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var username = ""
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var verificationEmailSent = false
    
    func signUp(authManager: AuthManager) async {
        print("SignUpViewModel: Starting sign up process")
        
        // Validate input
        if email.isEmpty || password.isEmpty || username.isEmpty {
            errorMessage = "Please fill in all fields."
            showError = true
            return
        }
        
        if password != confirmPassword {
            errorMessage = "Passwords don't match."
            showError = true
            return
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            showError = true
            return
        }
        
        // Check if username is valid (only alphanumeric and underscore)
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        if !usernamePredicate.evaluate(with: username) {
            errorMessage = "Username must be 3-20 characters and contain only letters, numbers, and underscores."
            showError = true
            return
        }
        
        // Check if username already exists
        do {
            print("SignUpViewModel: Checking if username exists")
            let usernameExists = try await UserManager.shared.usernameExists(username)
            if usernameExists {
                errorMessage = "Username already taken. Please choose another."
                showError = true
                return
            }
            
            print("SignUpViewModel: Creating account")
            // Create user with our AuthManager
            try await authManager.createAccount(email: email, password: password, username: username)
            
            // Send email verification
            if let user = Auth.auth().currentUser {
                try await user.sendEmailVerification()
                print("SignUpViewModel: Verification email sent to \(email)")
                verificationEmailSent = true
            }
            
            // Refresh token to ensure valid token
            print("SignUpViewModel: Refreshing auth token after signup")
            try await authManager.refreshAuthToken()
            
            return
        } catch {
            print("SignUpViewModel: Error during signup: \(error.localizedDescription)")
            handleAuthError(error)
        }
    }
    
    private func handleAuthError(_ error: Error) {
        print("SignUpViewModel: Auth error: \(error.localizedDescription)")
        
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .emailAlreadyInUse:
                errorMessage = "Account already exists. Please sign in instead."
            case .weakPassword:
                errorMessage = "Password is too weak. Please use a stronger password."
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

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showSignInView: Bool
    @State private var isLoading = false
    @State private var firebaseError: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            TextField("Email", text: $viewModel.email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            TextField("Username", text: $viewModel.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            SecureField("Confirm Password", text: $viewModel.confirmPassword)
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
            
            if viewModel.verificationEmailSent {
                Text("Verification email sent! Please check your inbox.")
                    .foregroundColor(.green)
                    .padding(.vertical, 5)
            }
            
            Button {
                Task {
                    // Debug auth state before sign up
                    print("SignUpView: Checking auth state before sign up")
                    // authManager.debugAuthState()
                    
                    isLoading = true
                    do {
                        await viewModel.signUp(authManager: authManager)
                        
                        // Check for any Firestore-related errors after signup
                        if Auth.auth().currentUser != nil {
                            do {
                                if let uid = Auth.auth().currentUser?.uid {
                                    // Try to access user data to verify Firestore permissions
                                    let _ = try await UserManager.shared.getUser(userId: uid)
                                    print("SignUpView: Successfully accessed Firestore after sign up")
                                }
                            } catch {
                                firebaseError = "Firestore access error: \(error.localizedDescription)"
                                print("SignUpView: \(firebaseError!)")
                            }
                        }
                        
                        isLoading = false
                        if !viewModel.showError {
                            showSignInView = false
                        }
                    } catch {
                        isLoading = false
                        print("SignUpView: Error during sign up process: \(error.localizedDescription)")
                    }
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("Create Account")
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
                SignInView(showSignInView: $showSignInView)
            } label: {
                Text("Already have an account? Sign In")
                    .foregroundColor(.blue)
                    .padding(.top, 15)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Sign Up")
        .disabled(isLoading)
        .onAppear {
            // Clear all errors when view appears
            viewModel.showError = false
            firebaseError = nil
            viewModel.verificationEmailSent = false
            // Check initial auth state
            // authManager.debugAuthState()
        }
    }
} 