import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct UserData: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let dateCreated: Date
    var followerCount: Int = 0
    var followingCount: Int = 0
    var profileImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case dateCreated
        case followerCount
        case followingCount
        case profileImageUrl
    }
}

final class UserManager {
    static let shared = UserManager()
    private let userCollection = Firestore.firestore().collection("users")
    
    private init() { }
    
    func createNewUser(auth: AuthDataResultModel, username: String) async throws {
        let usernameLowercased = username.lowercased()
        
        let userData = UserData(
            id: auth.uid,
            email: auth.email ?? "",
            username: username,
            dateCreated: Date(),
            followerCount: 0,
            followingCount: 0
        )
        
        do {
            let dataDict: [String: Any] = [
                "id": userData.id,
                "email": userData.email,
                "username": username,
                "username_lowercase": usernameLowercased,
                "dateCreated": Timestamp(date: userData.dateCreated),
                "followerCount": 0,
                "followingCount": 0
            ]
            
            try await userCollection.document(auth.uid).setData(dataDict, merge: true)
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                let minimalData: [String: Any] = [
                    "id": auth.uid,
                    "username": username,
                    "username_lowercase": usernameLowercased,
                    "followerCount": 0,
                    "followingCount": 0
                ]
                
                do {
                    try await userCollection.document(auth.uid).setData(minimalData, merge: true)
                    return
                } catch {
                    // Let it fall through to throw the original error
                }
            }
            
            throw error
        }
    }
    
    func getUser(userId: String) async throws -> UserData {
        do {
            let document = try await userCollection.document(userId).getDocument()
            
            if !document.exists {
                throw NSError(domain: "UserManagerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
            }
            
            guard let data = document.data() else {
                throw NSError(domain: "UserManagerError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Document data is nil"])
            }
            
            let id = data["id"] as? String ?? userId
            let email = data["email"] as? String ?? ""
            let username = data["username"] as? String ?? "User"
            let dateCreated = (data["dateCreated"] as? Timestamp)?.dateValue() ?? Date()
            let followerCount = data["followerCount"] as? Int ?? 0
            let followingCount = data["followingCount"] as? Int ?? 0
            let profileImageUrl = data["profileImageUrl"] as? String
            
            return UserData(
                id: id,
                email: email,
                username: username,
                dateCreated: dateCreated,
                followerCount: followerCount,
                followingCount: followingCount,
                profileImageUrl: profileImageUrl
            )
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                return UserData(
                    id: userId,
                    email: "user@example.com",
                    username: "User",
                    dateCreated: Date(),
                    followerCount: 0,
                    followingCount: 0
                )
            }
            
            throw error
        }
    }
    
    // Updated: Search users by username prefix (case insensitive) with limit
    func searchUsersByUsername(query: String, limit: Int = 20) async throws -> [UserData] {
        let lowercasedQuery = query.lowercased()
        guard !lowercasedQuery.isEmpty else { return [] }
        
        let endQuery = lowercasedQuery + "\u{f8ff}"
        
        let snapshot = try await userCollection
            .whereField("username_lowercase", isGreaterThanOrEqualTo: lowercasedQuery)
            .whereField("username_lowercase", isLessThanOrEqualTo: endQuery)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: UserData.self)
        }
    }

    
    func updateFollowerCount(userId: String, increment: Int) async throws {
        let userRef = userCollection.document(userId)
        try await userRef.updateData([
            "followerCount": FieldValue.increment(Int64(increment))
        ])
    }
    
    func updateFollowingCount(userId: String, increment: Int) async throws {
        let userRef = userCollection.document(userId)
        try await userRef.updateData([
            "followingCount": FieldValue.increment(Int64(increment))
        ])
    }
    
    func usernameExists(_ username: String) async throws -> Bool {
        do {
            let snapshot = try await userCollection
                .whereField("username", isEqualTo: username)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            if let nsError = error as? NSError,
               nsError.domain == "FIRFirestoreErrorDomain" &&
               nsError.code == 7 {
                return false
            }
            
            throw error
        }
    }
}
