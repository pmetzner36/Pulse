import Foundation

/// Mock API responses for development without a backend
/// Set APIClient.useMockMode = true to enable
enum MockAPIClient {
    
    static func mockAuthResponse(for credential: AppleSignInRequest) -> AuthResponse {
        print("🎭 MOCK MODE: Returning mock auth response")
        
        let mockUser = User(
            id: UUID().uuidString,
            appleUserId: "mock_apple_user_\(UUID().uuidString.prefix(8))",
            username: "",  // Empty will trigger username setup flow
            email: credential.email ?? "mock@example.com",
            createdAt: Date(),
            homeCity: nil
        )
        
        return AuthResponse(
            user: mockUser,
            accessToken: "mock_access_token_\(UUID().uuidString)",
            refreshToken: "mock_refresh_token_\(UUID().uuidString)",
            expiresIn: 3600
        )
    }
    
    static func mockUser() -> User {
        print("🎭 MOCK MODE: Returning mock user")
        
        return User(
            id: UUID().uuidString,
            appleUserId: "mock_apple_user_123",
            username: "mockuser",
            email: "mock@example.com",
            createdAt: Date(),
            homeCity: "San Francisco"
        )
    }
    
    static func mockUsernameCheck(username: String) -> UsernameCheckResponse {
        print("🎭 MOCK MODE: Checking username availability for '\(username)'")
        
        // Make some usernames "unavailable" for testing
        let unavailable = ["admin", "test", "user", "mock"]
        let isAvailable = !unavailable.contains(username.lowercased())
        
        return UsernameCheckResponse(
            available: isAvailable,
            suggestion: isAvailable ? nil : "\(username)\(Int.random(in: 100...999))"
        )
    }
    
    static func mockEmptyResponse() {
        print("🎭 MOCK MODE: Empty response")
    }
}
