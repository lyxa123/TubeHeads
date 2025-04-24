import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ShowReview: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let showId: String
    let content: String
    let rating: Double
    let timestamp: Date
    var username: String?
    var userProfileImageURL: String?
    var likes: Int = 0
    var userLikes: [String] = [] // Array of userIds who liked this review
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
    
    // This computed property can help debug issues with profile image
    var profileImageDescription: String {
        if let imageData = userProfileImageURL {
            return "Image data length: \(imageData.count)"
        } else {
            return "No image data"
        }
    }
}

class FirestoreReviewService {
    static let shared = FirestoreReviewService()
    
    private let reviewsCollection = Firestore.firestore().collection("reviews")
    private let showsCollection = Firestore.firestore().collection("shows")
    private let profilesCollection = Firestore.firestore().collection("profiles")
    
    private init() {}
    
    // Add a review for a show
    func addReview(userId: String, showId: String, content: String, rating: Double) async throws -> String {
        // Get basic user profile info directly from Firestore
        do {
            // Get user's profile document
            let profileDoc = try await profilesCollection.document(userId).getDocument()
            let profileData = profileDoc.data()
            
            // Extract username and profile image
            let username = profileData?["username"] as? String ?? "User"
            let profileImageBase64 = profileData?["profileImageBase64"] as? String
            
            let review = ShowReview(
                userId: userId,
                showId: showId,
                content: content,
                rating: rating,
                timestamp: Date(),
                username: username,
                userProfileImageURL: profileImageBase64
            )
            
            let reviewRef = reviewsCollection.document()
            try reviewRef.setData(from: review)
            
            // Update the show's reviews count
            let showRef = showsCollection.document(showId)
            try await showRef.updateData([
                "commentsCount": FieldValue.increment(Int64(1))
            ])
            
            return reviewRef.documentID
        } catch {
            print("Error getting profile for review: \(error)")
            
            // Create a review without profile data
            let review = ShowReview(
                userId: userId,
                showId: showId,
                content: content,
                rating: rating,
                timestamp: Date(),
                username: "User",
                userProfileImageURL: nil
            )
            
            let reviewRef = reviewsCollection.document()
            try reviewRef.setData(from: review)
            
            // Update the show's reviews count
            let showRef = showsCollection.document(showId)
            try await showRef.updateData([
                "commentsCount": FieldValue.increment(Int64(1))
            ])
            
            return reviewRef.documentID
        }
    }
    
    // Get all reviews for a show
    func getReviewsForShow(showId: String) async throws -> [ShowReview] {
        print("🔍 Fetching reviews for show ID: \(showId)")
        
        let snapshot = try await reviewsCollection
            .whereField("showId", isEqualTo: showId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        print("🔍 Found \(snapshot.documents.count) reviews")
        
        let reviews = snapshot.documents.compactMap { document in
            do {
                let review = try document.data(as: ShowReview.self)
                print("🔍 Review from \(review.username ?? "unknown"): has profileImage? \(review.userProfileImageURL != nil)")
                if let profileImageData = review.userProfileImageURL {
                    print("🔍   Profile image data length: \(profileImageData.count)")
                }
                return review
            } catch {
                print("🔍 Error decoding review: \(error)")
                return nil
            }
        }
        
        return reviews
    }
    
    // Delete a review
    func deleteReview(reviewId: String) async throws {
        // Get the review first to get the showId
        let review = try await reviewsCollection.document(reviewId).getDocument(as: ShowReview.self)
        
        // Delete the review
        try await reviewsCollection.document(reviewId).delete()
        
        // Update the show's review count
        let showRef = showsCollection.document(review.showId)
        try await showRef.updateData([
            "commentsCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    // Like a review
    func likeReview(reviewId: String, userId: String) async throws {
        let reviewRef = reviewsCollection.document(reviewId)
        let review = try await reviewRef.getDocument(as: ShowReview.self)
        
        // Check if user already liked this review
        if review.userLikes.contains(userId) {
            // Unlike
            try await reviewRef.updateData([
                "likes": FieldValue.increment(Int64(-1)),
                "userLikes": FieldValue.arrayRemove([userId])
            ])
        } else {
            // Like
            try await reviewRef.updateData([
                "likes": FieldValue.increment(Int64(1)),
                "userLikes": FieldValue.arrayUnion([userId])
            ])
        }
    }
    
    // Edit a review
    func editReview(reviewId: String, content: String, rating: Double) async throws {
        let reviewRef = reviewsCollection.document(reviewId)
        
        try await reviewRef.updateData([
            "content": content,
            "rating": rating,
            "timestamp": Date() // Update timestamp to show it was edited
        ])
    }
} 