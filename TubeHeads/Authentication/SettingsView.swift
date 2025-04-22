import SwiftUI

@MainActor
final class SettingsViewModelInfo: ObservableObject {
    
    @Published var username: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
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
    }
    
    func updateEmail() async throws {
        let email = "hello@gmail.com"
        
        try await AuthenticationManager.shared.updateEmail(email: email)
    }
    
    func updatePassword() async throws {
        let password = "1234567890"
        
        try await AuthenticationManager.shared.updatePassword(password: password)
    }
}

struct SettingsView: View {
    
    @StateObject private var viewModel = SettingsViewModelInfo()
    @Binding var showSignInView: Bool
    
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
                
                Button("Reset Password") {
                    Task {
                        do {
                            try await viewModel.resetPassword()
                            print("PASSWORD RESET!")
                            
                        } catch {
                            print(error)
                        }
                    }
                    
                }
                
                Button("Update Password") {
                    Task {
                        do {
                            try await viewModel.updatePassword()
                            print("Password Updated")
                            
                        } catch {
                            print(error)
                        }
                    }
                    
                }
                
                Button("Update Email") {
                    Task {
                        do {
                            try await viewModel.updateEmail()
                            print("Email Updated")
                            
                        } catch {
                            print(error)
                        }
                    }
                    
                }
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
