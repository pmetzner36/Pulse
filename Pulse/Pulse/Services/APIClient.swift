import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .noData:
            return "No data received"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    // API base URL from configuration
    private let baseURL: String = AppConfiguration.apiBaseURL

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // Try to decode as string first (ISO8601)
            if let dateString = try? container.decode(String.self) {
                // Try ISO8601 with fractional seconds
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                // Try ISO8601 without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                // Try custom format: "2024-02-05 10:30:45"
                let customFormatter = DateFormatter()
                customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = customFormatter.date(from: dateString) {
                    return date
                }
                
                // Try another common format: "2024-02-05T10:30:45.123456"
                customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                if let date = customFormatter.date(from: dateString) {
                    return date
                }
            }
            
            // Try to decode as timestamp (number)
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(container)"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Public Methods

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if required
        if requiresAuth {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        // Perform request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // More specific network error handling
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cannotConnectToHost, .cannotFindHost:
                    throw APIError.networkError(NSError(
                        domain: "APIClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Could not connect to server. Please check your network connection and ensure the server is running."]
                    ))
                case .timedOut:
                    throw APIError.networkError(NSError(
                        domain: "APIClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."]
                    ))
                default:
                    throw APIError.networkError(error)
                }
            }
            throw APIError.networkError(error)
        }

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle HTTP errors
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse?.displayMessage)
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Debug: Print raw response data
            #if DEBUG
            print("🔍 DECODING ERROR - Raw response:")
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            print("🔍 Error: \(error)")
            #endif
            throw APIError.decodingError(error)
        }
    }

    func requestWithoutResponse(
        endpoint: String,
        method: HTTPMethod = .post,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws {
        let url = try buildURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            let token = try await getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse?.displayMessage)
        }
    }

    // MARK: - Private Methods

    private func buildURL(endpoint: String) throws -> URL {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func getValidAccessToken() async throws -> String {
        let keychain = KeychainService.shared

        guard let tokens = try? keychain.loadTokens() else {
            throw APIError.unauthorized
        }

        // If token needs refresh, refresh it
        if tokens.needsRefresh {
            let newTokens = try await refreshTokens(using: tokens.refreshToken)
            try keychain.saveTokens(newTokens)
            return newTokens.accessToken
        }

        return tokens.accessToken
    }

    private func refreshTokens(using refreshToken: String) async throws -> AuthTokens {
        let url = try buildURL(endpoint: "/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RefreshTokenRequest(refreshToken: refreshToken)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.unauthorized
        }

        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        return authResponse.toTokens()
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct ErrorResponse: Decodable {
    let message: String?
    let error: String?
    let detail: String?  // FastAPI uses "detail" for error messages

    var displayMessage: String? {
        detail ?? message ?? error
    }
}

struct EmptyResponse: Decodable {}
