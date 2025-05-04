import SwiftUI
import FirebaseFirestore

struct ReviewsView: View {
    let showId: String
    let showName: String
    var onReviewAdded: () -> Void = {}
    
    @State private var reviews: [ShowReview] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddReviewSheet = false
    @State private var userReview: ShowReview?
    @State private var showEditReviewSheet = false
    @State private var userExistingRating: Double? = nil
    
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                
                Spacer()
                
                if authManager.isSignedIn {
                    Button(action: {
                        showAddReviewSheet = true
                    }) {
                        if userReview != nil {
                            Label("Edit Review", systemImage: "pencil")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        } else {
                            HStack {
                                Label("Write a Review", systemImage: "square.and.pencil")
                                    .font(.subheadline)
                                if userExistingRating != nil {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .disabled(userReview != nil)
                }
            }
            
            if userReview == nil && authManager.isSignedIn {
                // All rating-related prompt text removed
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if reviews.isEmpty {
                Text("No reviews yet. Be the first to share your thoughts!")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(reviews) { review in
                    ReviewCard(
                        review: review,
                        isUserReview: authManager.currentUser?.uid == review.userId,
                        onLike: { likeReview(reviewId: review.id!) },
                        onEdit: {
                            userReview = review
                            showEditReviewSheet = true
                        },
                        onDelete: { deleteReview(reviewId: review.id!) }
                    )
                    .padding(.vertical, 4)
                    
                    if review.id != reviews.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAddReviewSheet) {
            AddReviewView(showId: showId, showName: showName) { newReview in
                Task {
                    await loadReviews()
                    onReviewAdded()
                }
            }
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showEditReviewSheet) {
            if let review = userReview {
                EditReviewView(review: review) {
                    Task {
                        await loadReviews()
                        onReviewAdded()
                    }
                }
                .environmentObject(authManager)
            }
        }
        .task {
            await loadReviews()
            await loadUserRating()
        }
    }
    
    private func loadReviews() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            reviews = try await FirestoreReviewService.shared.getReviewsForShow(showId: showId)
            
            // Check if the current user has already posted a review
            if let userId = authManager.currentUser?.uid {
                userReview = reviews.first(where: { $0.userId == userId })
            }
        } catch {
            errorMessage = "Failed to load reviews: \(error.localizedDescription)"
            print("Error loading reviews: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadUserRating() async {
        guard let userId = authManager.currentUser?.uid else { return }
        
        do {
            let show = try await FirestoreShowService.shared.getShow(id: showId)
            let existingRating = show.userRatings[userId]
            
            await MainActor.run {
                if let rating = existingRating {
                    userExistingRating = rating
                }
            }
        } catch {
            print("Error loading user rating: \(error)")
        }
    }
    
    private func likeReview(reviewId: String) {
        guard let userId = authManager.currentUser?.uid else { return }
        
        Task {
            do {
                try await FirestoreReviewService.shared.likeReview(reviewId: reviewId, userId: userId)
                await loadReviews()
            } catch {
                print("Error liking review: \(error)")
            }
        }
    }
    
    private func deleteReview(reviewId: String) {
        Task {
            do {
                try await FirestoreReviewService.shared.deleteReview(reviewId: reviewId)
                await loadReviews()
                onReviewAdded()
            } catch {
                print("Error deleting review: \(error)")
            }
        }
    }
}

// Simple placeholder for profile images to avoid dependency issues
struct ReviewProfileImage: View {
    let userId: String?
    let base64ImageString: String?
    let size: CGFloat
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Try to load from base64 string first
        if let base64 = base64ImageString,
           !base64.isEmpty,
           let imageData = Data(base64Encoded: base64),
           let uiImage = UIImage(data: imageData) {
            self.image = uiImage
            return
        }
        
        // Otherwise, try to load from cache or Firestore
        if let id = userId {
            Task {
                do {
                    if let cachedImage = try? await ProfileImageCache.shared.getProfileImage(userId: id) {
                        DispatchQueue.main.async {
                            self.image = cachedImage
                        }
                    }
                } catch {
                    print("Error loading image: \(error)")
                }
            }
        }
    }
}

struct ReviewCard: View {
    let review: ShowReview
    let isUserReview: Bool
    let onLike: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var authManager: AuthManager
    @State private var showUserProfile = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // User profile image with navigation to user profile
                Button(action: {
                    if !isUserReview {
                        showUserProfile = true
                    }
                }) {
                    ReviewProfileImage(
                        userId: review.userId,
                        base64ImageString: review.userProfileImageURL,
                        size: 40
                    )
                }
                .disabled(isUserReview)
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    // Username with navigation to user profile
                    Button(action: {
                        if !isUserReview {
                            showUserProfile = true
                        }
                    }) {
                        Text(review.username ?? "Anonymous")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .disabled(isUserReview)
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(review.formattedDate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Rating
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(String(format: "%.1f", review.rating))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if isUserReview {
                    Menu {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(8)
                    }
                }
            }
            
            // Review content
            Text(review.content)
                .font(.body)
                .padding(.vertical, 4)
            
            // Like button
            if authManager.isSignedIn {
                HStack {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: review.userLikes.contains(authManager.currentUser?.uid ?? "") ? "heart.fill" : "heart")
                                .foregroundColor(review.userLikes.contains(authManager.currentUser?.uid ?? "") ? .red : .gray)
                            
                            if review.likes > 0 {
                                Text("\(review.likes)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer()
                }
                .padding(.top, 4)
            } else if review.likes > 0 {
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.gray)
                    
                    Text("\(review.likes)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView(userId: review.userId)
                    .environmentObject(authManager)
            }
        }
    }
}

struct AddReviewView: View {
    let showId: String
    let showName: String
    let onSubmit: (ShowReview) -> Void
    @State private var userExistingRating: Double?
    
    @State private var reviewText = ""
    @State private var rating: Double = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rating")) {
                    HStack {
                        Text("How would you rate \(showName)?")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                let ratingValue = userExistingRating ?? rating
                                Image(systemName: star <= Int(ratingValue) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .onTapGesture {
                                        if userExistingRating == nil {
                                            if Double(star) == rating {
                                                rating = 0
                                            } else {
                                                rating = Double(star)
                                            }
                                        }
                                    }
                            }
                        }
                        .opacity(userExistingRating != nil ? 0.7 : 1.0)
                    }
                }
                
                Section(header: Text("Written Review")) {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if reviewText.isEmpty {
                                    HStack {
                                        Text("Write your review here...")
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 4)
                                        Spacer()
                                    }
                                    .allowsHitTesting(false)
                                }
                            }
                        )
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: {
                    submitReview()
                }) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit Review")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.top)
                .disabled(isSubmitting || reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (rating == 0 && userExistingRating == nil))
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadUserRating()
        }
    }
    
    private func submitReview() {
        guard let userId = authManager.currentUser?.uid, !reviewText.isEmpty else {
            return
        }
        
        // Use the existing rating if present or the selected rating
        let finalRating = userExistingRating ?? rating
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                let reviewId = try await FirestoreReviewService.shared.addReview(
                    userId: userId,
                    showId: showId,
                    content: reviewText,
                    rating: finalRating
                )
                
                // Get the created review
                let reviewSnapshot = try await Firestore.firestore().collection("reviews").document(reviewId).getDocument()
                if let review = try? reviewSnapshot.data(as: ShowReview.self) {
                    await MainActor.run {
                        onSubmit(review)
                        dismiss()
                    }
                } else {
                    throw NSError(domain: "ReviewError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created review"])
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
    
    private func loadUserRating() async {
        guard let userId = authManager.currentUser?.uid else { return }
        
        do {
            let show = try await FirestoreShowService.shared.getShow(id: showId)
            let existingRating = show.userRatings[userId]
            
            await MainActor.run {
                if let rating = existingRating {
                    userExistingRating = rating
                }
            }
        } catch {
            print("Error loading user rating: \(error)")
        }
    }
}

struct EditReviewView: View {
    let review: ShowReview
    let onSubmit: () -> Void
    
    @State private var reviewText: String
    @State private var rating: Double
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    init(review: ShowReview, onSubmit: @escaping () -> Void) {
        self.review = review
        self.onSubmit = onSubmit
        _reviewText = State(initialValue: review.content)
        _rating = State(initialValue: review.rating)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rating")) {
                    HStack {
                        Text("Your Rating")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .onTapGesture {
                                        // If tapping the same star that's already selected, clear the rating
                                        if Double(star) == rating {
                                            rating = 0
                                        } else {
                                            rating = Double(star)
                                        }
                                    }
                            }
                        }
                    }
                    
                    Text("Changing your rating will update the show's overall rating.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                Section(header: Text("Review")) {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 150)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: updateReview) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Review")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(reviewText.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Edit Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateReview() {
        guard let reviewId = review.id, !reviewText.isEmpty else {
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await FirestoreReviewService.shared.editReview(
                    reviewId: reviewId,
                    content: reviewText,
                    rating: rating
                )
                
                await MainActor.run {
                    onSubmit()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
} 