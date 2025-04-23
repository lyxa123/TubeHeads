import SwiftUI
import SwiftData

enum Tab {
    case home, search, trending, profile
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var selection: Tab = .home
    @State private var showSignInView: Bool = false
    @EnvironmentObject var authManager: AuthManager

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
                TrendingTVView()
            }
            .tabItem {
                Label("Trending", systemImage: "flame")
            }
            .tag(Tab.trending)
            
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
