import Foundation
import FirebaseFirestore
import Network

class WatchlistService {
    static let shared = WatchlistService()
    
    private let userCollection = Firestore.firestore().collection("users")
    private let cachedWatchlistKey = "CachedWatchlistItems"
    private let monitor = NWPathMonitor()
    private var isCurrentlyOffline = false
    
    // Add in-memory cache for faster access and to prevent data loss when offline
    private var inMemoryCache: [String: [WatchlistItem]] = [:]
    
    private init() {
        // Start monitoring network status
        monitor.pathUpdateHandler = { [weak self] path in
            let wasOffline = self?.isCurrentlyOffline ?? false
            self?.isCurrentlyOffline = path.status != .satisfied
            
            print("WatchlistService: Network connection status changed. Offline: \(path.status != .satisfied)")
            
            // If we just came back online, try to sync any cached data
            if wasOffline && path.status == .satisfied {
                print("WatchlistService: Back online, syncing cached data")
                // This would be a good place to sync any changes made while offline
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    // Add a show to user's watchlist
    func addToWatchlist(userId: String, showId: String) async throws {
        // If we're offline, we should store locally and sync later
        if isOffline() {
            print("WatchlistService: Device is offline, caching add operation")
            // Here we would implement a queue of pending operations
            // For now, just show an error
            throw NSError(domain: "WatchlistServiceError", 
                         code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Cannot add to watchlist while offline"])
        }
        
        try await userCollection.document(userId)
            .collection("watchlist")
            .document(showId)
            .setData([
                "dateAdded": Timestamp(date: Date()),
                "showId": showId
            ])
        
        // Update local cache after online operation succeeds
        await refreshAndCacheWatchlist(userId: userId)
    }
    
    // Remove a show from user's watchlist
    func removeFromWatchlist(userId: String, showId: String) async throws {
        // If we're offline, we should store locally and sync later
        if isOffline() {
            print("WatchlistService: Device is offline, caching remove operation")
            // Here we would implement a queue of pending operations
            // For now, just show an error
            throw NSError(domain: "WatchlistServiceError", 
                         code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "Cannot remove from watchlist while offline"])
        }
        
        try await userCollection.document(userId)
            .collection("watchlist")
            .document(showId)
            .delete()
        
        // Update local cache after online operation succeeds
        await refreshAndCacheWatchlist(userId: userId)
    }
    
    // Check if a show is in user's watchlist
    func isInWatchlist(userId: String, showId: String) async throws -> Bool {
        // Try to check from in-memory cache first (fastest)
        if let cachedItems = inMemoryCache[userId] {
            if cachedItems.contains(where: { $0.show.id == showId }) {
                return true
            }
        }
        
        // Then try UserDefaults cache
        if let cachedItems = loadCachedWatchlist(userId: userId) {
            if cachedItems.contains(where: { $0.show.id == showId }) {
                return true
            }
        }
        
        // If offline, we've checked all local caches, so return false
        if isOffline() {
            return false
        }
        
        // If online, check Firestore
        let document = try await userCollection.document(userId)
            .collection("watchlist")
            .document(showId)
            .getDocument()
        
        return document.exists
    }
    
    // Get all shows in user's watchlist
    func getWatchlist(userId: String) async throws -> [WatchlistItem] {
        // First check in-memory cache for fastest access
        if let cachedItems = inMemoryCache[userId], !cachedItems.isEmpty {
            print("WatchlistService: Using in-memory cache with \(cachedItems.count) items")
            return cachedItems
        }
        
        // Then check UserDefaults cache
        if let cachedItems = loadCachedWatchlist(userId: userId), !cachedItems.isEmpty {
            print("WatchlistService: Loaded \(cachedItems.count) items from UserDefaults cache")
            // Store in memory for faster access next time
            inMemoryCache[userId] = cachedItems
            
            // If we're online, refresh cache in background for next time
            if !isOffline() {
                Task {
                    await refreshAndCacheWatchlist(userId: userId)
                }
            }
            
            return cachedItems
        }
        
        // If we're offline and have no cache, return empty array
        if isOffline() {
            print("WatchlistService: Device is offline with no cache available")
            return []
        }
        
        // If online with no cache, fetch from Firestore
        do {
            print("WatchlistService: Fetching watchlist from Firestore")
            let watchlistItems = try await fetchWatchlistFromFirestore(userId: userId)
            
            // Cache results for offline use
            cacheWatchlist(userId: userId, items: watchlistItems)
            
            // Also store in memory
            inMemoryCache[userId] = watchlistItems
            
            return watchlistItems
        } catch let error as NSError {
            print("WatchlistService: Error fetching from Firestore: \(error.localizedDescription)")
            
            // For network errors, return empty array instead of throwing
            if error.domain == NSURLErrorDomain || 
               (error.domain == "FIRFirestoreErrorDomain" && error.code == 17) {
                return []
            }
            
            // For other errors, rethrow
            throw error
        }
    }
    
    // Private method to fetch watchlist from Firestore
    private func fetchWatchlistFromFirestore(userId: String) async throws -> [WatchlistItem] {
        let snapshot = try await userCollection.document(userId)
            .collection("watchlist")
            .order(by: "dateAdded", descending: true)
            .getDocuments()
        
        var watchlistItems: [WatchlistItem] = []
        
        for document in snapshot.documents {
            if let showId = document.data()["showId"] as? String,
               let dateAdded = (document.data()["dateAdded"] as? Timestamp)?.dateValue() {
                
                do {
                    let show = try await FirestoreShowService.shared.getShow(id: showId)
                    watchlistItems.append(WatchlistItem(show: show, dateAdded: dateAdded))
                } catch {
                    print("WatchlistService: Error fetching show \(showId): \(error.localizedDescription)")
                    // Continue with other shows instead of failing completely
                }
            }
        }
        
        return watchlistItems
    }
    
    // MARK: - Caching Methods
    
    // Refresh and update the cache with latest watchlist data
    private func refreshAndCacheWatchlist(userId: String) async {
        do {
            let items = try await fetchWatchlistFromFirestore(userId: userId)
            cacheWatchlist(userId: userId, items: items)
            // Also update in-memory cache
            inMemoryCache[userId] = items
            print("WatchlistService: Refreshed cache with \(items.count) items")
        } catch {
            print("WatchlistService: Failed to refresh cache: \(error.localizedDescription)")
        }
    }
    
    // Cache watchlist items to UserDefaults
    private func cacheWatchlist(userId: String, items: [WatchlistItem]) {
        let encoder = JSONEncoder()
        do {
            let encodableItems = items.map { WatchlistItemCodable(from: $0) }
            let data = try encoder.encode(encodableItems)
            UserDefaults.standard.set(data, forKey: cachedWatchlistKey + "_" + userId)
            print("WatchlistService: Cached \(items.count) watchlist items to UserDefaults for user \(userId)")
        } catch {
            print("WatchlistService: Failed to cache watchlist: \(error.localizedDescription)")
        }
    }
    
    // Load cached watchlist items from UserDefaults (public access for error recovery)
    func loadCachedWatchlist(userId: String) -> [WatchlistItem]? {
        guard let data = UserDefaults.standard.data(forKey: cachedWatchlistKey + "_" + userId) else {
            print("WatchlistService: No cached data found in UserDefaults for user \(userId)")
            return nil
        }
        
        let decoder = JSONDecoder()
        do {
            let encodableItems = try decoder.decode([WatchlistItemCodable].self, from: data)
            let items = encodableItems.map { $0.toWatchlistItem() }
            print("WatchlistService: Successfully loaded \(items.count) items from UserDefaults cache")
            return items
        } catch {
            print("WatchlistService: Failed to decode cached watchlist: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Clear cached watchlist for a user (useful for testing or signout)
    func clearCache(for userId: String) {
        UserDefaults.standard.removeObject(forKey: cachedWatchlistKey + "_" + userId)
        inMemoryCache.removeValue(forKey: userId)
        print("WatchlistService: Cleared all cache for user \(userId)")
    }
    
    // Force immediate caching of watchlist items - useful for ensuring offline access
    func forceCacheWatchlist(userId: String, items: [WatchlistItem]) {
        cacheWatchlist(userId: userId, items: items)
        inMemoryCache[userId] = items
        print("WatchlistService: Force cached \(items.count) items for user \(userId)")
    }
    
    // Method to cache the watchlist without needing it right away
    // Call this when app launches or user logs in to prepare offline data
    func preCacheWatchlist(userId: String) {
        Task {
            do {
                let items = try await fetchWatchlistFromFirestore(userId: userId)
                cacheWatchlist(userId: userId, items: items)
                // Also update in-memory cache
                inMemoryCache[userId] = items
                print("WatchlistService: Pre-cached \(items.count) watchlist items for user \(userId)")
            } catch {
                print("WatchlistService: Failed to pre-cache watchlist: \(error.localizedDescription)")
            }
        }
    }
    
    // Try to determine if we're offline
    private func isOffline() -> Bool {
        return isCurrentlyOffline
    }
}

// Model for watchlist items
struct WatchlistItem: Identifiable {
    var id: String { show.id ?? "" }
    let show: FirestoreShow
    let dateAdded: Date
}

// Codable version of WatchlistItem for caching
private struct WatchlistItemCodable: Codable {
    let show: FirestoreShow
    let dateAdded: Date
    
    init(from item: WatchlistItem) {
        self.show = item.show
        self.dateAdded = item.dateAdded
    }
    
    func toWatchlistItem() -> WatchlistItem {
        return WatchlistItem(show: show, dateAdded: dateAdded)
    }
} 