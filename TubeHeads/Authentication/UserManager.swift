import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

struct UserData: Codable {
    let id: String
    let email: String
    let username: String
    let dateCreated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case dateCreated
    }
}

final class UserManager {
    static let shared = UserManager()
    private let userCollection = Firestore.firestore().collection("users")
    
    private init() { }
    
    func createNewUser(auth: AuthDataResultModel, username: String) async throws {
        let userData = UserData(
            id: auth.uid,
            email: auth.email ?? "",
            username: username,
            dateCreated: Date()
        )
        
        try userCollection.document(auth.uid).setData(from: userData)
    }
    
    func getUser(userId: String) async throws -> UserData {
        try await userCollection.document(userId).getDocument(as: UserData.self)
    }
    
    func usernameExists(_ username: String) async throws -> Bool {
        let snapshot = try await userCollection
            .whereField("username", isEqualTo: username)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
} 
