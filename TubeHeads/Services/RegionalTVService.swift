import Foundation
import CoreLocation

// Models for region-specific providers
struct WatchProviderResponse: Codable {
    let results: [String: WatchProviderCountry]
}

struct WatchProviderCountry: Codable {
    let link: String?
    let flatrate: [Provider]?
    let rent: [Provider]?
    let buy: [Provider]?
}

struct Provider: Codable, Identifiable {
    let id: Int
    let providerName: String
    let logoPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
    
    var logoURL: URL? {
        guard let logoPath = logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(logoPath)")
    }
}

struct PopularShowsResponse: Codable {
    let page: Int
    let results: [TVShow]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct RegionalShow: Identifiable {
    let show: TVShow
    let providers: [Provider]
    
    var id: Int {
        return show.id
    }
}

class RegionalTVService {
    static let shared = RegionalTVService()
    private let apiKey = "2d1114118f8905f3c102caa8791981e5"
    
    private init() {}
    
    // Get the two letter ISO country code from the region
    func getCountryCode(from placemark: CLPlacemark?) -> String {
        if let countryCode = placemark?.isoCountryCode {
            return countryCode.lowercased()
        }
        return "us" // Default to United States
    }
    
    // Fetch popular shows
    func fetchPopularShows(region: String) async throws -> [TVShow] {
        // Use discover endpoint instead of popular for better region-specific results
        let urlString = "https://api.themoviedb.org/3/discover/tv?api_key=\(apiKey)&sort_by=popularity.desc&region=\(region)&with_original_language=en&include_adult=false&vote_count.gte=100"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let popularResponse = try decoder.decode(PopularShowsResponse.self, from: data)
        
        return popularResponse.results
    }
    
    // Fetch providers for a specific show in a specific region
    func fetchWatchProviders(for showId: Int, region: String) async throws -> [Provider] {
        let urlString = "https://api.themoviedb.org/3/tv/\(showId)/watch/providers?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let providerResponse = try decoder.decode(WatchProviderResponse.self, from: data)
        
        // Get providers for the specified region
        if let countryProviders = providerResponse.results[region] {
            // First try streaming (flatrate)
            if let flatrate = countryProviders.flatrate, !flatrate.isEmpty {
                return flatrate
            }
            
            // Then try rental options
            if let rent = countryProviders.rent, !rent.isEmpty {
                return rent
            }
            
            // Finally try purchase options
            if let buy = countryProviders.buy, !buy.isEmpty {
                return buy
            }
        }
        
        return []
    }
    
    // Fetch popular shows with their streaming providers for a specific region
    func fetchRegionalShows(region: String) async throws -> [RegionalShow] {
        let shows = try await fetchPopularShows(region: region)
        
        var regionalShows: [RegionalShow] = []
        var showsWithoutProviders: [TVShow] = []
        
        // For each show, fetch its providers
        for show in shows.prefix(15) { // Look at more shows to find those with providers
            do {
                let providers = try await fetchWatchProviders(for: show.id, region: region)
                if !providers.isEmpty {
                    regionalShows.append(RegionalShow(show: show, providers: providers))
                    
                    // If we have enough shows with providers, break early
                    if regionalShows.count >= 10 {
                        break
                    }
                } else {
                    // Keep track of shows without providers
                    showsWithoutProviders.append(show)
                }
            } catch {
                print("Error fetching providers for show \(show.id): \(error)")
                showsWithoutProviders.append(show)
                continue
            }
        }
        
        // If we don't have enough shows with providers, add shows without providers
        if regionalShows.isEmpty {
            // Add all shows without providers if we have none with providers
            for show in showsWithoutProviders.prefix(10) {
                regionalShows.append(RegionalShow(show: show, providers: []))
            }
        }
        
        return regionalShows
    }
} 