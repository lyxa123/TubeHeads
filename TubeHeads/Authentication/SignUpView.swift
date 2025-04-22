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
    
    func signUp(authManager: AuthManager) async {
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
            let usernameExists = try await UserManager.shared.usernameExists(username)
            if usernameExists {
                errorMessage = "Username already taken. Please choose another."
                showError = true
                return
            }
            
            // Create user with our AuthManager
            try await authManager.createAccount(email: email, password: password, username: username)
            
            return
        } catch {
            handleAuthError(error)
        }
    }
    
    private func handleAuthError(_ error: Error) {
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
            
            Button {
                Task {
                    isLoading = true
                    await viewModel.signUp(authManager: authManager)
                    isLoading = false
                    if !viewModel.showError {
                        showSignInView = false
                    }
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                } else {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                }
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
    }
} 