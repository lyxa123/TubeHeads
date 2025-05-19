import SwiftUI
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import FirebaseAuth

enum NotificationType: String, Codable {
    case newFollower
    case friendActivity
}

struct NotificationPayload: Codable {
    let type: NotificationType
    let fromUserId: String
    let fromUsername: String
    var showId: String?
    var showName: String?
    var rating: Double?
    
    var title: String {
        switch type {
        case .newFollower:
            return "\(fromUsername) started following you"
        case .friendActivity:
            if let showName = showName, let rating = rating {
                return "\(fromUsername) rated \(showName)"
            } else {
                return "\(fromUsername) added a new rating"
            }
        }
    }
    
    var body: String {
        switch type {
        case .newFollower:
            return "Tap to view their profile"
        case .friendActivity:
            if let rating = rating {
                return "They gave it \(rating) stars"
            } else {
                return "Check out what they're watching"
            }
        }
    }
}

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    // Token cache for offline support
    private var fcmTokens: [String: String] = [:]
    private let tokenCacheKey = "FCMTokenCache"
    
    private override init() {
        super.init()
        
        // Load cached tokens
        if let data = UserDefaults.standard.data(forKey: tokenCacheKey),
           let tokens = try? JSONDecoder().decode([String: String].self, from: data) {
            self.fcmTokens = tokens
        }
    }
    
    // MARK: - Setup Methods
    
    func setupNotifications() {
        // Register for remote notifications
        UIApplication.shared.registerForRemoteNotifications()
        
        // Set up notification categories and actions
        setupNotificationCategories()
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request permission
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("NotificationService: User granted permission for notifications")
            } else if let error = error {
                print("NotificationService: Error requesting notification permission: \(error.localizedDescription)")
            } else {
                print("NotificationService: User denied notification permission")
            }
        }
    }
    
    // Update FCM token for a user
    func updateFCMToken(userId: String, token: String) async throws {
        do {
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "fcmToken": token
            ])
            
            // Cache the token
            fcmTokens[userId] = token
            saveFCMTokenCache()
            
            print("NotificationService: FCM token updated successfully")
        } catch {
            print("NotificationService: Error updating FCM token: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Clear FCM token when user signs out
    func clearFCMToken(userId: String) async throws {
        do {
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete()
            ])
            
            // Remove from cache
            fcmTokens.removeValue(forKey: userId)
            saveFCMTokenCache()
            
            print("NotificationService: FCM token cleared successfully")
        } catch {
            print("NotificationService: Error clearing FCM token: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func saveFCMTokenCache() {
        if let data = try? JSONEncoder().encode(fcmTokens) {
            UserDefaults.standard.set(data, forKey: tokenCacheKey)
        }
    }
    
    private func setupNotificationCategories() {
        // Create categories for different notification types
        let followCategory = UNNotificationCategory(
            identifier: NotificationType.newFollower.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        let activityCategory = UNNotificationCategory(
            identifier: NotificationType.friendActivity.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Register the categories
        UNUserNotificationCenter.current().setNotificationCategories([followCategory, activityCategory])
    }
    
    // MARK: - Notification Sending Methods
    
    // Send a follow notification
    func sendFollowNotification(fromUserId: String, fromUsername: String, toUserId: String) async throws {
        // Create notification payload
        let payload = NotificationPayload(
            type: .newFollower,
            fromUserId: fromUserId,
            fromUsername: fromUsername
        )
        
        // Send the notification
        try await sendNotification(to: toUserId, payload: payload)
    }
    
    // Send a rating activity notification
    func sendRatingNotification(fromUserId: String, fromUsername: String, toUserId: String, showId: String, showName: String, rating: Double) async throws {
        // Create notification payload
        let payload = NotificationPayload(
            type: .friendActivity,
            fromUserId: fromUserId,
            fromUsername: fromUsername,
            showId: showId,
            showName: showName,
            rating: rating
        )
        
        // Send the notification
        try await sendNotification(to: toUserId, payload: payload)
    }
    
    // Generic method to send a notification
    private func sendNotification(to userId: String, payload: NotificationPayload) async throws {
        // Get user's FCM token
        var fcmToken: String?
        
        // Try from cache first
        fcmToken = fcmTokens[userId]
        
        // If not in cache, try from Firestore
        if fcmToken == nil {
            do {
                let document = try await Firestore.firestore().collection("users").document(userId).getDocument()
                fcmToken = document.data()?["fcmToken"] as? String
                
                // Cache if found
                if let token = fcmToken {
                    fcmTokens[userId] = token
                    saveFCMTokenCache()
                }
            } catch {
                print("NotificationService: Error fetching FCM token: \(error.localizedDescription)")
            }
        }
        
        guard let fcmToken = fcmToken else {
            print("NotificationService: User doesn't have FCM token")
            return
        }
        
        // In a real app, you would send this to your server which would use Firebase Admin SDK
        // For demonstration purposes, we'll just log what would be sent
        print("NotificationService: Would send FCM notification to token: \(fcmToken)")
        print("NotificationService: Notification title: \(payload.title)")
        print("NotificationService: Notification body: \(payload.body)")
        
        // In a real implementation, call your own server API to send the notification
        // try await sendToServer(token: fcmToken, payload: payload)
    }
    
    // This is a placeholder for your server API call
    private func sendToServer(token: String, payload: NotificationPayload) async throws {
        // Convert payload to JSON
        guard let payloadData = try? JSONEncoder().encode(payload),
              let payloadJson = String(data: payloadData, encoding: .utf8) else {
            throw NSError(domain: "NotificationServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize notification data"])
        }
        
        // Here you would make an HTTP request to your server
        // Your server would then use Firebase Admin SDK to send the notification
        
        // Example implementation would look something like:
        /*
        let url = URL(string: "https://your-server.com/send-notification")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "token": token,
            "payload": payloadJson
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "NotificationServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server returned error"])
        }
        */
    }
    
    // MARK: - Notification Handling Methods
    
    func handleNotificationPayload(_ payload: [AnyHashable: Any]) {
        // Extract data from payload
        guard let userInfo = payload as? [String: Any],
              let fromUserId = userInfo["fromUserId"] as? String else {
            return
        }
        
        if let typeString = userInfo["type"] as? String,
           let type = NotificationType(rawValue: typeString) {
            
            switch type {
            case .newFollower:
                print("NotificationService: Should navigate to profile of \(fromUserId)")
                // Navigation would happen here
                
            case .friendActivity:
                if let showId = userInfo["showId"] as? String {
                    print("NotificationService: Should navigate to show \(showId)")
                    // Navigation would happen here
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even if app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle tap on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationPayload(response.notification.request.content.userInfo)
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("NotificationService: Firebase registration token: \(String(describing: fcmToken))")
        
        // Store this token in Firestore for the current user
        if let token = fcmToken, let userId = Auth.auth().currentUser?.uid {
            Task {
                try await updateFCMToken(userId: userId, token: token)
            }
        }
    }
} 