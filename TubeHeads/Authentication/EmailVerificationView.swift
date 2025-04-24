import SwiftUI
import FirebaseAuth

struct EmailVerificationView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showSignInView: Bool
    @State private var isCheckingVerification: Bool = false
    @State private var isResendingEmail: Bool = false
    @State private var verificationSent: Bool = false
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Back button
            Button {
                authManager.signOut()
                showSignInView = true
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.blue)
                .padding(.leading)
                .padding(.top, 10)
            }
            
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 30)
                
                Image(systemName: "envelope.badge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(Color(hex: "#f6bebe"))
                    .padding(.bottom, 20)
                
                Text("Email Verification Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We've sent a verification email to:")
                    .font(.body)
                
                Text(Auth.auth().currentUser?.email ?? "your email address")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.bottom, 10)
                
                Text("Please check your inbox and click the verification link to continue using TubeHeads.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.vertical, 5)
                        .onAppear {
                            // Auto-hide error message after 5 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                errorMessage = nil
                            }
                        }
                }
                
                if verificationSent {
                    Text("Verification email sent!")
                        .foregroundColor(.green)
                        .padding(.vertical, 5)
                }
                
                Spacer()
                    .frame(height: 15)
                    
                VStack(spacing: 18) {
                    Button {
                        Task {
                            isResendingEmail = true
                            do {
                                try await authManager.sendEmailVerification()
                                verificationSent = true
                                errorMessage = nil
                                // Auto-hide the success message after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    verificationSent = false
                                }
                            } catch {
                                errorMessage = "Error sending verification email: \(error.localizedDescription)"
                            }
                            isResendingEmail = false
                        }
                    } label: {
                        Group {
                            if isResendingEmail {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Text("Resend Verification Email")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#f6bebe").opacity(0.7))
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
                    }
                    .disabled(isResendingEmail)
                    
                    Divider()
                        .padding(.vertical, 5)
                    
                    Button {
                        Task {
                            isCheckingVerification = true
                            // Force reload from Firebase to get the latest verification status
                            if let user = Auth.auth().currentUser {
                                do {
                                    try await user.reload()
                                    let verified = user.isEmailVerified
                                    authManager.isEmailVerified = verified
                                    
                                    if verified {
                                        errorMessage = nil
                                        showSignInView = false
                                    } else {
                                        errorMessage = "Your email is still not verified. Please check your inbox and click the verification link."
                                    }
                                } catch {
                                    errorMessage = "Error checking verification status: \(error.localizedDescription)"
                                }
                            } else {
                                errorMessage = "User is no longer signed in"
                            }
                            isCheckingVerification = false
                        }
                    } label: {
                        Group {
                            if isCheckingVerification {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Text("Continue to App")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#f6bebe"))
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 2)
                    }
                    .disabled(isCheckingVerification)
                    
                    Text("Click after verifying your email to continue")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            // Check verification status immediately when the view appears
            Task {
                isCheckingVerification = true
                // Force reload from Firebase to get the latest verification status
                if let user = Auth.auth().currentUser {
                    do {
                        try await user.reload()
                        let verified = user.isEmailVerified
                        authManager.isEmailVerified = verified
                        
                        if verified {
                            showSignInView = false
                        }
                    } catch {
                        errorMessage = "Error checking verification status: \(error.localizedDescription)"
                    }
                }
                isCheckingVerification = false
            }
        }
    }
}

// SwiftUI Preview
struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EmailVerificationView(showSignInView: .constant(true))
                .environmentObject(AuthManager())
        }
    }
} 