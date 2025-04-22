import Foundation

class SearchService {
    static let shared = SearchService()
    private let apiKey = "2d1114118f8905f3c102caa8791981e5"
    
    private init() {}
    
    func searchShows(query: String) async throws -> [TVShow] {
        guard !query.isEmpty else { return [] }
        
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://api.themoviedb.org/3/search/tv?api_key=\(apiKey)&query=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(TMDBResponse.self, from: data)
        
        return searchResponse.results
    }
} 