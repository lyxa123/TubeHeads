import Foundation
import SwiftUI
import CoreLocation

class RegionalTVViewModel: ObservableObject {
    @Published var regionalShows: [RegionalShow] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var regionName: String = "your region"
    
    private let locationManager = LocationManager.shared
    
    @MainActor
    func loadRegionalShows() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get the country code from the location manager
            var countryCode = RegionalTVService.shared.getCountryCode(from: locationManager.placemark)
            
            // Get the region name for display
            if let countryName = locationManager.placemark?.country {
                regionName = countryName
            }
            
            // Fetch shows for this region
            regionalShows = try await RegionalTVService.shared.fetchRegionalShows(region: countryCode)
            
            // If we don't get any good results, try common English-speaking regions
            if regionalShows.isEmpty {
                // List of regions to try, in order of preference
                let fallbackRegions = ["us", "gb", "ca", "au"]
                
                for region in fallbackRegions {
                    // Skip the region we already tried
                    if region == countryCode.lowercased() {
                        continue
                    }
                    
                    do {
                        // Try this region
                        let shows = try await RegionalTVService.shared.fetchRegionalShows(region: region)
                        
                        if !shows.isEmpty {
                            regionalShows = shows
                            
                            // Update region name
                            switch region {
                            case "us":
                                regionName = "the United States"
                            case "gb":
                                regionName = "the United Kingdom"
                            case "ca":
                                regionName = "Canada"
                            case "au":
                                regionName = "Australia"
                            default:
                                regionName = region.uppercased()
                            }
                            
                            break
                        }
                    } catch {
                        print("Error with fallback region \(region): \(error)")
                        continue
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading regional shows: \(error)")
        }
        
        isLoading = false
    }
} 