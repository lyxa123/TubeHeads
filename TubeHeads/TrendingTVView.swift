import SwiftUI

struct TrendingTVView: View {
    @StateObject private var viewModel = TrendingTVViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trending Shows")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Time Window", selection: $viewModel.selectedTimeWindow) {
                    Text("Today").tag(TimeWindow.day)
                    Text("This Week").tag(TimeWindow.week)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .scaleEffect(0.9)
            }
            .padding(.horizontal)
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.0)
                        .padding()
                    Spacer()
                }
            } else if viewModel.errorMessage != nil {
                VStack {
                    Text("Error loading shows")
                        .foregroundColor(.red)
                        .font(.caption)
                    Button("Try Again") {
                        Task {
                            await viewModel.loadTrendingShows()
                        }
                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(viewModel.tvShows.enumerated()), id: \.element.id) { index, show in
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
                                TVShowCard(show: show)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                }
                .frame(height: 215)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadTrendingShows()
            }
        }
        .onChange(of: viewModel.selectedTimeWindow) { _ in
            Task {
                await viewModel.loadTrendingShows()
            }
        }
    }
}

struct TVShowCard: View {
    let show: TVShow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Poster image only
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
            .frame(width: 120, height: 180)
            .cornerRadius(6)
            .shadow(radius: 2)
        }
        .frame(width: 120)
    }
}

class TrendingTVViewModel: ObservableObject {
    @Published var tvShows: [TVShow] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var selectedTimeWindow: TimeWindow = .week
    
    @MainActor
    func loadTrendingShows() async {
        isLoading = true
        errorMessage = nil
        
        do {
            tvShows = try await TrendingTVService.shared.fetchTrendingShows(timeWindow: selectedTimeWindow)
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading trending shows: \(error)")
        }
        
        isLoading = false
    }
} 