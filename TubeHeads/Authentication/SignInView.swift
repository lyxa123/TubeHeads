import SwiftUI
import FirebaseAuth

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var showError = false
    
    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            showError = true
            return
        }
        
        do {
            try await AuthenticationManager.shared.signInUser(email: email, password: password)
            return
        } catch {
            handleAuthError(error)
        }
    }
    
    private func handleAuthError(_ error: Error) {
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
    @Binding var showSignInView: Bool
    @State private var isLoading = false
    
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
            
            Button {
                Task {
                    isLoading = true
                    await viewModel.signIn()
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
                        .background(Color.blue)
                        .cornerRadius(10)
                } else {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
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