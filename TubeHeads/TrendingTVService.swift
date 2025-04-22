import Foundation

// Models for TMDB API response
struct TMDBResponse: Codable {
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

struct TVShow: Identifiable, Codable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let firstAirDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case firstAirDate = "first_air_date"
    }
    
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var releaseYear: String {
        guard let firstAirDate = firstAirDate, firstAirDate.count >= 4 else { return "TBA" }
        return String(firstAirDate.prefix(4))
    }
    
    var rating: String {
        return String(format: "%.1f", voteAverage)
    }
}

enum TimeWindow: String {
    case day
    case week
}

class TrendingTVService {
    static let shared = TrendingTVService()
    private let apiKey = "2d1114118f8905f3c102caa8791981e5"
    
    private init() {}
    
    func fetchTrendingShows(timeWindow: TimeWindow = .week) async throws -> [TVShow] {
        let urlString = "https://api.themoviedb.org/3/trending/tv/\(timeWindow.rawValue)?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let tmdbResponse = try decoder.decode(TMDBResponse.self, from: data)
        
        return tmdbResponse.results
    }
} 