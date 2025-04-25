import SwiftUI
import FirebaseAuth
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
// Import the file containing UserProfileImageView
import UIKit
import Foundation

// Extended user profile model to include profile-specific fields
struct UserProfile: Codable {
    let userId: String
    var username: String
    var bio: String
    var location: String
    var hasProfileImage: Bool
    var profileImageBase64: String?
    var lastUpdated: Date
    var isPublic: Bool
    var watchedShows: [WatchedShow]
    
    enum CodingKeys: String, CodingKey {
        case userId
        case username
        case bio
        case location
        case hasProfileImage
        case profileImageBase64
        case lastUpdated
        case isPublic
        case watchedShows
    }
}

// Model for watched shows
struct WatchedShow: Codable, Identifiable {
    var id: String
    var title: String
    var imageName: String?
    var dateWatched: Date
    var rating: Int? // Optional rating out of 5
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageName
        case dateWatched
        case rating
    }
}

// Add image resizing extension
extension UIImage {
    func resized(toWidth width: CGFloat, quality: CGFloat = 0.5) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // Further compress the image data
        guard let imageData = resizedImage?.jpegData(compressionQuality: quality) else {
            return resizedImage
        }
        
        return UIImage(data: imageData)
    }
}

class ProfileManager {
    static let shared = ProfileManager()
    private let profileCollection = Firestore.firestore().collection("profiles")
    
    // Add image cache with thread safety
    private var imageCache: [String: UIImage] = [:]
    private let cacheLock = NSLock()
    
    private init() { }
    
