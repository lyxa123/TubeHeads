import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showSignInView: Bool = false
    @State private var needsEmailVerification: Bool = false
    
    var body: some View {
        ZStack {
            if !showSignInView {
                if needsEmailVerification {
                    NavigationStack {
                        EmailVerificationView(showSignInView: $showSignInView)
                    }
                } else {
                    NavigationStack {
                        HomepageView(showSignInView: $showSignInView)
                    }
                }
            }
        }
        .onAppear {
            checkAuthState()
        }
        .onChange(of: authManager.isSignedIn) { _ in
            checkAuthState()
        }
        .onChange(of: authManager.isEmailVerified) { newValue in
            if newValue {
                // If email becomes verified, update our state
                needsEmailVerification = false
            }
        }
        .fullScreenCover(isPresented: $showSignInView) {
            NavigationStack {
                AuthenticationView(showSignInView: $showSignInView)
            }
            .onDisappear {
                // When the authentication view disappears, re-check auth state
                checkAuthState()
            }
        }
    }
    
    private func checkAuthState() {
        if authManager.isSignedIn {
            Task {
                // Get fresh verification status directly from Firebase
                let isVerified = await authManager.checkEmailVerification()
                print("RootView: Auth state check - Email verified: \(isVerified)")
                
                // Update UI on main thread
                await MainActor.run {
                    needsEmailVerification = !isVerified
                    showSignInView = false
                }
            }
        } else {
            showSignInView = true
            needsEmailVerification = false
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager())
}
