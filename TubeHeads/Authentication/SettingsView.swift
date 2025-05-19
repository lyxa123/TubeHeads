import SwiftUI

@MainActor
final class SettingsViewModelInfo: ObservableObject {
    
    @Published var username: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showResetPasswordAlert: Bool = false
    @Published var showPasswordUpdateAlert: Bool = false
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var showError: Bool = false
    
    func loadUserData() async {
        isLoading = true
        do {
            let authUser = try AuthenticationManager.shared.getAuthenticatedUser()
            let userData = try await UserManager.shared.getUser(userId: authUser.uid)
            self.username = userData.username
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signOut() throws {
        try AuthenticationManager.shared.SignOut()
    }
    
    func resetPassword() async throws {
        let authUser = try AuthenticationManager.shared.getAuthenticatedUser()
        guard let email = authUser.email else {
            throw URLError(.fileDoesNotExist)
        }
            
        try await AuthenticationManager.shared.resetPassword(email: email)
        showResetPasswordAlert = true
    }
    
    func updatePassword() async throws {
        // Validate passwords
        if newPassword.isEmpty || confirmPassword.isEmpty {
            errorMessage = "Please fill in all fields."
            showError = true
            throw NSError(domain: "All fields are required", code: 400)
        }
        
        if newPassword != confirmPassword {
            errorMessage = "Passwords don't match."
            showError = true
            throw NSError(domain: "Passwords don't match", code: 400)
        }
        
        if newPassword.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            showError = true
            throw NSError(domain: "Password must be at least 6 characters", code: 400)
        }
        
        try await AuthenticationManager.shared.updatePassword(password: newPassword)
        showPasswordUpdateAlert = true
        
        // Clear fields after successful update
        newPassword = ""
        confirmPassword = ""
        showError = false
    }
}

struct SettingsView: View {
    
    @StateObject private var viewModel = SettingsViewModelInfo()
    @Binding var showSignInView: Bool
    @State private var showUpdatePasswordSheet: Bool = false
    @State private var isUpdatingPassword: Bool = false
    
    var body: some View {
        List {
            Section {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("Username:")
                        Spacer()
                        Text(viewModel.username)
                            .fontWeight(.semibold)
                    }
                }
            } header: {
                Text("Profile")
            }
            
            Section {
                Button("Log out") {
                    Task {
                        do {
                            try viewModel.signOut()
                            showSignInView = true
                            
                        } catch {
                            print(error)
                        }
                    }
                }
                .foregroundColor(Color(hex:"517891"))
                
                Button("Reset Password") {
                    Task {
                        do {
                            try await viewModel.resetPassword()
                        } catch {
                            print(error)
                        }
                    }
                }
                .alert("Password Reset Email Sent", isPresented: $viewModel.showResetPasswordAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Check your email for instructions to reset your password.")
                }
                .foregroundColor(.primary)
                
                Button("Update Password") {
                    showUpdatePasswordSheet = true
                }
                .sheet(isPresented: $showUpdatePasswordSheet) {
                    NavigationStack {
                        VStack(spacing: 20) {
                            SecureField("New Password", text: $viewModel.newPassword)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                
                            SecureField("Confirm New Password", text: $viewModel.confirmPassword)
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
                                    isUpdatingPassword = true
                                    do {
                                        try await viewModel.updatePassword()
                                        isUpdatingPassword = false
                                        showUpdatePasswordSheet = false
                                    } catch {
                                        isUpdatingPassword = false
                                        print(error)
                                    }
                                }
                            } label: {
                                Group {
                                    if isUpdatingPassword {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    } else {
                                        Text("Update Password")
                                            .font(.headline)
                                            .foregroundColor(.black)
                                    }
                                }
                                .frame(height: 55)
                                .frame(maxWidth: .infinity)
                                .background(Color(hex: "#77b1d4"))
                                .cornerRadius(10)
                                .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
                            }
                            .disabled(isUpdatingPassword)
                            .padding(.top, 10)
                            
                            Spacer()
                        }
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Cancel") {
                                    viewModel.newPassword = ""
                                    viewModel.confirmPassword = ""
                                    viewModel.showError = false
                                    showUpdatePasswordSheet = false
                                }
                            }
                        }
                        .navigationTitle("Update Password")
                        .navigationBarTitleDisplayMode(.inline)
                    }

                }
                .alert("Password Updated", isPresented: $viewModel.showPasswordUpdateAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Your password has been successfully updated.")
                }
                .foregroundColor(.primary)
            }
        }
        .navigationBarTitle("Settings")
        .onAppear {
            Task {
                await viewModel.loadUserData()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView(showSignInView: .constant(false))
        }
    }
}
