import SwiftUI
import FirebaseFirestore

struct ShowDetailView: View {
    let tmdbId: Int
    let initialTVShow: TVShow
    
    @State private var firestoreShow: FirestoreShow?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var userRating: Double = 0
    @State private var isInWatchlist = false
    @State private var isAddingToWatchlist = false
    
    // Assume we have a user manager that can get current user ID
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header image (backdrop)
                if let backdropURL = initialTVShow.backdropURL {
                    AsyncImage(url: backdropURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(initialTVShow.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Release year
                    Text(initialTVShow.releaseYear)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Watchlist button
                    if authManager.isSignedIn {
                        Button(action: {
                            toggleWatchlist()
                        }) {
                            HStack {
                                Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                                Text(isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isInWatchlist ? Color.green.opacity(0.8) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .overlay(
                                Group {
                                    if isAddingToWatchlist {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                }
                            )
                        }
                        .disabled(isAddingToWatchlist)
                    } else {
                        Button(action: {
                            // Navigate to sign in
                        }) {
                            HStack {
                                Image(systemName: "bookmark")
                                Text("Sign in to add to Watchlist")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    // User rating section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User Rating")
                            .font(.headline)
                        
                        if let show = firestoreShow {
                            HStack {
                                if show.userRatings.isEmpty {
                                    Text("No ratings yet")
                                        .foregroundColor(.gray)
                                } else {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", show.averageUserRating))
                                        .fontWeight(.bold)
                                    Text("(\(show.userRatings.count) ratings)")
                                        .foregroundColor(.gray)
                                }
                            }
                        } else {
                            Text("Loading ratings...")
                                .foregroundColor(.gray)
                        }
                        
                        if authManager.isSignedIn {
                            Text("Your Rating:")
                                .font(.subheadline)
                                .padding(.top, 4)
                            
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(userRating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .onTapGesture {
                                            userRating = Double(star)
                                            submitRating()
                                        }
                                }
                            }
                        } else {
                            Button(action: {
                                // Navigate to sign in
                            }) {
                                Text("Sign in to rate")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Overview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overview")
                            .font(.headline)
                        
                        Text(initialTVShow.overview)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    // Divider before reviews section
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Reviews section
                    if let show = firestoreShow, let showId = show.id {
                        ReviewsView(showId: showId, showName: initialTVShow.name)
                            .environmentObject(authManager)
                    } else {
                        // Show a placeholder until the firestore show is loaded
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reviews")
                                .font(.headline)
                            
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding()
                            } else {
                                Text("Loading reviews...")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadShowDetails()
        }
    }
    
    private func loadShowDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, check if the show exists in Firestore
            if let show = try await FirestoreShowService.shared.getShowByTMDBId(tmdbId: tmdbId) {
                firestoreShow = show
                
                // Get user's rating if available
                if let userId = authManager.currentUser?.uid {
                    if let userRatingValue = show.userRatings[userId] {
                        userRating = userRatingValue
                    }
                    
                    // Check if show is in user's watchlist
                    if let showId = show.id {
                        isInWatchlist = try await WatchlistService.shared.isInWatchlist(userId: userId, showId: showId)
                    }
                }
            } else {
                // If not, save it to Firestore
                let showId = try await FirestoreShowService.shared.saveShow(from: initialTVShow)
                firestoreShow = try await FirestoreShowService.shared.getShow(id: showId)
                
                // Check if show is in user's watchlist after saving
                if let userId = authManager.currentUser?.uid {
                    isInWatchlist = try await WatchlistService.shared.isInWatchlist(userId: userId, showId: showId)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading show details: \(error)")
        }
        
        isLoading = false
    }
    
    private func submitRating() {
        guard let showId = firestoreShow?.id,
              let userId = authManager.currentUser?.uid else {
            return
        }
        
        Task {
            do {
                try await FirestoreShowService.shared.rateShow(
                    showId: showId,
                    userId: userId,
                    rating: userRating
                )
                
                // Reload show to get updated ratings
                firestoreShow = try await FirestoreShowService.shared.getShow(id: showId)
            } catch {
                print("Error submitting rating: \(error)")
            }
        }
    }
    
    private func toggleWatchlist() {
        guard let showId = firestoreShow?.id,
              let userId = authManager.currentUser?.uid else {
            return
        }
        
        isAddingToWatchlist = true
        
        Task {
            do {
                if isInWatchlist {
                    try await WatchlistService.shared.removeFromWatchlist(userId: userId, showId: showId)
                    isInWatchlist = false
                } else {
                    try await WatchlistService.shared.addToWatchlist(userId: userId, showId: showId)
                    isInWatchlist = true
                }
            } catch {
                print("Error toggling watchlist: \(error)")
            }
            
            isAddingToWatchlist = false
        }
    }
}

#Preview {
    NavigationView {
        ShowDetailView(
            tmdbId: 1,
            initialTVShow: TVShow(
                id: 1,
                name: "Sample Show",
                overview: "This is a sample show overview with some text to demonstrate how the overview section will look with multiple lines of text.",
                posterPath: nil,
                backdropPath: nil,
                voteAverage: 8.5,
                firstAirDate: "2023-01-01"
            )
        )
    }
} 