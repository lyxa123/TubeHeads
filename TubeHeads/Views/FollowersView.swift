import SwiftUI
import FirebaseFirestore

struct FollowersView: View {
    let userId: String
    @State private var followers: [UserWithFollowStats] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if followers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No followers yet")
                        .font(.headline)
                    
                    Text("When people follow you, they'll show up here.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                // List of followers
                List {
                    ForEach(followers, id: \.id) { follower in
                        NavigationLink(destination: UserProfileView(userId: follower.id)) {
                            UserFollowRow(user: follower)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Followers")
        .onAppear {
            loadFollowers()
        }
    }
    
    private func loadFollowers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                followers = try await FollowService.shared.getFollowers(userId: userId)
                
                // Check if current user is following each of these users
                if let currentUserId = authManager.currentUser?.uid {
                    for i in 0..<followers.count {
                        let isFollowing = try await FollowService.shared.checkIfFollowing(
                            followerId: currentUserId,
                            followedId: followers[i].id
                        )
                        followers[i].isFollowedByCurrentUser = isFollowing
                    }
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load followers: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct FollowingView: View {
    let userId: String
    @State private var following: [UserWithFollowStats] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if following.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("Not following anyone yet")
                        .font(.headline)
                    
                    Text("When you follow people, they'll show up here.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                // List of people being followed
                List {
                    ForEach(following, id: \.id) { user in
                        NavigationLink(destination: UserProfileView(userId: user.id)) {
                            UserFollowRow(user: user)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Following")
        .onAppear {
            loadFollowing()
        }
    }
    
    private func loadFollowing() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                following = try await FollowService.shared.getFollowing(userId: userId)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load following: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct UserFollowRow: View {
    @State var user: UserWithFollowStats
    @State private var isFollowing: Bool
    @State private var isProcessing = false
    @EnvironmentObject private var authManager: AuthManager
    
    // Computed property to check if this is the current user
    private var isCurrentUser: Bool {
        authManager.currentUser?.uid == user.id
    }
    
    init(user: UserWithFollowStats) {
        self._user = State(initialValue: user)
        self._isFollowing = State(initialValue: user.isFollowedByCurrentUser)
    }
    
    var body: some View {
        HStack {
            // Profile image (could be a custom component from your existing app)
            if let imageUrl = user.profileImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            
            // User info
            VStack(alignment: .leading) {
                Text(user.username)
                    .font(.headline)
                
                Text("\(user.followerCount) followers")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Follow/Unfollow button (hidden if it's the current user)
            if !isCurrentUser {
                Button(action: {
                    followToggle()
                }) {
                    Text(isFollowing ? "Unfollow" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                        .foregroundColor(isFollowing ? .primary : .white)
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.5 : 1.0)
                .overlay(
                    isProcessing ? ProgressView().tint(isFollowing ? .primary : .white) : nil
                )
            }
        }
        .padding(.vertical, 4)
    }
    
    private func followToggle() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        isProcessing = true
        
        Task {
            do {
                if isFollowing {
                    // Unfollow
                    try await FollowService.shared.unfollowUser(
                        currentUserId: currentUserId,
                        targetUserId: user.id
                    )
                } else {
                    // Follow
                    try await FollowService.shared.followUser(
                        currentUserId: currentUserId,
                        targetUserId: user.id
                    )
                }
                
                await MainActor.run {
                    isFollowing.toggle()
                    user.isFollowedByCurrentUser = isFollowing
                    
                    // Update counts optimistically
                    if isFollowing {
                        user.followerCount += 1
                    } else if user.followerCount > 0 {
                        user.followerCount -= 1
                    }
                    
                    isProcessing = false
                }
            } catch {
                print("Error toggling follow: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

struct SuggestedUsersView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var suggestedUsers: [UserWithFollowStats] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Suggested for You")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if suggestedUsers.isEmpty {
                Text("No suggestions available right now")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(suggestedUsers, id: \.id) { user in
                            SuggestedUserCard(user: user)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 180)
            }
        }
        .onAppear {
            loadSuggestions()
        }
    }
    
    private func loadSuggestions() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        isLoading = true
        
        Task {
            do {
                suggestedUsers = try await FollowService.shared.getSuggestedUsers(
                    forUserId: currentUserId,
                    limit: 5
                )
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load suggestions"
                }
            }
        }
    }
}

struct SuggestedUserCard: View {
    @State var user: UserWithFollowStats
    @State private var isFollowing = false
    @State private var isProcessing = false
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        VStack {
            // Profile image
            if let imageUrl = user.profileImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 70, height: 70)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // Username
            Text(user.username)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Follower count
            Text("\(user.followerCount) followers")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Follow button
            Button(action: {
                followUser()
            }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                    .foregroundColor(isFollowing ? .primary : .white)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.5 : 1.0)
        }
        .frame(width: 100)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
    
    private func followUser() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        isProcessing = true
        
        Task {
            do {
                try await FollowService.shared.followUser(
                    currentUserId: currentUserId,
                    targetUserId: user.id
                )
                
                await MainActor.run {
                    isFollowing = true
                    user.followerCount += 1
                    isProcessing = false
                }
            } catch {
                print("Error following user: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

// Preview
struct FollowViews_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FollowersView(userId: "sampleUserId")
                .environmentObject(AuthManager())
        }
        
        NavigationView {
            FollowingView(userId: "sampleUserId")
                .environmentObject(AuthManager())
        }
        
        SuggestedUsersView()
            .environmentObject(AuthManager())
            .previewLayout(.sizeThatFits)
    }
} 