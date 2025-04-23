import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showSignInView: Bool
    @State private var showFirebaseRulesSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = "Missing or insufficient permissions. Check Firebase Rules."
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo and title section
            VStack(spacing: 10) {
                Text("TubeHeads")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("Welcome to TubeHeads")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 50)
            
            Spacer()
            
            // Sign in button
            NavigationLink {
                SignInView(showSignInView: $showSignInView)
            } label: {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.black)
                    
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#f6bebe"))
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
            }
            
            // Sign up button
            NavigationLink {
                SignUpView(showSignInView: $showSignInView)
            } label: {
                HStack {
                    Image(systemName: "person.fill.badge.plus")
                        .foregroundColor(.black)
                    
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#f6bebe"))
                .cornerRadius(10)
                .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
            }
            
            Spacer()
            
            // Firebase Rules button
            Button {
                showFirebaseRulesSheet = true
            } label: {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.blue)
                    
                    Text("Firebase Rules Help")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showFirebaseRulesSheet) {
                FirebaseRulesView()
            }
        }
        .padding()
        .onAppear {
            // Check auth state when view appears
            authManager.debugAuthState()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Permission Error"),
                message: Text(errorMessage),
                primaryButton: .default(Text("Show Rules")) {
                    showFirebaseRulesSheet = true
                },
                secondaryButton: .cancel(Text("Dismiss"))
            )
        }
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AuthenticationView_Preview: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AuthenticationView(showSignInView: .constant(false))
                .environmentObject(AuthManager())
        }
    }
}
