import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case validationError(message: String, errors: [String: [String]])
    case rateLimited
    case decodingError(Error)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL tidak valid."
        case .unauthorized:
            return "Sesi login telah berakhir. Silakan login kembali."
        case .serverError(let code, let message):
            return "Error Server (\(code)): \(message)"
        case .validationError(let message, let errors):
            if let firstField = errors.keys.first, let firstErr = errors[firstField]?.first {
                return firstErr
            }
            return message
        case .rateLimited:
            return "Terlalu banyak request. Harap tunggu beberapa saat."
        case .decodingError(let error):
            return "Gagal memproses data server: \(error.localizedDescription)"
        case .networkError(let error):
            return "Koneksi jaringan bermasalah: \(error.localizedDescription)"
        case .unknown:
            return "Terjadi kesalahan yang tidak diketahui."
        }
    }
}

