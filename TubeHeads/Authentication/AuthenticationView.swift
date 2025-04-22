import SwiftUI

struct AuthenticationView: View {
    
    @Binding var showSignInView: Bool
    
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
                        .foregroundColor(.white)
                    
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
            
            // Sign up button
            NavigationLink {
                SignUpView(showSignInView: $showSignInView)
            } label: {
                HStack {
                    Image(systemName: "person.fill.badge.plus")
                        .foregroundColor(.white)
                    
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AuthenticationView_Preview: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AuthenticationView(showSignInView: .constant(false))
        }
    }
}
