import SwiftUI
import SwiftData

enum Tab {
    case home, search, watchlist, lists, trending, reviews, profile
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var selection: Tab = .home
    @State private var showSignInView: Bool = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        TabView(selection: $selection) {
            NavigationView {
                HomepageView(showSignInView: $showSignInView)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(Tab.home)
            
            NavigationView {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)
            
            NavigationView {
                WatchlistView()
            }
            .tabItem {
                Label("Watchlist", systemImage: "bookmark")
            }
            .tag(Tab.watchlist)
            
            NavigationView {
                UserListsView()
            }
            .tabItem {
                Label("Lists", systemImage: "list.bullet")
            }
            .tag(Tab.lists)
            
            NavigationView {
                TrendingTVView()
            }
            .tabItem {
                Label("Trending", systemImage: "flame")
            }
            .tag(Tab.trending)
            
            NavigationView {
                UserReviewsView()
                    .onAppear {
                        print("Reviews tab selected in ContentView")
                    }
            }
            .tabItem {
                Label("Reviews", systemImage: "star.bubble")
            }
            .tag(Tab.reviews)
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(Tab.profile)
        }
        .accentColor(.red)
        .environmentObject(authManager)
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .environmentObject(AuthManager())
}
