import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// Structure to represent a follow relationship
struct FollowRelationship: Codable, Identifiable {
    @DocumentID var id: String?
    let followerId: String // User who is following
    let followedId: String // User being followed
    let timestamp: Date
    
    // Helper for showing when the follow occurred
    var followedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// Structure to represent a user with follow stats
struct UserWithFollowStats: Codable {
    let id: String
    let username: String
    let email: String
    var profileImageUrl: String?
    var followerCount: Int
    var followingCount: Int
    var isFollowedByCurrentUser: Bool
    
    // Initialize from UserData plus follow stats
    init(userData: UserData, followerCount: Int = 0, followingCount: Int = 0, isFollowedByCurrentUser: Bool = false) {
        self.id = userData.id
        self.username = userData.username
        self.email = userData.email
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.isFollowedByCurrentUser = isFollowedByCurrentUser
        // Profile image would be fetched separately or added to UserData
    }
}

class FollowService {
    static let shared = FollowService()
    
    private let followsCollection = Firestore.firestore().collection("follows")
    private let usersCollection = Firestore.firestore().collection("users")
    
    private init() {}
    
    // Follow a user
    func followUser(currentUserId: String, targetUserId: String) async throws {
        // Check if already following
        let isAlreadyFollowing = try await checkIfFollowing(followerId: currentUserId, followedId: targetUserId)
        
        if isAlreadyFollowing {
            // Already following, no need to create duplicate
            return
        }
        
        // Create new follow relationship
        let follow = FollowRelationship(
            followerId: currentUserId,
            followedId: targetUserId,
            timestamp: Date()
        )
        
        let document = followsCollection.document()
        try document.setData(from: follow)
        
        // Update follower/following counts (optional transaction for atomicity)
        try await Firestore.firestore().runTransaction { transaction, errorPointer in
            // Update follower count for target user
            let targetUserRef = self.usersCollection.document(targetUserId)
            transaction.updateData(["followerCount": FieldValue.increment(Int64(1))], forDocument: targetUserRef)
            
            // Update following count for current user
            let currentUserRef = self.usersCollection.document(currentUserId)
            transaction.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: currentUserRef)
            
            return nil
        }
    }
    
    // Unfollow a user
    func unfollowUser(currentUserId: String, targetUserId: String) async throws {
        // Find the follow relationship
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: currentUserId)
            .whereField("followedId", isEqualTo: targetUserId)
            .getDocuments()
        
        // If relationship exists, delete it
        guard let document = snapshot.documents.first else {
            // Not following, nothing to do
            return
        }
        
        try await document.reference.delete()
        
        // Update counts (optional transaction for atomicity)
        try await Firestore.firestore().runTransaction { transaction, errorPointer in
            // Update follower count for target user
            let targetUserRef = self.usersCollection.document(targetUserId)
            transaction.updateData(["followerCount": FieldValue.increment(Int64(-1))], forDocument: targetUserRef)
            
            // Update following count for current user
            let currentUserRef = self.usersCollection.document(currentUserId)
            transaction.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: currentUserRef)
            
            return nil
        }
    }
    
    // Check if a user is following another
    func checkIfFollowing(followerId: String, followedId: String) async throws -> Bool {
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: followerId)
            .whereField("followedId", isEqualTo: followedId)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    // Get all followers of a user
    func getFollowers(userId: String) async throws -> [UserWithFollowStats] {
        // Get all relationships where this user is being followed
        let snapshot = try await followsCollection
            .whereField("followedId", isEqualTo: userId)
            .getDocuments()
        
        // Extract follower IDs
        let followerIds = snapshot.documents.compactMap { document -> String? in
            guard let relationship = try? document.data(as: FollowRelationship.self) else { return nil }
            return relationship.followerId
        }
        
        // Fetch user details for each follower
        var followers: [UserWithFollowStats] = []
        for followerId in followerIds {
            if let userData = try? await UserManager.shared.getUser(userId: followerId) {
                let followerCount = try await getFollowerCount(userId: followerId)
                let followingCount = try await getFollowingCount(userId: followerId)
                
                followers.append(UserWithFollowStats(
                    userData: userData,
                    followerCount: followerCount,
                    followingCount: followingCount
                ))
            }
        }
        
        return followers
    }
    
    // Get all users a user is following
    func getFollowing(userId: String) async throws -> [UserWithFollowStats] {
        // Get all relationships where this user is following others
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        // Extract followed user IDs
        let followedIds = snapshot.documents.compactMap { document -> String? in
            guard let relationship = try? document.data(as: FollowRelationship.self) else { return nil }
            return relationship.followedId
        }
        
        // Fetch user details for each followed user
        var following: [UserWithFollowStats] = []
        for followedId in followedIds {
            if let userData = try? await UserManager.shared.getUser(userId: followedId) {
                let followerCount = try await getFollowerCount(userId: followedId)
                let followingCount = try await getFollowingCount(userId: followedId)
                
                following.append(UserWithFollowStats(
                    userData: userData,
                    followerCount: followerCount,
                    followingCount: followingCount,
                    isFollowedByCurrentUser: true
                ))
            }
        }
        
        return following
    }
    
    // Get follower count for a user
    func getFollowerCount(userId: String) async throws -> Int {
        let snapshot = try await followsCollection
            .whereField("followedId", isEqualTo: userId)
            .count
            .getAggregation(source: .server)
        
        return Int(truncating: snapshot.count)
    }
    
    // Get following count for a user
    func getFollowingCount(userId: String) async throws -> Int {
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: userId)
            .count
            .getAggregation(source: .server)
        
        return Int(truncating: snapshot.count)
    }
    
    // Get suggested users to follow
    func getSuggestedUsers(forUserId userId: String, limit: Int = 10) async throws -> [UserWithFollowStats] {
        // Get IDs of users already being followed
        let followingSnapshot = try await followsCollection
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        let followingIds = followingSnapshot.documents.compactMap { document -> String? in
            guard let relationship = try? document.data(as: FollowRelationship.self) else { return nil }
            return relationship.followedId
        }
        
        // Add current user ID to exclude list
        var excludeIds = followingIds
        excludeIds.append(userId)
        
        // Fetch users not in the exclude list, limit to requested number
        let usersSnapshot = try await usersCollection
            .limit(to: limit + excludeIds.count) // Get extra to account for filtering
            .getDocuments()
        
        // Filter and process users
        var suggestedUsers: [UserWithFollowStats] = []
        for document in usersSnapshot.documents {
            guard let id = document.data()["id"] as? String,
                  !excludeIds.contains(id) else {
                continue
            }
            
            do {
                let userData = try await UserManager.shared.getUser(userId: id)
                let followerCount = try await getFollowerCount(userId: id)
                let followingCount = try await getFollowingCount(userId: id)
                
                suggestedUsers.append(UserWithFollowStats(
                    userData: userData,
                    followerCount: followerCount,
                    followingCount: followingCount
                ))
                
                if suggestedUsers.count >= limit {
                    break
                }
            } catch {
                print("Error getting user data: \(error)")
                continue
            }
        }
        
        return suggestedUsers
    }
} 