import SwiftUI
import FirebaseFirestore
import Firebase
import FirebaseFirestoreSwift
import Foundation

struct UserReviewsView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var reviews: [ShowReview] = []
    @State private var showDetails: [String: FirestoreShow] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                                .padding()
                            
                            if authManager.isSignedIn {
                                Text("You haven't written any reviews yet.")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                
                                Text("Browse shows and share your thoughts to see them here.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            } else {
                                Text("Sign in to see your reviews")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    // Navigate to sign in view
                                }) {
                                    Text("Sign In")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(minHeight: 400)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(reviews) { review in
                                SimpleReviewCard(
                                    review: review,
                                    show: showDetails[review.showId]
                                )
                                
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("My Reviews")
            .task {
                print("📱 UserReviewsView is loading user reviews")
                await loadUserReviews()
            }
            .refreshable {
                print("📱 UserReviewsView is refreshing user reviews")
                await loadUserReviews()
            }
            .onAppear {
                print("📱 UserReviewsView appeared")
            }
        }
    }
    
    private func loadUserReviews() async {
        guard let userId = authManager.currentUser?.uid else {
            print("📱 UserReviewsView: No user signed in")
            errorMessage = "Please sign in to view your reviews"
            return
        }
        
        print("📱 UserReviewsView: Loading reviews for user \(userId)")
        isLoading = true
        errorMessage = nil
        
        do {
            print("📱 UserReviewsView: Calling getReviewsByUser")
            reviews = try await FirestoreReviewService.shared.getReviewsByUser(userId: userId)
            print("📱 UserReviewsView: Found \(reviews.count) reviews")
            
            // Load show details for each review
            for review in reviews {
                if showDetails[review.showId] == nil {
                    print("📱 UserReviewsView: Loading details for show \(review.showId)")
                    if let show = try? await FirestoreShowService.shared.getShow(id: review.showId) {
                        print("📱 UserReviewsView: Loaded show details for \(show.name)")
                        await MainActor.run {
                            showDetails[review.showId] = show
                        }
                    }
                }
            }
        } catch {
            print("📱 UserReviewsView ERROR: \(error.localizedDescription)")
            errorMessage = "Failed to load reviews: \(error.localizedDescription)"
            print("Error loading user reviews: \(error)")
        }
        
        isLoading = false
    }
    
    private func deleteReview(reviewId: String) {
        Task {
            do {
                try await FirestoreReviewService.shared.deleteReview(reviewId: reviewId)
                await loadUserReviews()
            } catch {
                print("Error deleting review: \(error)")
            }
        }
    }
}

struct SimpleReviewCard: View {
    let review: ShowReview
    let show: FirestoreShow?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Show title
                if let show = show {
                    Text(show.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("Unknown Show")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Rating
                HStack {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= Int(review.rating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
            }
            
            // Review content
            Text(review.content)
                .font(.body)
                .lineLimit(3)
            
            // Review date
            Text(review.formattedDate)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    UserReviewsView()
        .environmentObject(AuthManager())
} 