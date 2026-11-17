import Foundation
import CoreLocation

// MARK: - Generic API Wrappers
struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let message: String?
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let data: [T]
    let meta: PaginationMeta?
}

struct PaginationMeta: Decodable {
    let currentPage: Int?
    let lastPage: Int?
    let perPage: Int?
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total
    }
}

// MARK: - User & Auth
struct LoginResponse: Decodable {
    let message: String
    let token: String
    let tokenType: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case message, token
        case tokenType = "token_type"
        case user
    }
}

struct UserProfileResponse: Decodable {
    let user: User
}

struct User: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
    let email: String
    let evModelId: Int?
    let evModel: EvModel?

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case evModelId = "ev_model_id"
        case evModel = "ev_model"
    }
}

// MARK: - Master EV Model (Mobil Listrik)
struct EvModel: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let brand: String
    let modelName: String
    let variant: String?
    let fullName: String
    let batteryCapacityKwh: Double
    let rangeKm: Int
    let acPlugType: String
    let dcPlugType: String?
    let hasDc: Bool
    let maxAcKw: Double?
    let maxDcKw: Double?
    let isActive: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, brand
        case modelName = "model_name"
        case variant
        case fullName = "full_name"
        case batteryCapacityKwh = "battery_capacity_kwh"
        case rangeKm = "range_km"
        case acPlugType = "ac_plug_type"
        case dcPlugType = "dc_plug_type"
        case hasDc = "has_dc"
        case maxAcKw = "max_ac_kw"
        case maxDcKw = "max_dc_kw"
        case isActive = "is_active"
        case notes
    }
}

// MARK: - Master Charging App (Aplikasi Operator SPKLU)
struct ChargingApp: Identifiable, Decodable, Hashable, Sendable {
    let id: Int?
    let name: String
    let schemeUrl: String?
    let appStoreUrl: String?
    let playStoreUrl: String?
    let iconUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case schemeUrl = "scheme_url"
        case appStoreUrl = "app_store_url"
        case playStoreUrl = "play_store_url"
        case iconUrl = "icon_url"
    }
}

struct ChargingAppMaster {
    static let plnMobile = ChargingApp(
        id: 1,
        name: "PLN Mobile",
        schemeUrl: "plnmobile://",
        appStoreUrl: "https://apps.apple.com/id/app/pln-mobile/id1296796967",
        playStoreUrl: "https://play.google.com/store/apps/details?id=com.icon.pln123",
        iconUrl: nil
    )

    static let voltron = ChargingApp(
        id: 2,
        name: "Voltron",
        schemeUrl: "voltron://",
        appStoreUrl: "https://apps.apple.com/id/app/voltron-charging-network/id1661633596",
        playStoreUrl: "https://play.google.com/store/apps/details?id=com.voltron.ev",
        iconUrl: nil
    )

    static let eCharge = ChargingApp(
        id: 3,
        name: "E Charge International",
        schemeUrl: "echarge://",
        appStoreUrl: "https://apps.apple.com/id/app/e-charge-international/id1666838321",
        playStoreUrl: "https://play.google.com/store/apps/details?id=com.echarge.international",
        iconUrl: nil
    )

    static let terraCharge = ChargingApp(
        id: 4,
        name: "Terra Charge",
        schemeUrl: "terracharge://",
        appStoreUrl: "https://apps.apple.com/id/app/terra-charge/id6444062492",
        playStoreUrl: "https://play.google.com/store/apps/details?id=jp.co.terramotors.terracharge",
        iconUrl: nil
    )

    static let allMasters: [ChargingApp] = [plnMobile, voltron, eCharge, terraCharge]

    /// Pencocokan cerdas jika backend hanya mengirimkan nama operator / stasiun
    static func match(by text: String?) -> ChargingApp? {
        guard let raw = text?.lowercased() else { return nil }
        if raw.contains("pln") { return plnMobile }
        if raw.contains("voltron") { return voltron }
        if raw.contains("e charge") || raw.contains("echarge") || raw.contains("e-charge") { return eCharge }
        if raw.contains("terra") { return terraCharge }
        return nil
    }
}

// MARK: - Station (SPKLU)
struct Station: Identifiable, Decodable, Hashable, Sendable {
    let id: Int
    let name: String
    let operatorName: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let pricingNote: String?
    let openingHours: String?
    let notes: String?
    var isFavorite: Bool
    let distanceKm: Double?
    let connectors: [Connector]?

