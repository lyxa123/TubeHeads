import Foundation
import FirebaseFirestore

struct ShowList: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let description: String
    var isPrivate: Bool
    let userId: String
    let dateCreated: Date
    var showIds: [String] = []
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dateCreated)
    }
}

class ListService {
    static let shared = ListService()
    
    private let userCollection = Firestore.firestore().collection("users")
    private let listCollection = Firestore.firestore().collection("lists")
    
    private init() {}
    
    // Create a new list
    func createList(name: String, description: String, isPrivate: Bool, userId: String) async throws -> String {
        let newList = ShowList(
            name: name,
            description: description,
            isPrivate: isPrivate,
            userId: userId,
            dateCreated: Date()
        )
        
        let docRef = listCollection.document()
        try docRef.setData(from: newList)
        
        return docRef.documentID
    }
    
    // Get a list by its ID
    func getList(id: String) async throws -> ShowList {
        return try await listCollection.document(id).getDocument(as: ShowList.self)
    }
    
    // Get all lists for a user
    func getUserLists(userId: String) async throws -> [ShowList] {
        let snapshot = try await listCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "dateCreated", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: ShowList.self)
        }
    }
    
    // Add a show to a list
    func addShowToList(listId: String, showId: String) async throws {
        let listRef = listCollection.document(listId)
        
        try await listRef.updateData([
            "showIds": FieldValue.arrayUnion([showId])
        ])
    }
    
    // Remove a show from a list
    func removeShowFromList(listId: String, showId: String) async throws {
        let listRef = listCollection.document(listId)
        
        try await listRef.updateData([
            "showIds": FieldValue.arrayRemove([showId])
        ])
    }
    
    // Delete a list
    func deleteList(listId: String) async throws {
        try await listCollection.document(listId).delete()
    }
    
    // Update list privacy setting
    func updateListPrivacy(listId: String, isPrivate: Bool) async throws {
        let listRef = listCollection.document(listId)
        
        try await listRef.updateData([
            "isPrivate": isPrivate
        ])
    }
    
    // Get shows in a list
    func getShowsInList(listId: String) async throws -> [FirestoreShow] {
        // Get the list
        let list = try await getList(id: listId)
        
        // If no shows in list, return empty array
        if list.showIds.isEmpty {
            return []
        }
        
        // Get all shows in the list
        var shows: [FirestoreShow] = []
        
        for showId in list.showIds {
            do {
                let show = try await FirestoreShowService.shared.getShow(id: showId)
                shows.append(show)
            } catch {
                print("Error getting show with ID \(showId): \(error)")
                // Continue with the next show
            }
        }
        
        return shows
    }
} 