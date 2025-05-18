import FirebaseFirestore

struct AppUser: Identifiable {
    let id: String
    let username: String
    let profileImageURL: String
}

enum UserService {
    static func searchUsers(by keyword: String, completion: @escaping (Result<[AppUser], Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: keyword)
            .whereField("username", isLessThan: keyword + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    let users = snapshot?.documents.compactMap { doc -> AppUser? in
                        let data = doc.data()
                        return AppUser(
                            id: doc.documentID,
                            username: data["username"] as? String ?? "",
                            profileImageURL: data["profileImageURL"] as? String ?? ""
                        )
                    } ?? []
                    completion(.success(users))
                }
            }
    }
}
