import SwiftUI

struct TrendingTVView: View {
    @StateObject private var viewModel = TrendingTVViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending Shows")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Time Window", selection: $viewModel.selectedTimeWindow) {
                    Text("Today").tag(TimeWindow.day)
                    Text("This Week").tag(TimeWindow.week)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal)
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Spacer()
                }
            } else if viewModel.errorMessage != nil {
                VStack {
                    Text("Error loading shows")
                        .foregroundColor(.red)
                    Button("Try Again") {
                        Task {
                            await viewModel.loadTrendingShows()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.tvShows) { show in
                            NavigationLink(destination: ShowDetailView(tmdbId: show.id, initialTVShow: show)) {
                                TVShowCard(show: show)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
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
            .frame(width: 150, height: 225)
            .cornerRadius(8)
            .shadow(radius: 3)
        }
        .frame(width: 150)
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