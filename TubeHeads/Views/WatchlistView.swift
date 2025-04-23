import SwiftUI
import FirebaseFirestore

// Add explicit import for TVShow type

struct WatchlistView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var watchlistItems: [WatchlistItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignInView = false
    
    var body: some View {
        NavigationView {
            VStack {
                if !authManager.isSignedIn {
                    VStack(spacing: 20) {
                        Text("Sign in to view your watchlist")
                            .font(.headline)
                        
                        Button(action: {
                            showSignInView = true
                        }) {
                            Text("Sign In")
                                .frame(minWidth: 200)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                } else if isLoading {
                    ProgressView("Loading watchlist...")
                        .scaleEffect(1.2)
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Text("Error loading watchlist")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            Task {
                                await loadWatchlist()
                            }
                        }) {
                            Text("Try Again")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                } else if watchlistItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("Your watchlist is empty")
                            .font(.headline)
                        
                        Text("Add shows to your watchlist to keep track of what you want to watch")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        NavigationLink(destination: TrendingTVView()) {
                            Text("Discover Shows")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(watchlistItems) { item in
                            NavigationLink {
                                // Use the show directly instead of conditional unwrapping
                                FirestoreShowDetailView(firestoreShow: item.show)
                            } label: {
                                WatchlistItemRow(item: item)
                            }
                        }
                        .onDelete(perform: removeFromWatchlist)
                    }
                }
            }
            .navigationTitle("My Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !watchlistItems.isEmpty && authManager.isSignedIn {
                        EditButton()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadWatchlist()
                }
            }
            .fullScreenCover(isPresented: $showSignInView) {
                NavigationStack {
                    AuthenticationView(showSignInView: $showSignInView)
                }
            }
        }
    }
    
    private func loadWatchlist() async {
        isLoading = true
        errorMessage = nil
        
        if !authManager.isSignedIn {
            isLoading = false
            return
        }
        
        guard let userId = authManager.currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            watchlistItems = try await WatchlistService.shared.getWatchlist(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading watchlist: \(error)")
        }
        
        isLoading = false
    }
    
    private func removeFromWatchlist(at offsets: IndexSet) {
        guard let userId = authManager.currentUser?.uid else {
            return
        }
        
        // Take a snapshot of the affected items before removing them
        let itemsToRemove = offsets.map { watchlistItems[$0] }
        
        // First update UI
        watchlistItems.remove(atOffsets: offsets)
        
        // Then remove from backend
        for item in itemsToRemove {
            guard let showId = item.show.id else {
                continue
            }
            
            Task {
                do {
                    try await WatchlistService.shared.removeFromWatchlist(userId: userId, showId: showId)
                } catch {
                    print("Error removing show from watchlist: \(error)")
                    // Consider re-adding the item to UI if backend removal fails
                    // This would require more complex state management
                }
            }
        }
    }
}

struct WatchlistItemRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Show poster
            if let posterURL = item.show.posterURL {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 90)
                            .cornerRadius(6)
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
                            .cornerRadius(6)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
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
            
            VStack(alignment: .leading, spacing: 4) {
                // Show title
                Text(item.show.name)
                    .font(.headline)
                
                // Release year
                Text(item.show.releaseYear)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Date added
                Text("Added \(dateFormatter.string(from: item.dateAdded))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Rating if available
            if item.show.averageUserRating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(String(format: "%.1f", item.show.averageUserRating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

#Preview {
    WatchlistView()
        .environmentObject(AuthManager())
} 