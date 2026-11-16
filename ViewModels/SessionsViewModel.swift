import Foundation

@Observable
final class SessionsViewModel {
    var sessions: [ChargingSession] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var modeFilter: String = "ALL" // "ALL", "AC", "DC"

    @MainActor
    func fetchSessions() async {
        isLoading = true
        errorMessage = nil

        var queryItems: [URLQueryItem] = []
        if modeFilter != "ALL" {
            queryItems.append(URLQueryItem(name: "charging_mode", value: modeFilter))
        }

        do {
            let response: PaginatedResponse<ChargingSession> = try await APIClient.shared.request(
                path: "/charging-sessions",
                queryItems: queryItems
            )
            self.sessions = response.data
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    @MainActor
    func createSession(
        stationId: Int,
        connectorId: Int?,
        evModelId: Int?,
        chargingMode: String,
        startedAt: String,
        endedAt: String?,
        kwh: Double,
        cost: Double?,
        socStart: Int?,
        socEnd: Int?,
        notes: String?
    ) async -> Bool {
        struct CreateSessionPayload: Encodable {
            let station_id: Int
            let connector_id: Int?
            let ev_model_id: Int?
            let charging_mode: String
            let started_at: String
            let ended_at: String?
            let kwh: Double
            let cost: Double?
            let soc_start: Int?
            let soc_end: Int?
            let notes: String?
        }

        do {
            let payload = CreateSessionPayload(
                station_id: stationId,
                connector_id: connectorId,
                ev_model_id: evModelId,
                charging_mode: chargingMode,
                started_at: startedAt,
                ended_at: endedAt,
                kwh: kwh,
                cost: cost,
                soc_start: socStart,
                soc_end: socEnd,
                notes: notes
            )

            let _: APIResponse<ChargingSession> = try await APIClient.shared.request(
                path: "/charging-sessions",
                method: "POST",
                body: payload
            )

            await fetchSessions()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func deleteSession(id: Int) async -> Bool {
        struct MessageResponse: Decodable {
            let message: String
        }

        do {
            let _: MessageResponse = try await APIClient.shared.request(
                path: "/charging-sessions/\(id)",
                method: "DELETE"
            )
            sessions.removeAll { $0.id == id }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}

