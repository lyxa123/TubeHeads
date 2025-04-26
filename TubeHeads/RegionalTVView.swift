import SwiftUI

struct RegionalTVView: View {
    @StateObject private var viewModel = RegionalTVViewModel()
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Popular in \(viewModel.regionName)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if locationManager.authorizationStatus != .authorizedWhenInUse && 
                   locationManager.authorizationStatus != .authorizedAlways {
                    Button {
                        locationManager.requestLocationPermission()
                    } label: {
                        HStack {
                            Image(systemName: "location")
                            Text("Set Location")
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
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
                    Text("Error loading regional shows")
                        .foregroundColor(.red)
                        .font(.caption)
                    Button("Try Again") {
                        Task {
                            await viewModel.loadRegionalShows()
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
            } else if viewModel.regionalShows.isEmpty {
                Text("No shows available for your region")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.regionalShows) { regionalShow in
                            NavigationLink(destination: 
                                FirestoreShowDetailView(firestoreShow: FirestoreShow(
                                    tmdbId: regionalShow.show.id,
                                    name: regionalShow.show.name,
                                    overview: regionalShow.show.overview,
                                    posterPath: regionalShow.show.posterPath,
                                    backdropPath: regionalShow.show.backdropPath,
                                    firstAirDate: regionalShow.show.firstAirDate
                                ))
                            ) {
                                RegionalShowCard(regionalShow: regionalShow)
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
                await viewModel.loadRegionalShows()
            }
        }
        .onChange(of: locationManager.placemark) { _ in
            Task {
                await viewModel.loadRegionalShows()
            }
        }
    }
}

struct RegionalShowCard: View {
    let regionalShow: RegionalShow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Poster image
            AsyncImage(url: regionalShow.show.posterURL) { phase in
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
            
            // Provider logos
            if !regionalShow.providers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(regionalShow.providers.prefix(3)) { provider in
                            ProviderLogoView(provider: provider)
                        }
                    }
                }
                .frame(height: 18)
                .padding(.top, 1)
            } else {
                Spacer()
                    .frame(height: 6)
            }
        }
        .frame(width: 120)
    }
}

struct ProviderLogoView: View {
    let provider: Provider
    
    var body: some View {
        AsyncImage(url: provider.logoURL) { phase in
            switch phase {
            case .empty:
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 15, height: 15)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .clipShape(Circle())
            case .failure:
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 15, height: 15)
                    .overlay(
                        Text(provider.providerName.prefix(1))
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    )
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 15, height: 15)
    }
} 