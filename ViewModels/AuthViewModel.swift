import Foundation

@Observable
final class AuthViewModel {
    private static let userDefaultsUserKey = "chargebing_cached_user"

    var currentUser: User?
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    init() {
        checkAuthStatus()
    }

    private static func saveUserLocally(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsUserKey)
        }
    }

    private static func loadUserLocally() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsUserKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    private static func clearUserLocally() {
        UserDefaults.standard.removeObject(forKey: userDefaultsUserKey)
    }

    func checkAuthStatus() {
        if let token = KeychainManager.getToken(), !token.isEmpty {
            isAuthenticated = true
            currentUser = Self.loadUserLocally()
            Task {
                await fetchProfile()
            }
        } else {
            isAuthenticated = false
            currentUser = nil
            Self.clearUserLocally()
        }
    }

    @MainActor
    func login(email: String, password: String, deviceName: String = "iPhone (SwiftUI)") async -> Bool {
        isLoading = true
        errorMessage = nil

        struct LoginPayload: Encodable {
            let email: String
            let password: String
            let device_name: String
        }

        do {
            let payload = LoginPayload(email: email, password: password, device_name: deviceName)
            let response: LoginResponse = try await APIClient.shared.request(
                path: "/auth/login",
                method: "POST",
                body: payload,
                requiresAuth: false
            )

            KeychainManager.saveToken(response.token)
            currentUser = response.user
            Self.saveUserLocally(response.user)
            isAuthenticated = true
            isLoading = false
            return true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    @MainActor
    func fetchProfile() async {
        do {
            let response: UserProfileResponse = try await APIClient.shared.request(path: "/me")
            self.currentUser = response.user
            Self.saveUserLocally(response.user)
            self.isAuthenticated = true
        } catch {
            if case APIError.unauthorized = error {
                self.isAuthenticated = false
                self.currentUser = nil
                Self.clearUserLocally()
            }
        }
    }

    @MainActor
    func updateActiveCar(evModelId: Int) async -> Bool {
        struct UpdateCarPayload: Encodable {
            let ev_model_id: Int
        }

        do {
            let payload = UpdateCarPayload(ev_model_id: evModelId)
            let response: UserProfileResponse = try await APIClient.shared.request(
                path: "/me",
                method: "PUT",
                body: payload
            )
            self.currentUser = response.user
            Self.saveUserLocally(response.user)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func updateProfile(
        name: String,
        email: String,
        password: String? = nil,
        evModelId: Int? = nil,
        avatar: String? = nil
    ) async -> (success: Bool, message: String?) {
        isLoading = true
        errorMessage = nil

        struct UpdateProfilePayload: Encodable {
            let name: String
            let email: String
            let password: String?
            let ev_model_id: Int?
            let avatar: String?
        }

        do {
            let trimmedPwd = password?.trimmingCharacters(in: .whitespacesAndNewlines)
            let pwdToSend = (trimmedPwd?.isEmpty ?? true) ? nil : trimmedPwd

            let payload = UpdateProfilePayload(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: pwdToSend,
                ev_model_id: evModelId,
                avatar: avatar
            )

            let response: UserProfileResponse = try await APIClient.shared.request(
                path: "/me",
                method: "PUT",
                body: payload
            )

            self.currentUser = response.user
            Self.saveUserLocally(response.user)
            self.isLoading = false
            return (true, nil)
        } catch let error as APIError {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            return (false, error.localizedDescription)
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            return (false, error.localizedDescription)
        }
    }

    @MainActor
    func logout() async {
        struct EmptyResponse: Decodable {}
        _ = try? await APIClient.shared.request(path: "/auth/logout", method: "POST") as EmptyResponse
        KeychainManager.deleteToken()
        Self.clearUserLocally()
        currentUser = nil
        isAuthenticated = false
    }
}

