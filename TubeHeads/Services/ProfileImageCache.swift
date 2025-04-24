import Foundation
import UIKit
import FirebaseFirestore

// Utility class for handling profile image caching
class ProfileImageCache {
    static let shared = ProfileImageCache()
    
    // Add image cache with thread safety
    private var imageCache: [String: UIImage] = [:]
    private let cacheLock = NSLock()
    
    private init() { }
    
    // Safe cache access methods
    func getCachedImage(_ userId: String) -> UIImage? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return imageCache[userId]
    }
    
    func setCachedImage(_ userId: String, image: UIImage) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        imageCache[userId] = image
    }
    
    func clearImageCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        imageCache.removeAll()
    }
    
    // Get profile image (from cache or decode from base64)
    func getProfileImage(userId: String) async throws -> UIImage? {
        // First check cache safely
        if let cachedImage = getCachedImage(userId) {
            print("Using cached profile image for user \(userId)")
            return cachedImage
        }
        
        // If not in cache, try to get from Firestore
        let profileCollection = Firestore.firestore().collection("profiles")
        let document = try await profileCollection.document(userId).getDocument()
        
        if let data = document.data(),
           let base64String = data["profileImageBase64"] as? String,
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            // Cache the image safely
            setCachedImage(userId, image: image)
            return image
        }
        
        return nil
    }
} 
