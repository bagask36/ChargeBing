import Foundation

enum Config {
    #if targetEnvironment(simulator)
    // Default URL for iOS Simulator
    static let defaultBaseURL = "http://127.0.0.1:8080/api/v1"
    #else
    // Default URL for Physical iPhone (Mac local IP: 192.168.1.23)
    static let defaultBaseURL = "http://192.168.1.23:8080/api/v1"
    #endif

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

