import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showSignInView: Bool = false
    
    var body: some View {
        ZStack {
            if !showSignInView {
                NavigationStack {
                    HomepageView(showSignInView: $showSignInView)
                }
            }
        }
        .onAppear {
            showSignInView = !authManager.isSignedIn
        }
        .fullScreenCover(isPresented: $showSignInView) {
            NavigationStack {
                AuthenticationView(showSignInView: $showSignInView)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager())
}
