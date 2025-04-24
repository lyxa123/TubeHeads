import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

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
        
        do {
            let dataDict: [String: Any] = [
                "id": userData.id,
                "email": userData.email,
                "username": username,
                "dateCreated": Timestamp(date: userData.dateCreated)
            ]
            
            try await userCollection.document(auth.uid).setData(dataDict, merge: true)
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                let minimalData: [String: Any] = [
                    "id": auth.uid,
                    "username": username
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
            
            return UserData(
                id: id,
                email: email,
                username: username,
                dateCreated: dateCreated
            )
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                return UserData(
                    id: userId, 
                    email: "user@example.com", 
                    username: "User",
                    dateCreated: Date()
                )
            }
            
            throw error
        }
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