    // Mastering aplikasi charging dari backend
    let chargingApp: ChargingApp?
    let appName: String?
    let appSchemeUrl: String?
    let appStoreUrl: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, notes
        case operatorName = "operator"
        case pricingNote = "pricing_note"
        case openingHours = "opening_hours"
        case isFavorite = "is_favorite"
        case distanceKm = "distance_km"
        case connectors
        case chargingApp = "charging_app"
        case appName = "app_name"
        case appSchemeUrl = "app_scheme_url"
        case appStoreUrl = "app_store_url"
    }

    /// Mengambil konfigurasi aplikasi charging:
    /// 1. Prioritas utama: Object `charging_app` dari backend
    /// 2. Prioritas kedua: Direct field `app_scheme_url` / `app_name`
    /// 3. Fallback: Cocokkan otomatis dari nama operator atau nama stasiun ke master charging apps
    var resolvedChargingApp: ChargingApp? {
        if let app = chargingApp {
            return app
        }
        if let scheme = appSchemeUrl, !scheme.isEmpty {
            return ChargingApp(
                id: nil,
                name: appName ?? operatorName ?? "Aplikasi Charging",
                schemeUrl: scheme,
                appStoreUrl: appStoreUrl,
                playStoreUrl: nil,
                iconUrl: nil
            )
        }
        return ChargingAppMaster.match(by: operatorName) ?? ChargingAppMaster.match(by: name)
    }

    // GB/T Pin Color Logic
    var gbtStatus: GBTCompatibilitySummary {
        let list = connectors ?? []
        let hasNative = list.contains { $0.compatStatus == "native" }
        let hasAdapter = list.contains { $0.compatStatus == "adapter_ok" }
        let hasUntested = list.contains { $0.compatStatus == "untested" }

        if hasNative { return .native }
        if hasAdapter { return .adapterOk }
        if hasUntested { return .untested }
        return .incompatible
    }
}

enum GBTCompatibilitySummary: String {
    case native
    case adapterOk
    case untested
    case incompatible

    var title: String {
        switch self {
        case .native: return "GB/T Native (Langsung Colok)"
        case .adapterOk: return "Adaptor OK"
        case .untested: return "Belum Dites"
        case .incompatible: return "Tidak Kompatibel"
        }
    }
}

// MARK: - Connector
struct Connector: Identifiable, Decodable, Hashable, Sendable {
    let id: Int
    let stationId: Int?
    let currentType: String
    let plugType: String
    let powerKw: Double
    let unitCount: Int
    let compatStatus: String
    let adapterNote: String?
    let lastTestedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case stationId = "station_id"
        case currentType = "current_type"
        case plugType = "plug_type"
        case powerKw = "power_kw"
        case unitCount = "unit_count"
        case compatStatus = "compat_status"
        case adapterNote = "adapter_note"
        case lastTestedAt = "last_tested_at"
    }

    var isGbtDirect: Bool {
        plugType == "GBT" && compatStatus == "native"
    }
}

// MARK: - Charging Session
struct ChargingSession: Identifiable, Decodable, Sendable {
    let id: Int
    let stationId: Int
    let connectorId: Int?
    let evModelId: Int?
    let chargingMode: String
    let startedAt: String
    let endedAt: String?
    let kwh: Double
    let cost: Double?
    let socStart: Int?
    let socEnd: Int?
    let notes: String?
    let station: Station?
    let connector: Connector?
    let evModel: EvModel?

    enum CodingKeys: String, CodingKey {
        case id, kwh, cost, notes, station, connector
        case stationId = "station_id"
        case connectorId = "connector_id"
        case evModelId = "ev_model_id"
        case chargingMode = "charging_mode"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case socStart = "soc_start"
        case socEnd = "soc_end"
        case evModel = "ev_model"
    }
}

// MARK: - Statistics Summary
struct StatsSummary: Decodable, Sendable {
    let allTime: TimeStats
    let currentMonth: MonthStats
    let monthly: [MonthStats]?

    enum CodingKeys: String, CodingKey {
        case allTime = "all_time"
        case currentMonth = "current_month"
        case monthly
    }
}

struct TimeStats: Decodable, Sendable {
    let totalSessions: Int
    let totalKwh: Double
    let totalCost: Double
    let ac: ModeStats
    let dc: ModeStats

    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case totalKwh = "total_kwh"
        case totalCost = "total_cost"
        case ac, dc
    }
}

struct MonthStats: Decodable, Sendable {
    let month: String?
    let totalSessions: Int
    let totalKwh: Double
    let totalCost: Double
    let ac: ModeStats
    let dc: ModeStats

    enum CodingKeys: String, CodingKey {
        case month
        case totalSessions = "total_sessions"
        case totalKwh = "total_kwh"
        case totalCost = "total_cost"
        case ac, dc
    }
}

struct ModeStats: Decodable, Sendable {
    let sessions: Int
    let kwh: Double
    let cost: Double
}

