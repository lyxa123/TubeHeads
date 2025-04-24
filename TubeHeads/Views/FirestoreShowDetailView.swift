import SwiftUI
import FirebaseFirestore

struct FirestoreShowDetailView: View {
    @State private var firestoreShow: FirestoreShow
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isInWatchlist = false
    @State private var isAddingToWatchlist = false
    @State private var showAddToListSheet = false
    @State private var userLists: [ShowList] = []
    @State private var isLoadingLists = false
    @State private var isWatched: Bool = false
    @State private var isMarkingWatched: Bool = false
    @State private var showRateSheet = false
    @State private var userRating: Double? = nil
    
    @EnvironmentObject private var authManager: AuthManager
    
    init(firestoreShow: FirestoreShow) {
        _firestoreShow = State(initialValue: firestoreShow)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header image (backdrop)
                if let backdropURL = firestoreShow.backdropURL {
                    AsyncImage(url: backdropURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(firestoreShow.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Release year
                    Text(firestoreShow.releaseYear)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Action buttons row
                    HStack(spacing: 15) {
                        // Watchlist button
                        if authManager.isSignedIn {
                            Button(action: {
                                toggleWatchlist()
                            }) {
                                VStack {
                                    Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 22))
                                    Text("Watchlist")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isAddingToWatchlist)
                        } else {
                            Button(action: {
                                // Sign in prompt
                            }) {
                                VStack {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 22))
                                    Text("Watchlist")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                            }
                        }
                        
                        // Watched button
                        if authManager.isSignedIn {
                            Button(action: {
                                if let showId = firestoreShow.id, let userId = authManager.currentUser?.uid {
                                    Task {
                                        await toggleWatchedStatus(showId: showId, userId: userId)
                                    }
                                }
                            }) {
                                VStack {
                                    if isMarkingWatched {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .font(.system(size: 22))
                                    } else {
                                        Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(isWatched ? .green : nil)
                                    }
                                    Text("Watched")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isMarkingWatched)
                        } else {
                            Button(action: {
                                // Sign in prompt
                            }) {
                                VStack {
                                    Image(systemName: "circle")
                                        .font(.system(size: 22))
                                    Text("Watched")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                            }
                        }
                        
                        // Add to list button
                        if authManager.isSignedIn {
                            Button(action: {
                                showAddToListSheet = true
                                Task {
                                    await loadUserLists()
                                }
                            }) {
                                VStack {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 22))
                                    Text("Add to List")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            Button(action: {
                                // Sign in prompt
                            }) {
                                VStack {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 22))
                                    Text("Add to List")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                            }
                        }
                        
                        // Rate button
                        if authManager.isSignedIn {
                            Button(action: {
                                showRateSheet = true
                            }) {
                                VStack {
                                    Image(systemName: "star")
                                        .font(.system(size: 22))
                                    Text("Rate")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .onChange(of: showRateSheet) { isPresented in
                                if !isPresented {
                                    // Refresh after dismissing the sheet
                                    Task {
                                        await refreshShowData()
                                    }
                                }
                            }
                        } else {
                            Button(action: {
                                // Sign in prompt
                            }) {
                                VStack {
                                    Image(systemName: "star")
                                        .font(.system(size: 22))
                                    Text("Rate")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // User rating section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User Rating")
                            .font(.headline)
                        
                        HStack {
                            if firestoreShow.userRatings.isEmpty {
                                Text("No ratings yet")
                                    .foregroundColor(.gray)
                            } else {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", firestoreShow.averageUserRating))
                                    .fontWeight(.bold)
                                Text("(\(firestoreShow.userRatings.count) ratings)")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if let rating = userRating {
                            HStack {
                                Text("Your rating:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                            .padding(.top, 2)
                        }
                        
                        if !authManager.isSignedIn {
                            Text("Sign in to rate this show or write a review.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Overview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overview")
                            .font(.headline)
                        
                        Text(firestoreShow.overview)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    // Divider before reviews section
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Reviews section
                    if let showId = firestoreShow.id {
                        ReviewsView(
                            showId: showId, 
                            showName: firestoreShow.name,
                            onReviewAdded: {
                                Task {
                                    await refreshShowData()
                                }
                            }
                        )
                        .environmentObject(authManager)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddToListSheet) {
            AddToListView(
                show: firestoreShow,
                userLists: userLists,
                isLoading: isLoadingLists
            )
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showRateSheet) {
            RateShowView(
                show: firestoreShow, 
                userCurrentRating: userRating,
                onRatingSubmitted: { newRating in
                    // Update the UI without reloading
                    userRating = newRating
                }
            )
            .environmentObject(authManager)
        }
        .task {
            await loadShowDetails()
        }
    }
    
    private func loadShowDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // If the show doesn't have an ID, check if it exists in Firestore or save it
            if firestoreShow.id == nil {
                if let existingShow = try await FirestoreShowService.shared.getShowByTMDBId(tmdbId: firestoreShow.tmdbId) {
                    // Update our local reference with the existing Firestore show
                    await MainActor.run {
                        // Create a new FirestoreShow with all properties from the existing one
                        var updatedShow = existingShow
                        // Copy any properties that might be missing in the Firestore version
                        if updatedShow.posterPath == nil {
                            updatedShow.posterPath = firestoreShow.posterPath
                        }
                        if updatedShow.backdropPath == nil {
                            updatedShow.backdropPath = firestoreShow.backdropPath
                        }
                        firestoreShow = updatedShow
                    }
                } else {
                    // Save show to Firestore to get an ID
                    let showId = try await FirestoreShowService.shared.saveShow(from: TVShow(
                        id: firestoreShow.tmdbId,
                        name: firestoreShow.name,
                        overview: firestoreShow.overview,
                        posterPath: firestoreShow.posterPath,
                        backdropPath: firestoreShow.backdropPath,
                        voteAverage: 0.0, firstAirDate: firestoreShow.firstAirDate  // Default value since FirestoreShow doesn't have this field
                    ))
                    
                    // Get the full show with ID from Firestore
                    let savedShow = try await FirestoreShowService.shared.getShow(id: showId)
                    await MainActor.run {
                        firestoreShow = savedShow
                    }
                }
            }
            
            await refreshShowData()
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading show details: \(error)")
        }
        
        isLoading = false
    }
    
    private func refreshShowData() async {
        // Now that we have a valid Firestore show with ID, continue with other operations
        if let userId = authManager.currentUser?.uid {
            // Check if show is in user's watchlist
            if let showId = firestoreShow.id {
                do {
                    // Load fresh show data to get updated ratings
                    let updatedShow = try await FirestoreShowService.shared.getShow(id: showId)
                    
                    // Update the show data
                    await MainActor.run {
                        firestoreShow = updatedShow
                    }
                    
                    isInWatchlist = try await WatchlistService.shared.isInWatchlist(userId: userId, showId: showId)
                    
                    // Check if show is in user's watched list
                    let profile = try await ProfileManager.shared.getProfile(userId: userId)
                    isWatched = profile.watchedShows.contains(where: { $0.id == showId })
                    
                    // Get user's rating if available
                    userRating = getUserRating(userId: userId)
                } catch {
                    print("Error refreshing show data: \(error)")
                }
            }
        }
    }
    
    private func getUserRating(userId: String) -> Double? {
        return firestoreShow.userRatings[userId]
    }
    
    private func loadUserLists() async {
        guard let userId = authManager.currentUser?.uid else {
            return
        }
        
        isLoadingLists = true
        
        do {
            userLists = try await ListService.shared.getUserLists(userId: userId)
        } catch {
            print("Error loading user lists: \(error)")
        }
        
        isLoadingLists = false
    }
    
    private func toggleWatchlist() {
        guard let showId = firestoreShow.id,
              let userId = authManager.currentUser?.uid else {
            return
        }
        
        isAddingToWatchlist = true
        
        Task {
            do {
                if isInWatchlist {
                    try await WatchlistService.shared.removeFromWatchlist(userId: userId, showId: showId)
                    isInWatchlist = false
                } else {
                    try await WatchlistService.shared.addToWatchlist(userId: userId, showId: showId)
                    isInWatchlist = true
                }
            } catch {
                print("Error toggling watchlist: \(error)")
            }
            
            isAddingToWatchlist = false
        }
    }
    
    private func toggleWatchedStatus(showId: String, userId: String) async {
        // Immediate UI feedback
        isMarkingWatched = true
        
        Task {
            do {
                if isWatched {
                    // Remove from watched shows
                    let profile = try await ProfileManager.shared.getProfile(userId: userId)
                    var updatedWatchedShows = profile.watchedShows.filter { $0.id != showId }
                    
                    try await ProfileManager.shared.updateWatchedShows(userId: userId, watchedShows: updatedWatchedShows)
                    await MainActor.run {
                        isWatched = false
                    }
                } else {
                    // Add to watched shows
                    let watchedShow = WatchedShow(
                        id: showId,
                        title: firestoreShow.name,
                        imageName: firestoreShow.posterPath ?? "",
                        dateWatched: Date(),
                        rating: nil
                    )
                    
                    try await ProfileManager.shared.addWatchedShow(userId: userId, show: watchedShow)
                    await MainActor.run {
                        isWatched = true
                        // Show rating sheet directly
                        showRateSheet = true
                    }
                }
            } catch {
                print("Error toggling watched status: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isMarkingWatched = false
            }
        }
    }
}

struct AddToListView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authManager: AuthManager
    let show: FirestoreShow
    let userLists: [ShowList]
    @State private var isLoading: Bool
    
    @State private var selectedListIds: Set<String> = []
    @State private var showCreateListSheet = false
    @State private var isSaving = false
    @State private var currentListStatuses: [String: Bool] = [:]
    @State private var statusMessage: String?
    @State private var showStatusMessage = false
    @State private var errorOccurred = false
    @State private var refreshTrigger = false  // To force refresh after creating a new list
    @State private var newUserLists: [ShowList] = []
    
    init(show: FirestoreShow, userLists: [ShowList], isLoading: Bool) {
        self.show = show
        self.userLists = userLists
        self._isLoading = State(initialValue: isLoading)
    }
    
    var listsToDisplay: [ShowList] {
        refreshTrigger ? newUserLists : userLists
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Loading your lists...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if listsToDisplay.isEmpty {
                        emptyListsView
                    } else {
                        listContentView
                        
                        // Status message
                        if showStatusMessage, let message = statusMessage {
                            Text(message)
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(errorOccurred ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                .foregroundColor(errorOccurred ? .red : .green)
                                .cornerRadius(8)
                                .padding(.bottom)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.bottom, showStatusMessage ? 8 : 0)
            }
            .navigationTitle("Add to List")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .task {
                // Set loading state immediately
                isLoading = true
                
                // Ensure fresh data every time the view appears
                do {
                    await loadListStatuses()
                } catch {
                    print("Error loading list statuses: \(error)")
                }
                
                // Update loading state when done
                isLoading = false
            }
            .sheet(isPresented: $showCreateListSheet) {
                CreateListView(onListCreated: { newList in
                    Task {
                        do {
                            // Update the lists after creating a new one
                            await loadListsAfterCreation()
                            
                            // Try to add the show to the newly created list if we have a valid show ID
                            if let showId = show.id, let listId = newList.id {
                                try await ListService.shared.addShowToList(listId: listId, showId: showId)
                                await MainActor.run {
                                    currentListStatuses[listId] = true
                                    selectedListIds.insert(listId)
                                    showTemporaryMessage("Added to \(newList.name)", isError: false)
                                }
                            }
                        } catch {
                            print("Error adding show to new list: \(error)")
                        }
                        
                        showCreateListSheet = false
                    }
                })
                .environmentObject(authManager)
            }
        }
    }
    
    private var emptyListsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("You don't have any lists yet")
                .font(.headline)
            
            Text("Create your first list to add shows to it")
                .foregroundColor(.gray)
            
            Button(action: {
                showCreateListSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New List")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var listContentView: some View {
        VStack(spacing: 0) {
            // Lists section header
            HStack {
                Text("Your Lists")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !selectedListIds.isEmpty {
                    Text("\(selectedListIds.count) selected")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Lists
            List {
                ForEach(listsToDisplay) { list in
                    let isInList = currentListStatuses[list.id ?? ""] == true
                    
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(list.name)
                                    .font(.headline)
                                
                                if isInList {
                                    Text("Added")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(list.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if isSaving && selectedListIds.contains(list.id ?? "") {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button(action: {
                                toggleList(list)
                            }) {
                                Image(systemName: isInList ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isInList ? .blue : .gray)
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleList(list)
                    }
                    .padding(.vertical, 4)
                    .background(isInList ? Color.blue.opacity(0.05) : Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listRowSeparator(.visible)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private func toggleList(_ list: ShowList) {
        guard let listId = list.id, let showId = show.id else { return }
        
        let isInList = currentListStatuses[listId] ?? false
        
        // Immediately update UI
        currentListStatuses[listId] = !isInList
        
        if isInList {
            selectedListIds.remove(listId)
        } else {
            selectedListIds.insert(listId)
        }
        
        // Set saving state
        isSaving = true
        
        Task {
            do {
                if isInList {
                    try await ListService.shared.removeShowFromList(listId: listId, showId: showId)
                    await MainActor.run {
                        showTemporaryMessage("Removed from \(list.name)", isError: false)
                    }
                } else {
                    try await ListService.shared.addShowToList(listId: listId, showId: showId)
                    await MainActor.run {
                        showTemporaryMessage("Added to \(list.name)", isError: false)
                    }
                }
            } catch {
                print("Error updating list: \(error)")
                // Revert the UI state on error
                await MainActor.run {
                    currentListStatuses[listId] = isInList
                    showTemporaryMessage("Failed to update list: \(error.localizedDescription)", isError: true)
                }
            }
            
            // Reset saving state
            await MainActor.run {
                isSaving = false
            }
        }
    }
    
    private func loadListStatuses() async {
        guard let showId = show.id else { 
            print("Cannot load list statuses: Show ID is nil")
            return 
        }
        
        print("🔍 Checking list statuses for show: \(showId)")
        
        // Clear existing statuses to start fresh
        currentListStatuses = [:]
        selectedListIds = []
        
        // First, get all user lists
        var listsToCheck = userLists
        
        if listsToCheck.isEmpty {
            print("No user lists available, trying to load them first")
            guard let userId = authManager.currentUser?.uid else {
                print("No authenticated user")
                return
            }
            
            do {
                listsToCheck = try await ListService.shared.getUserLists(userId: userId)
                // Update newUserLists for display
                newUserLists = listsToCheck
                refreshTrigger = true
            } catch {
                print("Error loading user lists: \(error)")
                return
            }
        }
        
        var listStatusCount = 0
        
        // Check each list to see if it contains the show
        for list in listsToCheck {
            guard let listId = list.id else { 
                print("List has no ID, skipping")
                continue 
            }
            
            do {
                let listObj = try await ListService.shared.getList(id: listId)
                let showExists = listObj.showIds.contains(showId)
                
                if showExists {
                    listStatusCount += 1
                }
                
                // Update UI state
                currentListStatuses[listId] = showExists
                
                // Sync with selectedListIds for consistency
                if showExists {
                    selectedListIds.insert(listId)
                } else {
                    selectedListIds.remove(listId)
                }
                
                print("Show \(showId) in list '\(list.name)' (\(listId)): \(showExists ? "✅ YES" : "❌ NO")")
            } catch {
                print("Error checking list status for '\(list.name)' (\(listId)): \(error)")
                // Default to not in list if there's an error
                currentListStatuses[listId] = false
            }
        }
        
        print("🔍 Found show in \(listStatusCount) of \(listsToCheck.count) lists")
    }
    
    private func loadListsAfterCreation() async {
        guard let userId = authManager.currentUser?.uid else { return }
        
        do {
            let lists = try await ListService.shared.getUserLists(userId: userId)
            await MainActor.run {
                newUserLists = lists
                refreshTrigger = true
                
                // Also need to update currentListStatuses for the new list
                if let showId = show.id {
                    for list in lists where currentListStatuses[list.id ?? ""] == nil {
                        currentListStatuses[list.id ?? ""] = false
                    }
                }
            }
        } catch {
            print("Error refreshing lists: \(error)")
        }
    }
    
    private func showTemporaryMessage(_ message: String, isError: Bool) {
        statusMessage = message
        errorOccurred = isError
        showStatusMessage = true
        
        // Hide message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showStatusMessage = false
            }
        }
    }
}

// Simple rating view for rating without review
struct RateShowView: View {
    let show: FirestoreShow
    let userCurrentRating: Double?
    let onRatingSubmitted: (Double) -> Void
    
    @State private var rating: Double
    @State private var isSubmitting = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    init(show: FirestoreShow, userCurrentRating: Double? = nil, onRatingSubmitted: @escaping (Double) -> Void = { _ in }) {
        self.show = show
        self.userCurrentRating = userCurrentRating
        self.onRatingSubmitted = onRatingSubmitted
        _rating = State(initialValue: userCurrentRating ?? 3.0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(userCurrentRating != nil ? "Update Rating" : "Rate \(show.name)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                if userCurrentRating != nil {
                    Text("You previously rated this \(String(format: "%.1f", userCurrentRating!)) stars")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Star rating display
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                rating = Double(star)
                            }
                    }
                }
                .padding()
                
                Text("This rating will contribute to the show's overall rating.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let success = successMessage {
                    Text(success)
                        .foregroundColor(.green)
                        .padding()
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button(action: submitRating) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text(userCurrentRating != nil ? "Update Rating" : "Submit Rating")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(isSubmitting)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
    
    private func submitRating() {
        guard let userId = authManager.currentUser?.uid, let showId = show.id else {
            errorMessage = "Unable to submit rating. Please try again."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await FirestoreShowService.shared.rateShow(
                    showId: showId,
                    userId: userId,
                    rating: rating
                )
                
                await MainActor.run {
                    successMessage = "Rating submitted successfully!"
                    isSubmitting = false
                    onRatingSubmitted(rating)
                    
                    // Auto dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to submit rating: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    FirestoreShowDetailView(
        firestoreShow: FirestoreShow(
            tmdbId: 1,
            name: "Sample Show",
            overview: "This is a sample show overview with some text to demonstrate how the overview section will look with multiple lines of text.",
            posterPath: nil,
            backdropPath: nil,
            firstAirDate: "2023-01-01"
        )
    )
    .environmentObject(AuthManager())
} 