    // Safe cache access methods
    private func getCachedImage(_ userId: String) -> UIImage? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return imageCache[userId]
    }
    
    private func setCachedImage(_ userId: String, image: UIImage) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        imageCache[userId] = image
    }
    
    private func clearImageCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        imageCache.removeAll()
    }
    
    // Save or update user profile data
    func saveProfile(userId: String, username: String, bio: String, location: String, profileImage: UIImage?, isPublic: Bool = true) async throws {
        let hasProfileImage = profileImage != nil
        var profileData: [String: Any] = [
            "userId": userId,
            "username": username,
            "bio": bio,
            "location": location,
            "hasProfileImage": hasProfileImage,
            "lastUpdated": Timestamp(date: Date()),
            "isPublic": isPublic
        ]
        
        // If there's a profile image, resize, compress, and convert to base64
        if let originalImage = profileImage {
            // Resize the image to max 250 points width
            guard let resizedImage = originalImage.resized(toWidth: 250, quality: 0.3) else {
                throw NSError(domain: "ProfileManagerError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"])
            }
            
            // Add to cache safely
            setCachedImage(userId, image: resizedImage)
            
            guard let imageData = resizedImage.jpegData(compressionQuality: 0.3) else {
                throw NSError(domain: "ProfileManagerError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            // Check the size before trying to store
            let base64String = imageData.base64EncodedString()
            let estimatedSize = base64String.utf8.count
            
            // Firestore has a 1MB document size limit (1,048,576 bytes)
            if estimatedSize > 900000 {  // Leave some room for other fields (900KB)
                throw NSError(domain: "ProfileManagerError", code: 413, userInfo: [NSLocalizedDescriptionKey: "Image too large for Firestore. Please use a smaller image."])
            }
            
            profileData["profileImageBase64"] = base64String
        } else {
            // Clear any existing profile image
            profileData["profileImageBase64"] = nil
        }
        
        // Save profile data to Firestore
        try await profileCollection.document(userId).setData(profileData, merge: true)
    }
    
    // Get user profile data
    func getProfile(userId: String) async throws -> UserProfile {
        // Get profile document
        let document = try await profileCollection.document(userId).getDocument()
        
        if !document.exists {
            // Return default profile if not found
            return UserProfile(
                userId: userId,
                username: "User",
                bio: "No bio yet",
                location: "",
                hasProfileImage: false,
                profileImageBase64: nil,
                lastUpdated: Date(),
                isPublic: true,
                watchedShows: []
            )
        }
        
        // Parse profile data
        guard let data = document.data() else {
            throw NSError(domain: "ProfileManagerError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Document data is nil"])
        }
        
        let profileImageBase64 = data["profileImageBase64"] as? String
        
        // If there's a base64 image, decode and cache it safely
        if let base64String = profileImageBase64, 
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            setCachedImage(userId, image: image)
        }
        
        // Parse watched shows list
        var watchedShows: [WatchedShow] = []
        if let watchedShowsData = data["watchedShows"] as? [[String: Any]] {
            for showData in watchedShowsData {
                if let id = showData["id"] as? String,
                   let title = showData["title"] as? String {
                    let dateWatched = (showData["dateWatched"] as? Timestamp)?.dateValue() ?? Date()
                    let imageName = showData["imageName"] as? String
                    let rating = showData["rating"] as? Int
                    
                    let show = WatchedShow(
                        id: id,
                        title: title,
                        imageName: imageName,
                        dateWatched: dateWatched,
                        rating: rating
                    )
                    watchedShows.append(show)
                }
            }
        }
        
        return UserProfile(
            userId: data["userId"] as? String ?? userId,
            username: data["username"] as? String ?? "User",
            bio: data["bio"] as? String ?? "No bio yet",
            location: data["location"] as? String ?? "",
            hasProfileImage: data["hasProfileImage"] as? Bool ?? false,
            profileImageBase64: profileImageBase64,
            lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date(),
            isPublic: data["isPublic"] as? Bool ?? true,
            watchedShows: watchedShows
        )
    }
    
    // Get profile image (from cache or decode from base64)
    func getProfileImage(userId: String) async throws -> UIImage? {
        // First check cache safely
        if let cachedImage = getCachedImage(userId) {
            print("Using cached profile image for user \(userId)")
            return cachedImage
        }
        
        // If not in cache, try to get from Firestore
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
    
    // Clear cache for testing
    func clearCache() {
        clearImageCache()
    }
    
    // Add a show to the watched list
    func addWatchedShow(userId: String, show: WatchedShow) async throws {
        // Validate show data
        let validShow = WatchedShow(
            id: show.id,
            title: show.title.isEmpty ? "Unknown Show" : show.title,
            imageName: show.imageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            dateWatched: show.dateWatched,
            rating: show.rating
        )
        
        // Get the current profile
        let profile = try await getProfile(userId: userId)
        
        // Remove existing show with the same ID if present
        var updatedWatchedShows = profile.watchedShows.filter { $0.id != validShow.id }
        
        // Add the new show
        updatedWatchedShows.append(validShow)
        
        // Prepare safe data for Firestore
        let watchedShowsData = updatedWatchedShows.map { show in
            return [
                "id": show.id,
                "title": show.title,
                "imageName": show.imageName ?? "",
                "dateWatched": Timestamp(date: show.dateWatched),
                "rating": show.rating ?? 0
            ]
        }
        
        // Update the watched shows in Firestore
        try await profileCollection.document(userId).updateData([
            "watchedShows": watchedShowsData
        ])
    }
    
    // Update the watched shows list for a user
    func updateWatchedShows(userId: String, watchedShows: [WatchedShow]) async throws {
        // Prepare safe data for Firestore
        let watchedShowsData = watchedShows.map { show in
            return [
                "id": show.id,
                "title": show.title,
                "imageName": show.imageName ?? "",
                "dateWatched": Timestamp(date: show.dateWatched),
                "rating": show.rating ?? 0
            ]
        }
        
        // Update the watched shows in Firestore
        try await profileCollection.document(userId).updateData([
            "watchedShows": watchedShowsData
        ])
    }
    
    // Remove a show from the watched list
    func removeWatchedShow(userId: String, showId: String) async throws {
        // Get the current profile
        let profile = try await getProfile(userId: userId)
        
        // Filter out the show with the given ID
        let updatedWatchedShows = profile.watchedShows.filter { $0.id != showId }
        
        // Prepare safe data for Firestore
        let watchedShowsData = updatedWatchedShows.map { show in
            return [
                "id": show.id,
                "title": show.title,
                "imageName": show.imageName ?? "",
                "dateWatched": Timestamp(date: show.dateWatched),
                "rating": show.rating ?? 0
            ]
        }
        
        // Update the watched shows in Firestore
        try await profileCollection.document(userId).updateData([
            "watchedShows": watchedShowsData
        ])
    }
}

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var username: String = "tubeheadsfan1"
    @State private var bio: String = "i love television."
    @State private var location: String = "California, US"
    @State private var followersCount: Int = 90
    @State private var followingCount: Int = 103
    @State private var showSignInView: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var profileImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var isImageLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isPublic: Bool = true
    @State private var watchedShows: [WatchedShow] = []
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase
    @State private var userLists: [(id: String, name: String, description: String, isPrivate: Bool, userId: String, showIds: [String])] = []
    @State private var isLoadingLists = false
    
    var body: some View {
        Group {
            if authManager.isSignedIn {
                // User is signed in - show profile
                profileContent
            } else {
                // User is not signed in - show sign in prompt
                VStack(spacing: 20) {
                    Text("Sign in to view your profile")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Button {
                        showSignInView = true
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .fullScreenCover(isPresented: $showSignInView) {
                    NavigationView {
                        AuthenticationView(showSignInView: $showSignInView)
                    }
                }
            }
        }
        .onAppear {
            loadUserProfile()
            loadUserLists()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Reload profile when app becomes active
                loadUserProfile()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            // Reload profile after editing
            loadUserProfile()
        } content: {
            NavigationView {
                EditProfileView(
                    username: username,
                    bio: bio,
                    location: location,
                    isPublic: isPublic, 
                    profileImage: profileImage,
                    onSave: { newBio, newLocation, newImage, newIsPublic in
                        saveUserProfile(bio: newBio, location: newLocation, image: newImage, isPublic: newIsPublic)
                    }
                )
            }
        }
    }
    
    var profileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header with back button and title
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Edit profile button
                    Button(action: {
                        showEditProfile = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Username with lock icon
                HStack {
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Show appropriate icon based on privacy status
                    Image(systemName: isPublic ? "lock.open.fill" : "lock.fill")
                        .font(.caption)
                        .foregroundColor(isPublic ? .green : .red)
                }
                .padding(.horizontal)
                
                // Profile image, bio and location
                VStack(alignment: .center, spacing: 8) {
                    if isLoading || isImageLoading {
                        ProgressView()
                            .frame(width: 100, height: 100)
                    } else if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .shadow(radius: 1)
                    } else {
                        UserProfileImageView(size: 100)
                    }
                    
                    Text(bio)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                }
                
                // Followers and Following
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("\(followersCount)")
                            .font(.headline)
                        Text("Followers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("\(followingCount)")
                            .font(.headline)
                        Text("Following")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                    .padding(.horizontal)
                
                // Watched Shows section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Watched Shows")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            // View all watched shows
                        }) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    if watchedShows.isEmpty {
                        Text("No watched shows yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        // Only show up to 3 items in the preview
                        let previewShows = Array(watchedShows.prefix(3))
                        
                        VStack(spacing: 10) {
                            ForEach(previewShows) { show in
                                WatchedShowRow(show: show)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Public Lists section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Public Lists")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        NavigationLink(destination: UserListsView()) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isLoadingLists {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if userLists.isEmpty {
                        Text("No public lists yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        // Only show up to 3 items in the preview
                        let previewLists = Array(userLists.prefix(3))
                        
                        VStack(spacing: 10) {
                            ForEach(previewLists, id: \.id) { list in
                                NavigationLink(destination: UserListsView()) {
                                    PublicListRow(
                                        listId: list.id,
                                        name: list.name, 
                                        description: list.description,
                                        showCount: list.showIds.count,
                                        showIds: list.showIds
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                Spacer()
            }
            .padding(.top)
        }
        .navigationBarHidden(true)
    }
    
    private func loadUserProfile() {
        guard let userId = authManager.currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get username from AuthManager
                if let username = await authManager.getCurrentUsername() {
                    self.username = username
                }
                
                // Get user profile data
                let profile = try await ProfileManager.shared.getProfile(userId: userId)
                
                // Load profile image in parallel with updating the UI
                if profile.hasProfileImage {
                    isImageLoading = true
                    
                    // Use a separate task for image loading to not block UI updates
                    Task {
                        do {
                            let image = try await ProfileManager.shared.getProfileImage(userId: userId)
                            
                            await MainActor.run {
                                self.profileImage = image
                                self.isImageLoading = false
                            }
                        } catch {
                            print("Failed to load profile image: \(error.localizedDescription)")
                            await MainActor.run {
                                self.isImageLoading = false
                            }
                        }
                    }
                }
                
                // Update UI with profile data
                await MainActor.run {
                    self.bio = profile.bio
                    self.location = profile.location
                    self.isPublic = profile.isPublic
                    self.watchedShows = profile.watchedShows
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    self.isLoading = false
                    self.isImageLoading = false
                }
            }
        }
    }
    
    private func saveUserProfile(bio: String, location: String, image: UIImage?, isPublic: Bool) {
        guard let userId = authManager.currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // First update the local state to provide immediate feedback
                await MainActor.run {
                    self.bio = bio
                    self.location = location
                    self.isPublic = isPublic
                    if let img = image {
                        self.profileImage = img
                    }
                }
                
                // Then save to the backend
                try await ProfileManager.shared.saveProfile(
                    userId: userId,
                    username: username,
                    bio: bio,
                    location: location,
                    profileImage: image,
                    isPublic: isPublic
                )
                
                await MainActor.run {
                    self.errorMessage = nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    self.isLoading = false
                    
                    // If the error is about image size, suggest what to do
                    if error.localizedDescription.contains("Image too large") {
                        self.errorMessage = "Image too large. Please choose a smaller photo."
                    }
                }
            }
        }
    }
    
    private func loadUserLists() {
        guard let userId = authManager.currentUser?.uid else { 
            print("📋 Lists: No user ID available")
            return 
        }
        
        print("📋 Lists: Loading lists for user \(userId)")
        isLoadingLists = true
        
        Task {
            do {
                // Get all user lists first (simpler query)
                print("📋 Lists: Querying Firestore for all lists")
                let allListsSnapshot = try await Firestore.firestore().collection("lists")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "dateCreated", descending: true) // Sort by creation date
                    .getDocuments()
                
                print("📋 Lists: Found \(allListsSnapshot.documents.count) total lists")
                
                // Filter for public lists client-side to avoid compound query issues
                let publicListDocuments = allListsSnapshot.documents.filter { document in
                    if let isPrivate = document.data()["isPrivate"] as? Bool {
                        return !isPrivate // Keep only public lists
                    }
                    return false // If can't determine, exclude
                }
                
                print("📋 Lists: Found \(publicListDocuments.count) public lists after filtering")
                
                let lists = publicListDocuments.compactMap { document -> (id: String, name: String, description: String, isPrivate: Bool, userId: String, showIds: [String])? in
                    guard let data = document.data() as? [String: Any],
                          let name = data["name"] as? String else {
                        print("📋 Lists: Error parsing document \(document.documentID) - missing required fields")
                        return nil
                    }
                    
                    // Use defaults for optional fields to be more resilient
                    let description = data["description"] as? String ?? "No description"
                    let listUserId = data["userId"] as? String ?? userId
                    let isPrivate = data["isPrivate"] as? Bool ?? false
                    let showIds = data["showIds"] as? [String] ?? []
                    
                    print("📋 Lists: Parsed list: \(name), isPrivate: \(isPrivate), showIds: \(showIds.count)")
                    
                    return (
                        id: document.documentID,
                        name: name,
                        description: description,
                        isPrivate: isPrivate,
                        userId: listUserId,
                        showIds: showIds
                    )
                }
                
                await MainActor.run {
                    print("📋 Lists: Final count: \(lists.count) public lists")
                    userLists = lists
                    isLoadingLists = false
                }
            } catch {
                print("📋 Lists: Error loading user lists: \(error)")
                await MainActor.run {
                    isLoadingLists = false
                }
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State var username: String
    @State var bio: String
    @State var location: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhoto: UIImage?
    @State private var isSaving = false
    @State private var showCountryPicker = false
    @State private var showSizeWarning = false
    @State private var showLocationPermission = false
    @State var isPublic: Bool
    @FocusState private var isLocationFocused: Bool
    @StateObject private var locationManager = LocationManager.shared
    
    // Initial profile image passed from ProfileView
    let profileImage: UIImage?
    
    // List of countries
    let countries = [
        "United States", "Canada", "United Kingdom", "Australia", "Germany", 
        "France", "Japan", "Brazil", "India", "Mexico", "Spain", "Italy", 
        "South Korea", "Netherlands", "Sweden", "Norway", "Denmark", "Finland", 
        "Ireland", "New Zealand", "Singapore", "China", "Russia", "Argentina", 
        "Chile", "Colombia", "Peru", "South Africa", "Nigeria", "Egypt", 
        "Israel", "Turkey", "United Arab Emirates", "Saudi Arabia", "Thailand", 
        "Malaysia", "Indonesia", "Philippines", "Vietnam"
    ].sorted()
    
    var onSave: (String, String, UIImage?, Bool) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {
                // Profile image picker
                VStack {
                    if let photo = selectedPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    } else if let existingImage = profileImage {
                        Image(uiImage: existingImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    } else {
                        UserProfileImageView(size: 120)
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Change Photo")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    
                    if showSizeWarning {
                        Text("Please choose a smaller image")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical)
                
                // Form fields
                VStack(spacing: 20) {
                    // Username (disabled - can't be changed)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Username", text: $username)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .disabled(true)
                            .foregroundColor(.gray)
                    }
                    
                    // Bio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $bio)
                            .padding(4)
                            .frame(height: 100)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button(action: {
                                showCountryPicker = true
                            }) {
                                HStack {
                                    Text(location.isEmpty ? "Select your location" : location)
                                        .foregroundColor(location.isEmpty ? .gray : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                // Show location permission dialog
                                if locationManager.authorizationStatus == .notDetermined {
                                    showLocationPermission = true
                                } else if locationManager.authorizationStatus == .authorizedWhenInUse || 
                                          locationManager.authorizationStatus == .authorizedAlways {
                                    // Already authorized, request location
                                    locationManager.requestLocation()
                                } else {
                                    // Denied, show system settings prompt
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Privacy toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Privacy")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $isPublic) {
                                HStack {
                                    Image(systemName: isPublic ? "lock.open.fill" : "lock.fill")
                                        .foregroundColor(isPublic ? .green : .red)
                                    
                                    Text(isPublic ? "Public Profile" : "Private Profile")
                                        .font(.subheadline)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            Text(isPublic ? "Anyone can view your profile" : "Only followers can view your profile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(isSaving)
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Check image size before setting it
                    let imageData = uiImage.jpegData(compressionQuality: 0.3) ?? Data()
                    let base64Size = imageData.base64EncodedString().utf8.count
                    
                    if base64Size > 900000 {
                        // Image is too large even with compression
                        showSizeWarning = true
                        
                        // Still set the image, but it will be resized before saving
                        selectedPhoto = uiImage
                    } else {
                        showSizeWarning = false
                        selectedPhoto = uiImage
                    }
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            NavigationView {
                List {
                    ForEach(countries, id: \.self) { country in
                        Button(action: {
                            location = country
                            showCountryPicker = false
                        }) {
                            HStack {
                                Text(country)
                                
                                Spacer()
                                
                                if location == country {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .navigationTitle("Select Country")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showCountryPicker = false
                        }
                    }
                }
            }
        }
        .onAppear {
            // Setup location manager
            if locationManager.location == nil && 
               (locationManager.authorizationStatus == .authorizedWhenInUse || 
                locationManager.authorizationStatus == .authorizedAlways) {
                locationManager.requestLocation()
            }
        }
        .onChange(of: locationManager.placemark) { newPlacemark in
            if let locationString = locationManager.getLocationString() {
                location = locationString
            }
        }
        .overlay {
            if showLocationPermission {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showLocationPermission = false
                        }
                    
                    LocationPermissionView(
                        showPermissionView: $showLocationPermission,
                        onAllow: {
                            locationManager.requestLocationPermission()
                        }
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                }
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Save the profile via the callback
        onSave(bio, location, selectedPhoto ?? profileImage, isPublic)
        
        isSaving = false
        dismiss()
    }
}

// Supporting Views

// Watched Shows List Component - Changed to vertical list
struct WatchedShowsList: View {
    let shows: [WatchedShow]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(shows) { show in
                WatchedShowRow(show: show)
            }
        }
        .padding(.horizontal)
    }
}

// Individual Watched Show Row - Simplified from card to row
struct WatchedShowRow: View {
    let show: WatchedShow
    
    var body: some View {
        NavigationLink(destination: FirestoreShowDetailViewWrapper(showId: show.id, showTitle: show.title)) {
            HStack(spacing: 12) {
                // Show thumbnail 
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 45, height: 68)
                    
                    if let imageName = show.imageName, !imageName.isEmpty, imageName != " " {
                        AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(imageName)")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 45, height: 68)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 45, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            case .failure:
                                Image(systemName: "tv")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "tv")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Show title
                    Text(show.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // Show watched date
                    Text("Watched on \(formattedDate(show.dateWatched))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Rating if available
                    if let rating = show.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.5))
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// Wrapper to navigate to FirestoreShowDetailView from a watched show
struct FirestoreShowDetailViewWrapper: View {
    let showId: String
    let showTitle: String
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Failed to load show details")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // Navigate to FirestoreShowDetailView passing showId
                // Since we can't directly instantiate FirestoreShow here,
                // we'll use a different approach
                NavigationLink(destination: FirestoreShowDetailViewNavigator(showId: showId)) {
                    EmptyView()
                }
                .opacity(0)
                .frame(width: 0, height: 0)
                
                // Show placeholder content while navigation happens
                VStack {
                    Text("Loading \(showTitle)...")
                    ProgressView()
                }
            }
        }
        .navigationTitle(showTitle)
        .task {
            // Simplify to just check if show exists
            await checkShowExists()
        }
    }
    
    private func checkShowExists() async {
        isLoading = true
        
        do {
            // Check if document exists in Firestore
            let document = try await Firestore.firestore().collection("shows").document(showId).getDocument()
            
            await MainActor.run {
                if document.exists {
                    // Show exists, we can navigate
                    errorMessage = nil
                } else {
                    // Show doesn't exist
                    errorMessage = "Show with ID \(showId) not found"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// Simple navigator view that can be used to pass just the ID to FirestoreShowDetailView
struct FirestoreShowDetailViewNavigator: View {
    let showId: String
    
    var body: some View {
        Text("Redirecting to show details...")
            .onAppear {
                // In a real implementation, you'd navigate directly to the show detail view
                // For our simplified version, we're just showing a placeholder
            }
    }
}

// Watch Button Component for Show Detail Pages
struct WatchButton: View {
    @State private var isWatched: Bool = false
    @State private var showRatingView: Bool = false
    @State private var rating: Int = 0
    
    let showId: String
    let showTitle: String
    let showImage: String?
    let userId: String?
    
    var body: some View {
        VStack {
            Button(action: {
                if isWatched {
                    // If already watched, show rating option
                    showRatingView = true
                } else {
                    // Mark as watched
                    markAsWatched()
                }
            }) {
                HStack {
                    Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isWatched ? .green : .primary)
                    
                    Text(isWatched ? "Watched" : "Mark as Watched")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(isWatched ? Color.green.opacity(0.2) : Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if showRatingView {
                VStack(spacing: 8) {
                    Text("Rate this show:")
                        .font(.subheadline)
                    
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 24))
                                .foregroundColor(star <= rating ? .yellow : .gray)
                                .onTapGesture {
                                    rating = star
                                    saveRating()
                                }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .transition(.scale)
            }
        }
        .onAppear {
            checkIfWatched()
        }
    }
    
    private func checkIfWatched() {
        guard let userId = userId else { return }
        
        Task {
            do {
                let profile = try await ProfileManager.shared.getProfile(userId: userId)
                
                // Check if this show is in the watched list
                if let watchedShow = profile.watchedShows.first(where: { $0.id == showId }) {
                    await MainActor.run {
                        isWatched = true
                        rating = watchedShow.rating ?? 0
                    }
                }
            } catch {
                print("Error checking if show is watched: \(error.localizedDescription)")
            }
        }
    }
    
    private func markAsWatched() {
        guard let userId = userId, !showId.isEmpty else { return }
        
        let newWatchedShow = WatchedShow(
            id: showId,
            title: showTitle,
            imageName: showImage ?? "",
            dateWatched: Date(),
            rating: nil
        )
        
        Task {
            do {
                try await ProfileManager.shared.addWatchedShow(userId: userId, show: newWatchedShow)
                
                await MainActor.run {
                    isWatched = true
                    showRatingView = true
                }
            } catch {
                print("Error marking show as watched: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveRating() {
        guard let userId = userId, !showId.isEmpty else { return }
        
        let updatedShow = WatchedShow(
            id: showId,
            title: showTitle,
            imageName: showImage ?? "",
            dateWatched: Date(),
            rating: rating > 0 ? rating : nil
        )
        
        Task {
            do {
                try await ProfileManager.shared.addWatchedShow(userId: userId, show: updatedShow)
                
                await MainActor.run {
                    // Hide rating view after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            showRatingView = false
                        }
                    }
                }
            } catch {
                print("Error saving rating: \(error.localizedDescription)")
            }
        }
    }
}

struct PublicListRow: View {
    let listId: String
    let name: String
    let description: String
    let showCount: Int
    let showIds: [String]
    @State private var showPreviews: [(id: String, name: String, posterPath: String?)] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // List title and show count
            HStack {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(showCount) shows")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
            }
            
            // Description with more compact layout
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Show previews in a more compact layout
            HStack(spacing: 6) {
                if isLoading {
                    // Show only smaller loading placeholder
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 45, height: 68)
                            .cornerRadius(4)
                    }
                    Spacer()
                } else if !showPreviews.isEmpty {
                    // Show actual image previews
                    ForEach(showPreviews.prefix(3), id: \.id) { show in
                        if let posterPath = show.posterPath, !posterPath.isEmpty {
                            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 45, height: 68)
                                        .cornerRadius(4)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 45, height: 68)
                                        .clipped()
                                        .cornerRadius(4)
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 45, height: 68)
                                        .cornerRadius(4)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 45, height: 68)
                                .cornerRadius(4)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                )
                        }
                    }
                    
                    // If we have more shows than we're displaying, show a count badge
                    if showCount > 3 {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 45, height: 68)
                                .cornerRadius(4)
                            
                            Text("+\(showCount - 3)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                } else if showCount > 0 {
                    // We have shows but couldn't load previews
                    Text("Contains \(showCount) shows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .frame(height: 68)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            Task {
                await loadShowPreviews()
            }
        }
    }
    
    private func loadShowPreviews() async {
        isLoading = true
        
        // Only fetch previews if we have show IDs
        if showIds.isEmpty {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            // Only fetch the first few shows for the preview
            let previewShowIds = Array(showIds.prefix(3))
            var previewShows: [(id: String, name: String, posterPath: String?)] = []
            
            for showId in previewShowIds {
                do {
                    let showDoc = try await Firestore.firestore().collection("shows").document(showId).getDocument()
                    
                    if showDoc.exists, let data = showDoc.data() {
                        let show = (
                            id: showDoc.documentID,
                            name: data["name"] as? String ?? "Unknown Show",
                            posterPath: data["posterPath"] as? String
                        )
                        previewShows.append(show)
                    }
                } catch {
                    print("Error loading show \(showId): \(error)")
                    // Continue with next show
                }
            }
            
            await MainActor.run {
                showPreviews = previewShows
                isLoading = false
            }
        } catch {
            print("Error loading list previews: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
} 
