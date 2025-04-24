import SwiftUI
import FirebaseFirestore

struct UserProfileView: View {
    let userId: String
    
    @State private var username: String = "User"
    @State private var bio: String = "No bio yet"
    @State private var location: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var isImageLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isPublic: Bool = true
    @State private var watchedShows: [WatchedShow] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
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
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Username with lock icon if profile is private
                HStack {
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !isPublic {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Profile section
                if !isPublic {
                    // Private profile message
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("This profile is private")
                            .font(.headline)
                        
                        Text("The user has set their profile to private mode.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    // Public profile content
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
                        
                        if !location.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Watched shows section (only shown if profile is public)
                    if !watchedShows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recently Watched")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(watchedShows.sorted(by: { $0.dateWatched > $1.dateWatched }).prefix(5)) { show in
                                WatchedShowRow(show: show)
                                    .padding(.horizontal)
                                
                                if show.id != watchedShows.sorted(by: { $0.dateWatched > $1.dateWatched }).prefix(5).last?.id {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    private func loadUserProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
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
                    self.username = profile.username
                    self.bio = profile.bio
                    self.location = profile.location
                    self.isPublic = profile.isPublic
                    self.watchedShows = profile.isPublic ? profile.watchedShows : []
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
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView(userId: "previewUserId")
    }
} 