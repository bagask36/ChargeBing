import Foundation
import CoreLocation

@Observable
final class StationsViewModel {
    var stations: [Station] = []
    var selectedStation: Station?
    var isLoading: Bool = false
    var errorMessage: String?

    var searchText: String = ""
    var filterCurrentType: String = "ALL" // "ALL", "AC", "DC"
    var usableOnly: Bool = false // Only GB/T native or adapter_ok

    @MainActor
    func fetchStations(userLocation: CLLocation? = nil) async {
        isLoading = true
        errorMessage = nil

        var queryItems: [URLQueryItem] = []

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: searchText.trimmingCharacters(in: .whitespaces)))
        }

        if filterCurrentType != "ALL" {
            queryItems.append(URLQueryItem(name: "current_type", value: filterCurrentType))
        }

        if usableOnly {
            queryItems.append(URLQueryItem(name: "usable_only", value: "1"))
        }

        if let loc = userLocation {
            queryItems.append(URLQueryItem(name: "lat", value: String(loc.coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: String(loc.coordinate.longitude)))
        }

        print("[StationsViewModel] fetchStations called with userLocation: \(String(describing: userLocation?.coordinate))")
        do {
            let response: PaginatedResponse<Station> = try await APIClient.shared.request(
                path: "/stations",
                queryItems: queryItems
            )
            self.stations = response.data
            self.isLoading = false
            print("[StationsViewModel] Fetched \(self.stations.count) stations successfully!")
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            print("[StationsViewModel] ERROR fetching stations: \(error.localizedDescription)")
        }
    }

    @MainActor
    func toggleFavorite(station: Station) async {
        struct UpdateStationPayload: Encodable {
            let is_favorite: Bool
        }

        do {
            let payload = UpdateStationPayload(is_favorite: !station.isFavorite)
            let response: APIResponse<Station> = try await APIClient.shared.request(
                path: "/stations/\(station.id)",
                method: "PUT",
                body: payload
            )

            if let idx = stations.firstIndex(where: { $0.id == station.id }) {
                stations[idx] = response.data
            }
            if selectedStation?.id == station.id {
                selectedStation = response.data
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

