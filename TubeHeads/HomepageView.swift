import SwiftUI

struct HomepageView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showSignInView: Bool
    @State private var showMenu = false
    @State private var navigateToSettings = false
    @State private var showSearch = false
    @State private var username: String = ""
    @State private var isLoadingUsername: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TubeHeads")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        // Region-specific popular shows
                        RegionalTVView()
                            .padding(.top, 4)
                        
                        // Trending TV Shows
                        TrendingTVView()
                            .padding(.top, 4)
                        
                        // More sections could be added here
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
                
                // Slide-out menu
                if showMenu {
                    SideMenuView(
                        showMenu: $showMenu,
                        showSignInView: $showSignInView,
                        username: username
                    )
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }
                
                NavigationLink(destination: SettingsView(showSignInView: $showSignInView), isActive: $navigateToSettings) {
                    EmptyView()
                }
                
                NavigationLink(destination: SearchView(), isActive: $showSearch) {
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        loadUsername()
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 {
                        loadUsername()
                        withAnimation {
                            showMenu = true
                        }
                    } else if value.translation.width < -50 && showMenu {
                        withAnimation {
                            showMenu = false
                        }
                    }
                }
        )
    }
    
    private func loadUsername() {
        guard !isLoadingUsername && username.isEmpty else { return }
        
        isLoadingUsername = true
        Task {
            if let username = await authManager.getCurrentUsername() {
                self.username = username
            }
            isLoadingUsername = false
        }
    }
}

struct SideMenuView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showMenu: Bool
    @Binding var showSignInView: Bool
    @State private var navigateToSettings = false
    @State private var navigateToProfile = false
    @State private var navigateToWatchlist = false
    @State private var navigateToLists = false
    @State private var navigateToReviews = false
    var username: String
    
    var body: some View {
        ZStack {
            // Background overlay that dismisses menu when tapped
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showMenu.toggle()
                    }
                }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation {
                                showMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                                .imageScale(.large)
                                .padding()
                        }
                    }
                    
                    // User greeting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hello,")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        if username.isEmpty {
                            Text("User")
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text(username)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 24)
                    
                    // Add divider 
                    Divider()
                        .padding(.horizontal)
                    
                    // Add more padding to push menu items down
                    Spacer()
                        .frame(height: 40)
                    
                    // Profile (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Navigate to profile after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToProfile = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Profile")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Watchlist (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Navigate to watchlist after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToWatchlist = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Watchlist")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Lists (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Navigate to lists after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToLists = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("My Lists")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Reviews (non-functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Navigate to reviews after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToReviews = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Reviews")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    // Activities (non-functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flame.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Activities")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Settings (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Navigate to settings after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToSettings = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Settings")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.blue)
                        .contentShape(Rectangle())
                    }
                    
                    // Log Out (functional)
                    Button {
                        withAnimation {
                            showMenu = false
                        }
                        
                        // Sign out after menu closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            authManager.signOut()
                            showSignInView = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Log Out")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .foregroundColor(.blue)
                        .contentShape(Rectangle())
                    }
                    
                    NavigationLink(destination: ProfileView().environmentObject(authManager), isActive: $navigateToProfile) {
                        EmptyView()
                    }
                    
                    NavigationLink(destination: WatchlistView().environmentObject(authManager), isActive: $navigateToWatchlist) {
                        EmptyView()
                    }
                    
                    NavigationLink(destination: UserListsView().environmentObject(authManager), isActive: $navigateToLists) {
                        EmptyView()
                    }
                    
                    NavigationLink(destination: UserReviewsView().environmentObject(authManager), isActive: $navigateToReviews) {
                        EmptyView()
                    }
                    
                    NavigationLink(destination: SettingsView(showSignInView: $showSignInView), isActive: $navigateToSettings) {
                        EmptyView()
                    }
                    
                    Spacer()
                        .frame(height: 20)
                }
                .frame(width: 250)
                .background(Color(UIColor.systemBackground))
                .edgesIgnoringSafeArea(.vertical)
                
                Spacer()
            }
        }
    }
}
