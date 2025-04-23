import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var username: String = "tubeheadsfan1"
    @State private var bio: String = "i love television."
    @State private var location: String = "California, US"
    @State private var followersCount: Int = 90
    @State private var followingCount: Int = 103
    @State private var showSignInView: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    // Recent activity shows will be displayed in a horizontal scroll
    let recentShows: [ShowPreview] = [
        ShowPreview(imageName: "whiteLotus", title: "The White Lotus"),
        ShowPreview(imageName: "cassandra", title: "Cassandra"),
        ShowPreview(imageName: "severance", title: "Severance")
    ]
    
    var body: some View {
        Group {
            if authManager.isSignedIn {
                // User is signed in - show profile
                profileContent
            } else {
                // User is not signed in - show sign in prompt
                VStack(spacing: 20) {
                    Text("Sign in to view your profile")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Button {
                        showSignInView = true
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .fullScreenCover(isPresented: $showSignInView) {
                    NavigationView {
                        AuthenticationView(showSignInView: $showSignInView)
                    }
                }
            }
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    var profileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Back button and title
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    
                    Text("TubeHeads")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                
                // Username with lock icon
                HStack {
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Profile image, name and location
                VStack(alignment: .center, spacing: 8) {
                    ProfileImage(size: 120)
                        .padding(.bottom, 8)
                    
                    Text(bio)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                // Recent Activity section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            // More action
                        }) {
                            Text("More")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Show thumbnails
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentShows) { show in
                                ShowThumbnail(show: show)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 130)
                }
                .padding(.vertical)
                
                // Followers and Following
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("Followers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(followersCount)")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Following")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(followingCount)")
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
            }
            .padding(.top)
        }
        .navigationBarHidden(true)
    }
    
    private func loadUserProfile() {
        Task {
            if let username = await authManager.getCurrentUsername() {
                await MainActor.run {
                    self.username = username
                    
                    // You would typically load these from a user profile endpoint
                    // For now, this is just placeholder data
                    if username != "tubeheadsfan1" {
                        // If we have a real username, update the display
                        self.bio = "TV enthusiast"
                        self.location = "United States"
                    }
                }
            }
        }
    }
}

// Supporting Views
struct ProfileImage: View {
    let size: CGFloat
    
    var body: some View {
        // Fallback to a system image if profileImage doesn't exist
        if UIImage(named: "profileImage") != nil {
            Image("profileImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .shadow(radius: 1)
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .foregroundColor(.gray)
        }
    }
}

struct ShowPreview: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
}

struct ShowThumbnail: View {
    let show: ShowPreview
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 130)
                
                // Fallback to a placeholder if the image doesn't exist
                if UIImage(named: show.imageName) != nil {
                    Image(show.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "tv")
                            .font(.largeTitle)
                        Text(show.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: 100, height: 130)
                }
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
} 