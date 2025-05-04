import SwiftUI
import FirebaseFirestore

struct UserProfileView: View {
    let userId: String
    
    @State private var username: String = "User"
    @State private var bio: String = "No bio yet"
    @State private var location: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var isImageLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isPublic: Bool = true
    @State private var watchedShows: [WatchedShow] = []
    @State private var userLists: [(id: String, name: String, description: String, isPrivate: Bool, userId: String, showIds: [String])] = []
    @State private var isLoadingLists: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header with back button and title
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Text(isLoading ? "User's Profile" : "\(username)'s Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Username with lock icon if profile is private
                HStack {
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !isPublic {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    // Only show follow button if viewing someone else's profile
                    if let currentUserId = authManager.currentUser?.uid, currentUserId != userId {
                        FollowButton(userId: userId)
                    }
                }
                .padding(.horizontal)
                
                // Profile section
                if !isPublic {
                    // Private profile message
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("This profile is private")
                            .font(.headline)
                        
                        Text("The user has set their profile to private mode.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    // Public profile content
                    VStack(alignment: .center, spacing: 8) {
                        if isLoading || isImageLoading {
                            ProgressView()
                                .frame(width: 100, height: 100)
                        } else if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .shadow(radius: 1)
                        } else {
                            UserProfileImageView(size: 100)
                        }
                        
                        Text(bio)
                            .font(.headline)
                        
                        if !location.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Watched shows section
                    if !watchedShows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Watched Shows")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if watchedShows.count > 3 {
                                    NavigationLink(destination: WatchedShowsView(shows: watchedShows)) {
                                        Text("See All")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            ForEach(watchedShows.sorted(by: { $0.dateWatched > $1.dateWatched }).prefix(3)) { show in
                                WatchedShowRow(show: show)
                                    .padding(.horizontal)
                                
                                if show.id != watchedShows.sorted(by: { $0.dateWatched > $1.dateWatched }).prefix(3).last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // Show Lists section
                    if isLoadingLists {
                        VStack {
                            ProgressView()
                            Text("Loading lists...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if !userLists.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Show Lists")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if userLists.count > 3 {
                                    NavigationLink(destination: UserListsView(userId: userId)) {
                                        Text("See All")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            ForEach(userLists.prefix(3), id: \.id) { list in
                                if !list.isPrivate {
                                    NavigationLink(destination: UserListView(listId: list.id, listName: list.name)) {
                                        ShowListRow(list: list)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    private func loadUserProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get user profile data
                let profile = try await ProfileManager.shared.getProfile(userId: userId)
                
                // Load profile image in parallel with updating the UI
                if profile.hasProfileImage {
                    isImageLoading = true
                    
                    // Use a separate task for image loading to not block UI updates
                    Task {
                        do {
                            let image = try await ProfileManager.shared.getProfileImage(userId: userId)
                            
                            await MainActor.run {
                                self.profileImage = image
                                self.isImageLoading = false
                            }
                        } catch {
                            print("Failed to load profile image: \(error.localizedDescription)")
                            await MainActor.run {
                                self.isImageLoading = false
                            }
                        }
                    }
                }
                
                // Update UI with profile data
                await MainActor.run {
                    self.username = profile.username
                    self.bio = profile.bio
                    self.location = profile.location
                    self.isPublic = profile.isPublic
                    self.watchedShows = profile.isPublic ? profile.watchedShows : []
                    self.isLoading = false
                }
                
                // Load user lists if profile is public
                if profile.isPublic {
                    loadUserLists()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    self.isLoading = false
                    self.isImageLoading = false
                }
            }
        }
    }
    
    private func loadUserLists() {
        isLoadingLists = true
        
        Task {
            do {
                let lists = try await ListService.shared.getUserLists(userId: userId)
                
                // Filter out private lists if needed
                let publicLists = lists.filter { !$0.isPrivate }
                
                await MainActor.run {
                    self.userLists = publicLists.map { list in
                        return (id: list.id ?? "", 
                                name: list.name, 
                                description: list.description, 
                                isPrivate: list.isPrivate, 
                                userId: list.userId, 
                                showIds: list.showIds)
                    }
                    self.isLoadingLists = false
                }
            } catch {
                print("Failed to load user lists: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingLists = false
                }
            }
        }
    }
}

struct ShowListRow: View {
    let list: (id: String, name: String, description: String, isPrivate: Bool, userId: String, showIds: [String])
    
    var body: some View {
        HStack(spacing: 12) {
            // List icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // List name
                Text(list.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                // List description
                if !list.description.isEmpty {
                    Text(list.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Show count
                Text("\(list.showIds.count) shows")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct UserListView: View {
    let listId: String
    let listName: String
    @State private var shows: [FirestoreShow] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else if shows.isEmpty {
                Text("This list is empty")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(shows, id: \.tmdbId) { show in
                            NavigationLink(destination: FirestoreShowDetailView(firestoreShow: show)) {
                                HStack(spacing: 12) {
                                    // Show thumbnail
                                    if let posterPath = show.posterPath, !posterPath.isEmpty {
                                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")) { phase in
                                            switch phase {
                                            case .empty:
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 60, height: 90)
                                                    .overlay(ProgressView())
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 90)
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 60, height: 90)
                                                    .overlay(Image(systemName: "tv"))
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 60, height: 90)
                                            .overlay(Image(systemName: "tv"))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(show.name)
                                            .font(.headline)
                                            .lineLimit(2)
                                        
                                        if !show.releaseYear.isEmpty {
                                            Text(show.releaseYear)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(listName)
        .task {
            await loadListShows()
        }
    }
    
    private func loadListShows() async {
        isLoading = true
        
        do {
            // First get the list
            let list = try await ListService.shared.getList(id: listId)
            
            var listShows: [FirestoreShow] = []
            
            // Load each show in the list
            for showId in list.showIds {
                do {
                    let show = try await FirestoreShowService.shared.getShow(id: showId)
                    listShows.append(show)
                } catch {
                    print("Error loading show \(showId): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.shows = listShows
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// FollowButton component for user profiles
struct FollowButton: View {
    let userId: String
    @State private var isFollowing = false
    @State private var isLoading = false
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        Button(action: {
            toggleFollow()
        }) {
            HStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                        .font(.caption)
                }
                
                Text(isFollowing ? "Following" : "Follow")
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue.opacity(0.8))
            .foregroundColor(isFollowing ? .primary : .white)
            .cornerRadius(15)
        }
        .disabled(isLoading)
        .onAppear {
            checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        isLoading = true
        
        // Here you would check if the current user is following this user
        // For demonstration, we'll simulate an API call
        Task {
            do {
                // Simulated check - in a real app, you'd query Firestore
                // to check if currentUserId follows userId
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec delay
                
                // This would be a Firestore query in a real implementation
                let followsDoc = try? await Firestore.firestore()
                    .collection("follows")
                    .document(currentUserId)
                    .getDocument()
                
                let isFollowing = followsDoc?.data()?["following"] as? [String] ?? []
                
                await MainActor.run {
                    self.isFollowing = isFollowing.contains(userId)
                    self.isLoading = false
                }
            } catch {
                print("Error checking follow status: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        isLoading = true
        
        Task {
            do {
                // In a real app, this would update Firestore to add/remove the follow relationship
                if isFollowing {
                    // Unfollow logic would go here
                    try await Task.sleep(nanoseconds: 800_000_000) // Simulate network delay
                } else {
                    // Follow logic would go here
                    try await Task.sleep(nanoseconds: 800_000_000) // Simulate network delay
                }
                
                await MainActor.run {
                    self.isFollowing.toggle()
                    self.isLoading = false
                }
            } catch {
                print("Error toggling follow status: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView(userId: "previewUserId")
    }
} 