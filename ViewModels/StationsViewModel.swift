import Foundation
import CoreLocation

@Observable
final class StationsViewModel {
    private static var cachedStations: [Station] = []

    var allStations: [Station] = []
    var selectedStation: Station?
    var isLoading: Bool = false
    var errorMessage: String?

    var searchText: String = ""
    var filterCurrentType: String = "ALL" // "ALL", "AC", "DC"
    var usableOnly: Bool = false // Only GB/T native or adapter_ok

    init() {
        if !Self.cachedStations.isEmpty {
            self.allStations = Self.cachedStations
        }
    }

    var stations: [Station] {
        var result = allStations

        // 1. Filter by Current Type (AC / DC)
        if filterCurrentType != "ALL" {
            result = result.filter { station in
                station.connectors?.contains { conn in
                    conn.currentType.uppercased() == filterCurrentType
                } ?? false
            }
        }

        // 2. Filter by GB/T Compatibility
        if usableOnly {
            result = result.filter { station in
                station.gbtStatus == .native || station.gbtStatus == .adapterOk
            }
        }

        // 3. Filter by Search Query
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter { station in
                station.name.localizedCaseInsensitiveContains(query) ||
                (station.operatorName?.localizedCaseInsensitiveContains(query) ?? false) ||
                (station.address?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        return result
    }

    @MainActor
    func fetchStations(userLocation: CLLocation? = nil, forceRefresh: Bool = false) async {
        // Hanya muat jika data belum ada atau pengguna secara eksplisit menekan refresh
        if !allStations.isEmpty && !forceRefresh {
            return
        }

        isLoading = true
        errorMessage = nil

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: "100")
        ]

        if let loc = userLocation {
            queryItems.append(URLQueryItem(name: "lat", value: String(loc.coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: String(loc.coordinate.longitude)))
        }

        print("[StationsViewModel] fetchStations (forceRefresh: \(forceRefresh)) with userLocation: \(String(describing: userLocation?.coordinate))")
        do {
            let response: PaginatedResponse<Station> = try await APIClient.shared.request(
                path: "/stations",
                queryItems: queryItems
            )
            self.allStations = response.data
            Self.cachedStations = response.data
            self.isLoading = false
            print("[StationsViewModel] Fetched \(self.allStations.count) stations successfully!")
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

            if let idx = allStations.firstIndex(where: { $0.id == station.id }) {
                allStations[idx] = response.data
            }
            if let idx = Self.cachedStations.firstIndex(where: { $0.id == station.id }) {
                Self.cachedStations[idx] = response.data
            }
            if selectedStation?.id == station.id {
                selectedStation = response.data
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

