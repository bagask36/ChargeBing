import Foundation

enum Config {
    // Production URL (Cloudflare Tunnel)
    static let defaultBaseURL = "https://chargebing.mhswmr.net/api/v1"

    private static let baseURLKey = "chargebing_custom_base_url"

    static var baseURL: String {
        get {
            UserDefaults.standard.string(forKey: baseURLKey) ?? defaultBaseURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: baseURLKey)
        }
    }
}

