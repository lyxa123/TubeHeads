import Foundation
import FirebaseFirestore

class WatchlistService {
    static let shared = WatchlistService()
    
    private let userCollection = Firestore.firestore().collection("users")
    
    private init() {}
    
    // Add a show to user's watchlist
    func addToWatchlist(userId: String, showId: String) async throws {
        try await userCollection.document(userId)
            .collection("watchlist")
            .document(showId)
            .setData([
                "dateAdded": Timestamp(date: Date()),
                "showId": showId
            ])
    }
    
    // Remove a show from user's watchlist
    func removeFromWatchlist(userId: String, showId: String) async throws {
        try await userCollection.document(userId)
            .collection("watchlist")
            .document(showId)
            .delete()
    }
    
    // Check if a show is in user's watchlist
    func isInWatchlist(userId: String, showId: String) async throws -> Bool {
        let document = try await userCollection.document(userId)
            .collection("watchlist")
            .document(showId)
            .getDocument()
        
        return document.exists
    }
    
    // Get all shows in user's watchlist
    func getWatchlist(userId: String) async throws -> [WatchlistItem] {
        let snapshot = try await userCollection.document(userId)
            .collection("watchlist")
            .order(by: "dateAdded", descending: true)
            .getDocuments()
        
        var watchlistItems: [WatchlistItem] = []
        
        for document in snapshot.documents {
            if let showId = document.data()["showId"] as? String,
               let dateAdded = (document.data()["dateAdded"] as? Timestamp)?.dateValue() {
                
                let show = try await FirestoreShowService.shared.getShow(id: showId)
                watchlistItems.append(WatchlistItem(show: show, dateAdded: dateAdded))
            }
        }
        
        return watchlistItems
    }
}

// Model for watchlist items
struct WatchlistItem: Identifiable {
    var id: String { show.id ?? "" }
    let show: FirestoreShow
    let dateAdded: Date
} 