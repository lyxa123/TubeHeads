import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

struct FirestoreShow: Identifiable, Codable {
    @DocumentID var id: String?
    let tmdbId: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    
    // Firestore-specific fields
    var userRatings: [String: Double] = [:]  // userId: rating
    var averageUserRating: Double = 0.0
    var commentsCount: Int = 0
    
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var releaseYear: String {
        guard let firstAirDate = firstAirDate, firstAirDate.count >= 4 else { return "TBA" }
        return String(firstAirDate.prefix(4))
    }
}

class FirestoreShowService {
    static let shared = FirestoreShowService()
    
    private let showsCollection = Firestore.firestore().collection("shows")
    
    private init() {}
    
    // Add or update a show in Firestore
    func saveShow(from tvShow: TVShow) async throws -> String {
        // Check if show already exists by TMDB ID
        let snapshot = try await showsCollection
            .whereField("tmdbId", isEqualTo: tvShow.id)
            .getDocuments()
        
        // If show exists, return its ID
        if let existingDoc = snapshot.documents.first {
            return existingDoc.documentID
        }
        
        // Otherwise create a new show
        let firestoreShow = FirestoreShow(
            tmdbId: tvShow.id,
            name: tvShow.name,
            overview: tvShow.overview,
            posterPath: tvShow.posterPath,
            backdropPath: tvShow.backdropPath,
            firstAirDate: tvShow.firstAirDate
        )
        
        let docRef = showsCollection.document()
        try docRef.setData(from: firestoreShow)
        
        return docRef.documentID
    }
    
    // Get a show by its Firestore ID
    func getShow(id: String) async throws -> FirestoreShow {
        return try await showsCollection.document(id).getDocument(as: FirestoreShow.self)
    }
    
    // Get a show by its TMDB ID
    func getShowByTMDBId(tmdbId: Int) async throws -> FirestoreShow? {
        let snapshot = try await showsCollection
            .whereField("tmdbId", isEqualTo: tmdbId)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        return try document.data(as: FirestoreShow.self)
    }
    
    // Add a user rating to a show
    func rateShow(showId: String, userId: String, rating: Double) async throws {
        let showRef = showsCollection.document(showId)
        
        // Get the current show to update ratings
        let show = try await showRef.getDocument(as: FirestoreShow.self)
        var userRatings = show.userRatings
        userRatings[userId] = rating
        
        // Calculate new average
        let newAverage = userRatings.values.reduce(0.0, +) / Double(userRatings.count)
        
        // Update the document
        try await showRef.updateData([
            "userRatings": userRatings,
            "averageUserRating": newAverage
        ])
    }
    
    // Get popular shows based on user ratings
    func getPopularShows(limit: Int = 20) async throws -> [FirestoreShow] {
        let snapshot = try await showsCollection
            .order(by: "averageUserRating", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreShow.self)
        }
    }
} 
