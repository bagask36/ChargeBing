import Foundation

@Observable
final class SessionsViewModel {
    var sessions: [ChargingSession] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var modeFilter: String = "ALL" // "ALL", "AC", "DC"

    var totalKwh: Double {
        sessions.reduce(0) { $0 + $1.kwh }
    }

    var totalCost: Double {
        sessions.reduce(0) { $0 + ($1.cost ?? 0) }
    }

    var averageCostPerKwh: Double? {
        guard totalKwh > 0, totalCost > 0 else { return nil }
        return totalCost / totalKwh
    }

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
        odometerKm: Int? = nil,
        distanceKm: Double? = nil,
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
            let odometer_km: Int?
            let distance_km: Double?
            let notes: String?

            enum CodingKeys: String, CodingKey {
                case station_id, connector_id, ev_model_id, charging_mode, started_at, ended_at
                case kwh, cost, soc_start, soc_end, odometer_km, distance_km, notes
            }

            // Kirim null secara eksplisit agar field yang dikosongkan ikut terhapus di server
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(station_id, forKey: .station_id)
                try c.encode(connector_id, forKey: .connector_id)
                try c.encode(ev_model_id, forKey: .ev_model_id)
                try c.encode(charging_mode, forKey: .charging_mode)
                try c.encode(started_at, forKey: .started_at)
                try c.encode(ended_at, forKey: .ended_at)
                try c.encode(kwh, forKey: .kwh)
                try c.encode(cost, forKey: .cost)
                try c.encode(soc_start, forKey: .soc_start)
                try c.encode(soc_end, forKey: .soc_end)
                try c.encode(odometer_km, forKey: .odometer_km)
                try c.encode(distance_km, forKey: .distance_km)
                try c.encode(notes, forKey: .notes)
            }
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
                odometer_km: odometerKm,
                distance_km: distanceKm,
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
    func updateSession(
        id: Int,
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
        odometerKm: Int? = nil,
        distanceKm: Double? = nil,
        notes: String?
    ) async -> ChargingSession? {
        struct UpdateSessionPayload: Encodable {
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
            let odometer_km: Int?
            let distance_km: Double?
            let notes: String?

            enum CodingKeys: String, CodingKey {
                case station_id, connector_id, ev_model_id, charging_mode, started_at, ended_at
                case kwh, cost, soc_start, soc_end, odometer_km, distance_km, notes
            }

            // Kirim null secara eksplisit agar field yang dikosongkan ikut terhapus di server
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(station_id, forKey: .station_id)
                try c.encode(connector_id, forKey: .connector_id)
                try c.encode(ev_model_id, forKey: .ev_model_id)
                try c.encode(charging_mode, forKey: .charging_mode)
                try c.encode(started_at, forKey: .started_at)
                try c.encode(ended_at, forKey: .ended_at)
                try c.encode(kwh, forKey: .kwh)
                try c.encode(cost, forKey: .cost)
                try c.encode(soc_start, forKey: .soc_start)
                try c.encode(soc_end, forKey: .soc_end)
                try c.encode(odometer_km, forKey: .odometer_km)
                try c.encode(distance_km, forKey: .distance_km)
                try c.encode(notes, forKey: .notes)
            }
        }

        do {
            let payload = UpdateSessionPayload(
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
                odometer_km: odometerKm,
                distance_km: distanceKm,
                notes: notes
            )

            let response: APIResponse<ChargingSession> = try await APIClient.shared.request(
                path: "/charging-sessions/\(id)",
                method: "PUT",
                body: payload
            )

            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx] = response.data
            }
            return response.data
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
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

