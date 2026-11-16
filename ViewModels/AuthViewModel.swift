import Foundation

@Observable
final class AuthViewModel {
    var currentUser: User?
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if let token = KeychainManager.getToken(), !token.isEmpty {
            isAuthenticated = true
            Task {
                await fetchProfile()
            }
        } else {
            isAuthenticated = false
            currentUser = nil
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
            self.isAuthenticated = true
        } catch {
            if case APIError.unauthorized = error {
                self.isAuthenticated = false
                self.currentUser = nil
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
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func logout() async {
        struct EmptyResponse: Decodable {}
        _ = try? await APIClient.shared.request(path: "/auth/logout", method: "POST") as EmptyResponse
        KeychainManager.deleteToken()
        currentUser = nil
        isAuthenticated = false
    }
}

