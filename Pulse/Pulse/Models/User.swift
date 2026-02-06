import Foundation

struct User: Codable, Identifiable {
    let id: String
    let appleUserId: String
    var username: String
    let email: String?
    let createdAt: Date
    var homeCity: String?

    var hasUsername: Bool {
        !username.isEmpty && username != "user"
    }
}

// MARK: - Current User Singleton
@MainActor
@Observable
final class CurrentUser {
    static let shared = CurrentUser()

    private(set) var user: User?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var needsUsername = false

    private init() {}

    var isSignedIn: Bool {
        isAuthenticated && user != nil
    }

    var displayName: String {
        user?.username ?? "Guest"
    }

    func setUser(_ user: User) {
        self.user = user
        self.isAuthenticated = true
        self.needsUsername = !user.hasUsername
    }

    func updateUsername(_ username: String) {
        user?.username = username
        needsUsername = false
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    func signOut() {
        user = nil
        isAuthenticated = false
        needsUsername = false
    }
}

// MARK: - Auth Tokens
struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }

    var needsRefresh: Bool {
        // Refresh if less than 5 minutes until expiry
        Date().addingTimeInterval(300) >= expiresAt
    }
}

// MARK: - API Response Models
struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    func toTokens() -> AuthTokens {
        AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

struct UsernameCheckResponse: Codable {
    let available: Bool
    let suggestion: String?
}

struct UsernameUpdateRequest: Codable {
    let username: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
    let email: String?
}
