import SwiftUI
import FirebaseAuth
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

// Extended user profile model to include profile-specific fields
struct UserProfile: Codable {
    let userId: String
    var username: String
    var bio: String
    var location: String
    var hasProfileImage: Bool
    var profileImageBase64: String?
    var lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case userId
        case username
        case bio
        case location
        case hasProfileImage
        case profileImageBase64
        case lastUpdated
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
    
    // Add image cache
    private var imageCache: [String: UIImage] = [:]
    
    private init() { }
    
    // Save or update user profile data
    func saveProfile(userId: String, username: String, bio: String, location: String, profileImage: UIImage?) async throws {
        let hasProfileImage = profileImage != nil
        var profileData: [String: Any] = [
            "userId": userId,
            "username": username,
            "bio": bio,
            "location": location,
            "hasProfileImage": hasProfileImage,
            "lastUpdated": Timestamp(date: Date())
        ]
        
        // If there's a profile image, resize, compress, and convert to base64
        if let originalImage = profileImage {
            // Resize the image to max 250 points width
            guard let resizedImage = originalImage.resized(toWidth: 250, quality: 0.3) else {
                throw NSError(domain: "ProfileManagerError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"])
            }
            
            // Add to cache
            imageCache[userId] = resizedImage
            
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
                lastUpdated: Date()
            )
        }
        
        // Parse profile data
        guard let data = document.data() else {
            throw NSError(domain: "ProfileManagerError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Document data is nil"])
        }
        
        let profileImageBase64 = data["profileImageBase64"] as? String
        
        // If there's a base64 image, decode and cache it
        if let base64String = profileImageBase64, 
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            imageCache[userId] = image
        }
        
        return UserProfile(
            userId: data["userId"] as? String ?? userId,
            username: data["username"] as? String ?? "User",
            bio: data["bio"] as? String ?? "No bio yet",
            location: data["location"] as? String ?? "",
            hasProfileImage: data["hasProfileImage"] as? Bool ?? false,
            profileImageBase64: profileImageBase64,
            lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    // Get profile image (from cache or decode from base64)
    func getProfileImage(userId: String) async throws -> UIImage? {
        // First check cache
        if let cachedImage = imageCache[userId] {
            print("Using cached profile image for user \(userId)")
            return cachedImage
        }
        
        // If not in cache, try to get from Firestore
        let document = try await profileCollection.document(userId).getDocument()
        if let data = document.data(),
           let base64String = data["profileImageBase64"] as? String,
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            // Cache the image
            imageCache[userId] = image
            return image
        }
        
        return nil
    }
    
    // Clear cache for testing
    func clearCache() {
        imageCache.removeAll()
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
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase
    
    // Recent activity shows will be displayed in a horizontal scroll
    let recentShows: [ShowPreview] = [
        ShowPreview(imageName: "whiteLotus", title: "The White Lotus"),
        ShowPreview(imageName: "cassandra", title: "Cassandra"),
        ShowPreview(imageName: "severance", title: "Severance")
    ]
    
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
                    profileImage: profileImage,
                    onSave: { newBio, newLocation, newImage in
                        saveUserProfile(bio: newBio, location: newLocation, image: newImage)
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
                    
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        ProfileImage(size: 100)
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
                
                // Recent Activity section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            // More action
                        }) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Show thumbnails
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentShows) { show in
                                ShowThumbnail(show: show)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 130)
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
    
    private func saveUserProfile(bio: String, location: String, image: UIImage?) {
        guard let userId = authManager.currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // First update the local state to provide immediate feedback
                await MainActor.run {
                    self.bio = bio
                    self.location = location
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
                    profileImage: image
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
    @FocusState private var isLocationFocused: Bool
    
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
    
    var onSave: (String, String, UIImage?) -> Void
    
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
                        ProfileImage(size: 120)
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
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Save the profile via the callback
        onSave(bio, location, selectedPhoto ?? profileImage)
        
        isSaving = false
        dismiss()
    }
}

// Supporting Views
struct ProfileImage: View {
    let size: CGFloat
    
    var body: some View {
        // Fallback to a system image if profileImage doesn't exist
        if UIImage(named: "profileImage") != nil {
            Image("profileImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .shadow(radius: 1)
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .foregroundColor(.gray)
        }
    }
}

struct ShowPreview: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
}

struct ShowThumbnail: View {
    let show: ShowPreview
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 130)
                
                // Fallback to a placeholder if the image doesn't exist
                if UIImage(named: show.imageName) != nil {
                    Image(show.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "tv")
                            .font(.largeTitle)
                        Text(show.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: 100, height: 130)
                }
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
} 