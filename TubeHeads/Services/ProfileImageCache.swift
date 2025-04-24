import SwiftUI
import FirebaseFirestore

// Utility class for handling profile image caching
class ProfileImageCache {
    static let shared = ProfileImageCache()
    
    // Thread-safe image cache
    private var imageCache = [String: UIImage]()
    private let imageCacheLock = NSLock()
    
    private init() { }
    
    // Safe cache access methods
    func storeImage(userId: String, image: UIImage?) {
        guard let image = image else { return }
        
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        
        imageCache[userId] = image
    }
    
    func getImage(userId: String) -> UIImage? {
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        
        return imageCache[userId]
    }
    
    func clearCache() {
        imageCacheLock.lock()
        defer { imageCacheLock.unlock() }
        
        imageCache.removeAll()
    }
    
    // Get profile image from Firestore and store in cache
    func getProfileImage(userId: String) async throws -> UIImage? {
        // First check cache
        if let cachedImage = getImage(userId: userId) {
            return cachedImage
        }
        
        // If not in cache, try to get from Firestore
        let document = try await Firestore.firestore().collection("profiles").document(userId).getDocument()
        if let data = document.data(),
           let base64String = data["profileImageBase64"] as? String,
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            // Cache the image safely
            storeImage(userId: userId, image: image)
            return image
        }
        
        return nil
    }
} 
