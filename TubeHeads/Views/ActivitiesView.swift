import SwiftUI
import FirebaseFirestore
import Foundation

struct ActivityItem: Identifiable {
    let id: String
    let userId: String
    let username: String
    let profileImageURL: String?
    let timestamp: Date
    let showId: String
    let showName: String
    let showPosterPath: String?
    let activityType: ActivityType
    let rating: Double?
    let reviewContent: String?
    
    enum ActivityType {
        case rating
        case review
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct ActivitiesView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLoading = false
    @State private var activities: [ActivityItem] = []
    @State private var errorMessage: String? = nil
    @State private var following: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Suggested users section
                SuggestedUsersView()
                    .padding(.top, 8)
                
                // Activity feed section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activity Feed")
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
                    } else if activities.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("No activity yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Follow more users to see their ratings and reviews in your feed")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(activities) { activity in
                                ActivityCard(activity: activity)
                                
                                if activity.id != activities.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.top)
            .navigationTitle("Activities")
        }
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            loadActivities()
        }
    }
    
    private func loadActivities() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get list of users the current user is following
                let followingUsers = try await FollowService.shared.getFollowing(userId: currentUserId)
                following = followingUsers.map { $0.id }
                
                // If not following anyone, show appropriate message
                if following.isEmpty {
                    await MainActor.run {
                        activities = []
                        isLoading = false
                    }
                    return
                }
                
                // Get recent reviews from followed users
                var activityItems: [ActivityItem] = []
                
                for userId in following {
                    // Get user's reviews
                    let reviews = try await FirestoreReviewService.shared.getReviewsByUser(userId: userId)
                    
                    for review in reviews.prefix(5) { // Limit to recent 5 reviews per user
                        // Get show details
                        let show = try await FirestoreShowService.shared.getShow(id: review.showId)
                        
                        // Create activity item
                        let activityItem = ActivityItem(
                            id: review.id ?? UUID().uuidString,
                            userId: review.userId,
                            username: review.username ?? "User",
                            profileImageURL: review.userProfileImageURL,
                            timestamp: review.timestamp,
                            showId: review.showId,
                            showName: show.name,
                            showPosterPath: show.posterPath,
                            activityType: review.content.isEmpty ? .rating : .review,
                            rating: review.rating,
                            reviewContent: review.content.isEmpty ? nil : review.content
                        )
                        
                        activityItems.append(activityItem)
                    }
                }
                
                // Sort activities by timestamp (newest first)
                activityItems.sort { $0.timestamp > $1.timestamp }
                
                // Update UI
                await MainActor.run {
                    activities = activityItems
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load activities: \(error.localizedDescription)"
                    isLoading = false
                }
                print("Error loading activities: \(error)")
            }
        }
    }
}

struct ActivityCard: View {
    let activity: ActivityItem
    @State private var navigateToShowDetail = false
    @State private var navigateToUserProfile = false
    @State private var firestoreShow: FirestoreShow?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info and timestamp
            HStack {
                // Profile image with navigation to user profile
                Button(action: {
                    navigateToUserProfile = true
                }) {
                    ReviewProfileImage(
                        userId: activity.userId,
                        base64ImageString: activity.profileImageURL,
                        size: 40
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    // Username
                    Button(action: {
                        navigateToUserProfile = true
                    }) {
                        Text(activity.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Activity description
                    HStack(spacing: 4) {
                        Text(activity.activityType == .review ? "reviewed" : "rated")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(activity.timeAgo)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Rating
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color(hex: "#57b9ff"))
                        .font(.caption)
                    
                    Text(String(format: "%.1f", activity.rating ?? 0))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Show info with poster
            Button(action: {
                prepareForNavigation()
            }) {
                HStack(spacing: 12) {
                    // Show poster
                    if let posterPath = activity.showPosterPath, let posterURL = URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)") {
                        AsyncImage(url: posterURL) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 90)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 90)
                                    .cornerRadius(6)
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 90)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                                    .cornerRadius(6)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 90)
                            .cornerRadius(6)
                    }
                    
                    // Show name
                    Text(activity.showName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Review content (if it's a review)
            if let reviewContent = activity.reviewContent {
                Text(reviewContent)
                    .font(.body)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .background(
            NavigationLink(
                destination: UserProfileView(userId: activity.userId),
                isActive: $navigateToUserProfile,
                label: { EmptyView() }
            )
            .opacity(0)
        )
        .background(
            Group {
                if let show = firestoreShow {
                    NavigationLink(
                        destination: FirestoreShowDetailView(firestoreShow: show),
                        isActive: $navigateToShowDetail,
                        label: { EmptyView() }
                    )
                    .opacity(0)
                }
            }
        )
    }
    
    private func prepareForNavigation() {
        Task {
            do {
                let show = try await FirestoreShowService.shared.getShow(id: activity.showId)
                await MainActor.run {
                    firestoreShow = show
                    navigateToShowDetail = true
                }
            } catch {
                print("Error loading show details: \(error)")
            }
        }
    }
}

struct ActivitiesView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitiesView()
            .environmentObject(AuthManager())
    }
} 
