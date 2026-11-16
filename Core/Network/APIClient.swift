import Foundation

final class APIClient: Sendable {
    static let shared = APIClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: Config.baseURL + path) else {
            throw APIError.invalidURL
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = KeychainManager.getToken(), !token.isEmpty else {
                throw APIError.unauthorized
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            do {
                urlRequest.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.networkError(error)
            }
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try jsonDecoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        case 401:
            KeychainManager.deleteToken()
            throw APIError.unauthorized

        case 422:
            if let validationObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = validationObj["message"] as? String {
                let errors = validationObj["errors"] as? [String: [String]] ?? [:]
                throw APIError.validationError(message: message, errors: errors)
            }
            throw APIError.serverError(statusCode: 422, message: "Validasi form gagal.")

        case 429:
            throw APIError.rateLimited

        default:
            let serverMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "Terjadi kesalahan pada server."
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: serverMsg)
        }
    }
}

