import SwiftUI

struct RootView: View {
    
    @State private var showSignInView: Bool = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                if showSignInView {
                    AuthenticationView(showSignInView: $showSignInView)
                } else {
                    HomepageView(showSignInView: $showSignInView) // Navigate to HomepageView
                }
            }
        }
        
        .id(showSignInView)
        
        .onAppear {
            let authuser = try? AuthenticationManager.shared.getAuthenticatedUser()
            self.showSignInView = authuser == nil
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
}
