import SwiftUI
import FirebaseAuth

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var errorMessage = ""
    @Published var showError = false
    
    func signUp() async {
        // Validate input
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please enter both email and password."
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
        
        do {
            try await AuthenticationManager.shared.createUser(email: email, password: password)
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
                    await viewModel.signUp()
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