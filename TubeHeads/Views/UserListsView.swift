import SwiftUI
import FirebaseFirestore

struct UserListsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var userLists: [ShowList] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateListSheet = false
    @State private var selectedFilter: ListFilter = .yourList
    @State private var watchedShows: [WatchedShow] = []
    @State private var isLoadingWatchedShows = false
    
    // Add optional userId parameter
    var userId: String?
    
    enum ListFilter: String, CaseIterable {
        case yourList = "Your List"
        case likedList = "Liked List"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs - only show when viewing own lists
            if userId == nil {
                HStack(spacing: 0) {
                    ForEach(ListFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            if selectedFilter != filter {
                                selectedFilter = filter
                                Task {
                                    await loadUserLists()
                                }
                            }
                        }) {
                            Text(filter.rawValue)
                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                        }
                        .background(selectedFilter == filter ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Search action
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal)
            }
            
            if isLoading {
                ProgressView("Loading lists...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 10) {
                    Text("Error loading lists")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .foregroundColor(.gray)
                    
                    Button("Try Again") {
                        Task {
                            await loadUserData()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if userLists.isEmpty && watchedShows.isEmpty && selectedFilter == .yourList {
                VStack(spacing: 20) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    if userId != nil {
                        Text("This user has no public lists")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("When they create public lists, they will appear here.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        Text("You haven't created any lists yet")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Create your first list to keep track of TV shows you want to watch or ones you love.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showCreateListSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create List")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if userLists.isEmpty && selectedFilter == .likedList {
                VStack(spacing: 20) {
                    Image(systemName: "heart")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No liked lists yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Lists you like from other users will appear here.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List content
                ScrollView {
                    VStack(spacing: 20) {
                        // Watched Shows section (shown as a list)
                        if !watchedShows.isEmpty && (userId == nil || (userId != nil && userId == authManager.currentUser?.uid)) && selectedFilter == .yourList {
                            NavigationLink(destination: WatchedShowsView(shows: watchedShows)) {
                                WatchedShowsListCard(watchedShows: watchedShows)
                            }
                        }
                        
                        // User-created lists
                        ForEach(userLists) { list in
                            NavigationLink(destination: ListDetailView(list: list)) {
                                if selectedFilter == .likedList {
                                    LikedListCardView(list: list)
                                } else {
                                    ListCardView(list: list)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(userId == nil ? "Lists" : "User's Lists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedFilter == .yourList && userId == nil {
                    Button(action: {
                        showCreateListSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadUserData()
            }
        }
        .sheet(isPresented: $showCreateListSheet) {
            CreateListView(onListCreated: { newList in
                userLists.insert(newList, at: 0)
            })
        }
    }
    
    private func loadUserData() async {
        await loadUserLists()
        await loadWatchedShows()
    }
    
    private func loadUserLists() async {
        // If userId is provided, use that; otherwise use current user's ID
        let targetUserId = userId ?? authManager.currentUser?.uid
        
        guard let userIdToLoad = targetUserId else {
            isLoading = false
            errorMessage = "You must be signed in to view lists"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // When viewing another user's lists, we only want to see public lists
            if userId != nil {
                // Load other user's public lists
                let allLists = try await ListService.shared.getUserLists(userId: userIdToLoad)
                userLists = allLists.filter { !$0.isPrivate }
            } else if selectedFilter == .yourList {
                // Load current user's lists (both public and private)
                userLists = try await ListService.shared.getUserLists(userId: userIdToLoad)
            } else {
                // Load current user's liked lists
                userLists = try await ListService.shared.getLikedLists(userId: userIdToLoad)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading user lists: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadWatchedShows() async {
        // If userId is provided, use that; otherwise use current user's ID
        let targetUserId = userId ?? authManager.currentUser?.uid
        
        guard let userIdToLoad = targetUserId else {
            return
        }
        
        isLoadingWatchedShows = true
        
        do {
            let profile = try await ProfileManager.shared.getProfile(userId: userIdToLoad)
            await MainActor.run {
                watchedShows = profile.watchedShows.sorted(by: { $0.dateWatched > $1.dateWatched })
                isLoadingWatchedShows = false
            }
        } catch {
            print("Error loading watched shows: \(error)")
            await MainActor.run {
                isLoadingWatchedShows = false
            }
        }
    }
}

// New component for displaying Watched Shows as a list card
struct WatchedShowsListCard: View {
    let watchedShows: [WatchedShow]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with eye icon to indicate watched shows
            HStack {
                Text("Watched Shows")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Spacer()
                
                Text("Updated \(formattedLatestWatchDate)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Description
            Text("Shows you've watched")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            // Show preview images
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(watchedShows.prefix(4)) { show in
                        if let imageName = show.imageName, !imageName.isEmpty {
                            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w200\(imageName)")) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 120)
                                        .cornerRadius(6)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 120)
                                        .cornerRadius(6)
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 120)
                                        .cornerRadius(6)
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
                                .frame(width: 80, height: 120)
                                .cornerRadius(6)
                                .overlay(
                                    Image(systemName: "tv")
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Get formatted date of the most recently watched show
    private var formattedLatestWatchDate: String {
        guard let latestShow = watchedShows.sorted(by: { $0.dateWatched > $1.dateWatched }).first else {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: latestShow.dateWatched)
    }
}

struct ListCardView: View {
    let list: ShowList
    @State private var listShows: [FirestoreShow] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and lock icon for private lists
            HStack {
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if list.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            
            // Description
            Text(list.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            // Show preview images (if available)
            if isLoading {
                HStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 120)
                            .cornerRadius(6)
                    }
                }
            } else if !listShows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(listShows.prefix(4)) { show in
                            if let posterURL = show.posterURL {
                                AsyncImage(url: posterURL) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 120)
                                            .cornerRadius(6)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 120)
                                            .cornerRadius(6)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 120)
                                            .cornerRadius(6)
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
                                    .frame(width: 80, height: 120)
                                    .cornerRadius(6)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                }
            } else {
                Text("No shows in this list yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: 50)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            if let listId = list.id {
                Task {
                    await loadListShows(listId: listId)
                }
            }
        }
    }
    
    private func loadListShows(listId: String) async {
        isLoading = true
        
        do {
            listShows = try await ListService.shared.getShowsInList(listId: listId)
        } catch {
            print("Error loading shows for list \(listId): \(error)")
        }
        
        isLoading = false
    }
}

struct LikedListCardView: View {
    let list: ShowList
    @State private var listShows: [FirestoreShow] = []
    @State private var isLoading = true
    @State private var creatorUsername: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with heart icon for liked lists
            HStack {
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Spacer()
            }
            
            // Description
            Text(list.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            // Creator info
            if !creatorUsername.isEmpty {
                Text("Created by: \(creatorUsername)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Show preview images (if available)
            if isLoading {
                HStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 120)
                            .cornerRadius(6)
                    }
                }
            } else if !listShows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(listShows.prefix(4)) { show in
                            if let posterURL = show.posterURL {
                                AsyncImage(url: posterURL) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 120)
                                            .cornerRadius(6)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 120)
                                            .cornerRadius(6)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 120)
                                            .cornerRadius(6)
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
                                    .frame(width: 80, height: 120)
                                    .cornerRadius(6)
                                    .overlay(
                                        Image(systemName: "tv")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                }
            } else {
                Text("This list is empty")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical)
            }
            
            // Last updated date
            Text("Updated \(list.formattedDate)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            Task {
                await loadListShows()
                await loadCreatorUsername()
            }
        }
    }
    
    private func loadListShows() async {
        isLoading = true
        
        do {
            let shows = try await ListService.shared.getShowsInList(listId: list.id ?? "")
            await MainActor.run {
                listShows = shows
                isLoading = false
            }
        } catch {
            print("Error loading shows for list: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadCreatorUsername() async {
        do {
            let profile = try await ProfileManager.shared.getProfile(userId: list.userId)
            await MainActor.run {
                creatorUsername = profile.username
            }
        } catch {
            print("Error loading creator username: \(error)")
        }
    }
}

struct CreateListView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var listName: String = ""
    @State private var listDescription: String = ""
    @State private var isPrivate: Bool = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var onListCreated: (ShowList) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Details")) {
                    TextField("List Name", text: $listName)
                    
                    TextField("Description", text: $listDescription)
                        .frame(height: 80)
                    
                    Toggle("Private List", isOn: $isPrivate)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create New List")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: createList) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Create")
                            .bold()
                    }
                }
                .disabled(isCreating || listName.isEmpty)
            )
        }
    }
    
    private func createList() {
        guard let userId = authManager.currentUser?.uid else {
            errorMessage = "You must be signed in to create a list"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let listId = try await ListService.shared.createList(
                    name: listName,
                    description: listDescription,
                    isPrivate: isPrivate,
                    userId: userId
                )
                
                if let newList = try? await ListService.shared.getList(id: listId) {
                    await MainActor.run {
                        onListCreated(newList)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                errorMessage = "Failed to create list: \(error.localizedDescription)"
                print("Error creating list: \(error)")
            }
            
            await MainActor.run {
                isCreating = false
            }
        }
    }
}

struct ListDetailView: View {
    @State private var list: ShowList
    @State private var shows: [FirestoreShow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isEditMode = false
    @State private var selectedShows: Set<String> = []
    @State private var showingPrivacyConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var randomShow: FirestoreShow? = nil
    @State private var showingRandomShow = false
    @State private var isSpinningRoulette = false
    @EnvironmentObject private var authManager: AuthManager
    
    init(list: ShowList) {
        _list = State(initialValue: list)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // List header
                VStack(alignment: .leading, spacing: 8) {
                    Text(list.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(list.description)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                    
                    HStack {
                        if list.isPrivate {
                            Label("Private", systemImage: "lock.fill")
                                .font(.caption)
                        } else {
                            Label("Public", systemImage: "globe")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Text("Created \(list.formattedDate)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Add roulette button if there are shows
                    if !shows.isEmpty {
                        Button(action: pickRandomShow) {
                            Label("Roulette", systemImage: "dice.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.top, 8)
                                .scaleEffect(isSpinningRoulette ? 1.1 : 1.0)
                                .rotation3DEffect(
                                    .degrees(isSpinningRoulette ? 360 : 0),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                                .animation(
                                    isSpinningRoulette ? 
                                        .easeInOut(duration: 0.5).repeatCount(3, autoreverses: false) : 
                                        .default,
                                    value: isSpinningRoulette
                                )
                        }
                    }
                }
                .padding()
                
                if isLoading {
                    ProgressView("Loading shows...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = errorMessage {
                    VStack {
                        Text("Error loading shows")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .foregroundColor(.gray)
                        
                        Button("Try Again") {
                            loadShows()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else if shows.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tv")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No shows in this list yet")
                            .font(.headline)
                        
                        Text("Add shows to this list by tapping the bookmark icon on a show's detail page.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding()
                    }
                    .padding(.vertical, 50)
                    .frame(maxWidth: .infinity)
                } else {
                    // Shows in list
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(shows) { show in
                            if isEditMode {
                                ShowEditItemView(
                                    show: show,
                                    isSelected: selectedShows.contains(show.id ?? ""),
                                    onToggle: { toggleShowSelection(show) }
                                )
                            } else {
                                NavigationLink(destination: FirestoreShowDetailView(firestoreShow: show)) {
                                    ShowGridItemView(show: show)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    Button(action: {
                        isEditMode = false
                        selectedShows.removeAll()
                    }) {
                        Text("Done")
                    }
                } else if authManager.currentUser?.uid == list.userId {
                    // Only show menu if user owns the list
                    Menu {
                        Button(action: {
                            isEditMode = true
                        }) {
                            Label("Edit Shows", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            showingPrivacyConfirmation = true
                        }) {
                            Label(list.isPrivate ? "Make Public" : "Make Private", 
                                  systemImage: list.isPrivate ? "globe" : "lock")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay(
            VStack {
                Spacer()
                
                if isEditMode && !selectedShows.isEmpty && authManager.currentUser?.uid == list.userId {
                    HStack {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Text("Remove \(selectedShows.count) show\(selectedShows.count > 1 ? "s" : "")")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                }
            }
        )
        .confirmationDialog(
            "Change Privacy Setting",
            isPresented: $showingPrivacyConfirmation,
            titleVisibility: .visible
        ) {
            Button(list.isPrivate ? "Make Public" : "Make Private", role: .none) {
                toggleListPrivacy()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(list.isPrivate 
                ? "Making this list public will allow other users to see it."
                : "Making this list private will hide it from other users.")
        }
        .confirmationDialog(
            "Remove Shows",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                removeSelectedShows()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove the selected shows from this list?")
        }
        .task {
            await fetchShowsData(listId: list.id ?? "")
        }
        .sheet(isPresented: $showingRandomShow, onDismiss: {
            randomShow = nil
        }) {
            if let show = randomShow {
                NavigationView {
                    FirestoreShowDetailView(firestoreShow: show)
                        .navigationBarItems(trailing: Button("Close") {
                            showingRandomShow = false
                        })
                }
            }
        }
    }
    
    private func loadShows() {
        guard let listId = list.id else {
            errorMessage = "Invalid list ID"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await fetchShowsData(listId: listId)
        }
    }
    
    private func fetchShowsData(listId: String) async {
        do {
            let loadedShows = try await ListService.shared.getShowsInList(listId: listId)
            
            // Also refresh the list details
            let updatedList = try? await ListService.shared.getList(id: listId)
            
            await MainActor.run {
                shows = loadedShows
                if let updatedList = updatedList {
                    list = updatedList
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                print("Error loading shows: \(error)")
            }
        }
    }
    
    private func toggleShowSelection(_ show: FirestoreShow) {
        guard let showId = show.id else { return }
        
        if selectedShows.contains(showId) {
            selectedShows.remove(showId)
        } else {
            selectedShows.insert(showId)
        }
    }
    
    private func removeSelectedShows() {
        guard let listId = list.id else { return }
        
        // Verify user ownership before allowing removal
        guard authManager.currentUser?.uid == list.userId else {
            print("Error: User does not own this list and cannot remove shows")
            return
        }
        
        // Capture the selected shows for removal
        let showsToRemove = selectedShows
        
        // Set to edit mode immediately for UI feedback
        isEditMode = true
        
        Task {
            do {
                // Update the list with the filtered show IDs
                // Create a filtered list of shows that excludes the ones to be removed
                let filteredShowIds = list.showIds.filter { showId in
                    !showsToRemove.contains(showId)
                }
                
                // Update the list with the filtered show IDs
                try await updateShowIdsInList(listId: listId, showIds: filteredShowIds)
                
                // Clear selection and reload the shows list
                await MainActor.run {
                    selectedShows.removeAll()
                }
                
                // Load the fresh data
                await fetchShowsData(listId: listId)
                
                // Exit edit mode once complete
                await MainActor.run {
                    isEditMode = false
                }
            } catch {
                print("Error removing shows: \(error)")
                
                await MainActor.run {
                    isEditMode = false
                }
            }
        }
    }
    
    private func updateShowIdsInList(listId: String, showIds: [String]) async throws {
        // Get a reference to the list document
        let listRef = Firestore.firestore().collection("lists").document(listId)
        
        // Update the showIds field with the new array
        try await listRef.updateData([
            "showIds": showIds
        ])
    }
    
    private func toggleListPrivacy() {
        guard let listId = list.id else { return }
        
        // Verify user ownership before allowing privacy changes
        guard authManager.currentUser?.uid == list.userId else {
            print("Error: User does not own this list and cannot change privacy settings")
            return
        }
        
        // Toggle local state first for immediate UI feedback
        list.isPrivate.toggle()
        
        Task {
            do {
                // Update Firestore
                try await ListService.shared.updateListPrivacy(listId: listId, isPrivate: list.isPrivate)
            } catch {
                // Revert on error
                await MainActor.run {
                    list.isPrivate.toggle() // Revert back on error
                    print("Error updating list privacy: \(error)")
                }
            }
        }
    }
    
    private func pickRandomShow() {
        guard !shows.isEmpty else { return }
        
        // Start animation
        isSpinningRoulette = true
        
        // Schedule showing the random show after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Pick a random show
            let randomIndex = Int.random(in: 0..<shows.count)
            randomShow = shows[randomIndex]
            showingRandomShow = true
            isSpinningRoulette = false
        }
    }
}

struct ShowEditItemView: View {
    let show: FirestoreShow
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topTrailing) {
                ShowGridItemView(show: show)
                    .opacity(isSelected ? 0.7 : 1.0)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)
                    .background(Circle().fill(Color.white))
                    .padding(8)
            }
        }
    }
}

struct ShowGridItemView: View {
    let show: FirestoreShow
    
    var body: some View {
        VStack(alignment: .leading) {
            // Poster image
            if let posterURL = show.posterURL {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(2/3, contentMode: .fit)
                            .cornerRadius(8)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .cornerRadius(8)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(2/3, contentMode: .fit)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 200)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // Show title
            Text(show.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            // Release year
            Text(show.releaseYear)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    UserListsView()
        .environmentObject(AuthManager())
} 