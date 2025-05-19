//
//  TubeHeadsApp.swift
//  TubeHeads
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore //  Added for Firestore offline support
import FirebaseMessaging // Added for Push Notifications

@main
struct TubeHeadsApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // first view on the app
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        print("Firebase Configured!")
        
        // ✅ Enable Firestore offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
        
        // Initialize the LocationManager
        _ = LocationManager.shared
        
        // Initialize and setup NotificationService
        NotificationService.shared.setupNotifications()
        
        return true
    }
}
