import SwiftUI
import FirebaseFirestore
import Foundation

struct ActivitiesView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activities")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Suggested users section
                SuggestedUsersView()
                    .padding(.top, 8)
                
                // Placeholder for future activity feed
                VStack(alignment: .center, spacing: 20) {
                    Spacer(minLength: 60)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("Activity Feed Coming Soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("You'll soon be able to see what your friends are watching, reviewing, and adding to their lists.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            .padding(.top)
        }
        .navigationBarTitle("", displayMode: .inline)
    }
}

struct ActivitiesView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitiesView()
            .environmentObject(AuthManager())
    }
} 