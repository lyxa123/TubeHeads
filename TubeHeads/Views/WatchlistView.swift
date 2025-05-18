import SwiftUI
import FirebaseFirestore

// Add explicit import for TVShow type

struct WatchlistView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var watchlistItems: [WatchlistItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignInView = false
    @State private var isOfflineMode = false
    
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
                } else if let error = errorMessage, watchlistItems.isEmpty {
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
                    VStack {
                        if isOfflineMode {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("Offline Mode")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                                Button(action: {
                                    Task {
                                        await loadWatchlist(forceRefresh: true)
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                        }
                        
                        List {
                            ForEach(watchlistItems) { item in
                                NavigationLink {
                                    FirestoreShowDetailView(firestoreShow: item.show)
                                } label: {
                                    WatchlistItemRow(item: item)
                                }
                            }
                            .onDelete(perform: removeFromWatchlist)
                        }
                    }
                }
            }
            .navigationTitle("My Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !watchlistItems.isEmpty && authManager.isSignedIn {
                        HStack {
                            Button(action: {
                                Task {
                                    await loadWatchlist(forceRefresh: true)
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            EditButton()
                        }
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
    
    private func loadWatchlist(forceRefresh: Bool = false) async {
        // Set loading state
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        if !authManager.isSignedIn {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        guard let userId = authManager.currentUser?.uid else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            if forceRefresh {
                // Only clear cache if we can refresh from server
                await MainActor.run {
                    print("WatchlistView: Force refreshing watchlist data")
                }
            }
            
            let items = try await WatchlistService.shared.getWatchlist(userId: userId)
            
            // Update UI on the main thread
            await MainActor.run {
                print("WatchlistView: Got \(items.count) watchlist items")
                
                if items.isEmpty && !forceRefresh {
                    // If returning empty while not force refreshing, this could be due to
                    // corrupt cache or no previous data, so keep any existing items
                    if !watchlistItems.isEmpty {
                        print("WatchlistView: Keeping existing \(watchlistItems.count) items instead of empty result")
                        // Keep existing items
                        isOfflineMode = true
                    } else {
                        // Otherwise use the empty result
                        watchlistItems = items
                        isOfflineMode = !items.isEmpty
                    }
                } else {
                    // Normal case: use the items we got
                    watchlistItems = items
                    isOfflineMode = false
                    
                    // If we got items, enforce caching to make sure they're available offline
                    if !items.isEmpty {
                        WatchlistService.shared.forceCacheWatchlist(userId: userId, items: items)
                    }
                }
                
                isLoading = false // Make sure to set loading to false
            }
        } catch {
            print("WatchlistView: Error loading watchlist: \(error.localizedDescription)")
            
            // Try to get cached data directly
            let cachedItems = await getCachedWatchlistItems(userId: userId)
            
            // Update UI on the main thread
            await MainActor.run {
                if !cachedItems.isEmpty {
                    print("WatchlistView: Using \(cachedItems.count) cached items after error")
                    watchlistItems = cachedItems
                    isOfflineMode = true
                    errorMessage = nil
                } else if !watchlistItems.isEmpty {
                    // Keep any existing items instead of showing empty
                    print("WatchlistView: Keeping existing items after error")
                    isOfflineMode = true
                    errorMessage = nil
                } else {
                    // If no cached or existing items, show error
                    errorMessage = "Unable to load your watchlist. Please check your internet connection and try again."
                }
                
                isLoading = false
            }
        }
    }
    
    // Helper method to directly access cached watchlist items
    private func getCachedWatchlistItems(userId: String) async -> [WatchlistItem] {
        if let cachedItems = await WatchlistService.shared.loadCachedWatchlist(userId: userId) {
            return cachedItems
        }
        return []
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
                    // If removal fails, show offline message
                    await MainActor.run {
                        isOfflineMode = true
                    }
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

