import SwiftUI

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [TVShow] = []
    @Published var isSearching = false
    @Published var errorMessage: String? = nil
    @Published var showRecentSearches = true
    
    // Store recent searches
    @Published var recentSearches: [String] = []
    private let maxRecentSearches = 5
    
    private var searchTask: Task<Void, Never>?
    
    init() {
        // Load recent searches from UserDefaults
        recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    }
    
    func search() {
        // Cancel any ongoing search
        searchTask?.cancel()
        
        guard !searchText.isEmpty else {
            searchResults = []
            showRecentSearches = true
            return
        }
        
        showRecentSearches = false
        isSearching = true
        errorMessage = nil
        
        // Debounce search to avoid too many API calls
        searchTask = Task {
            do {
                // Wait for 500ms before actually performing the search
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // If task was cancelled during the sleep, exit
                if Task.isCancelled { return }
                
                let results = try await SearchService.shared.searchShows(query: searchText)
                
                // Make sure we're on the main thread for UI updates
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                    
                    // Add to recent searches if not already present and we got results
                    if !results.isEmpty {
                        self.addToRecentSearches(self.searchText)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        showRecentSearches = true
        searchTask?.cancel()
    }
    
    private func addToRecentSearches(_ query: String) {
        // Remove the search term if it already exists to avoid duplicates
        recentSearches.removeAll(where: { $0 == query })
        
        // Add the new search term at the beginning
        recentSearches.insert(query, at: 0)
        
        // Limit the number of recent searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "recentSearches")
    }
    
    func performSearch(with term: String) {
        searchText = term
        search()
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            // Results or recent searches
            if viewModel.showRecentSearches && !viewModel.recentSearches.isEmpty {
                recentSearchesView
            } else if viewModel.isSearching {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                noResultsView
            } else {
                searchResultsView
            }
        }
        .navigationBarHidden(true)
        .background(Color(UIColor.systemBackground))
    }
    
    private var searchHeader: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.primary)
                    .padding(8)
            }
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search for TV shows", text: $viewModel.searchText, onCommit: {
                    viewModel.search()
                })
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGray6))
            .cornerRadius(10)
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .onChange(of: viewModel.searchText) { _ in
            viewModel.search()
        }
    }
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    viewModel.clearRecentSearches()
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.recentSearches, id: \.self) { search in
                        Button(action: {
                            viewModel.performSearch(with: search)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                
                                Text(search)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                        }
                        .background(Color(UIColor.systemBackground))
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Searching...")
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.yellow)
                .padding()
            
            Text("Error")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding()
            
            Button("Try Again") {
                viewModel.search()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
    
    private var noResultsView: some View {
        VStack {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .padding()
            
            Text("No results found")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("Try using different keywords or check your spelling")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding()
            
            Spacer()
        }
        .padding()
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.searchResults) { show in
                    NavigationLink(destination: 
                        FirestoreShowDetailView(firestoreShow: FirestoreShow(
                            tmdbId: show.id,
                            name: show.name,
                            overview: show.overview,
                            posterPath: show.posterPath,
                            backdropPath: show.backdropPath,
                            firstAirDate: show.firstAirDate
                        ))
                    ) {
                        SearchResultRow(show: show)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct SearchResultRow: View {
    let show: TVShow
    
    var body: some View {
        HStack(spacing: 16) {
            // Show poster
            AsyncImage(url: show.posterURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 120)
            .cornerRadius(8)
            
            // Show details
            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if !show.releaseYear.isEmpty && show.releaseYear != "TBA" {
                    Text(show.releaseYear)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(show.overview)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        SearchView()
    }
} 