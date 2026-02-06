import Foundation
import AuthenticationServices
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Debug-only logging helper
private func authLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

enum AuthError: Error, LocalizedError {
    case signInFailed(Error)
    case invalidCredentials
    case tokenSaveFailed
    case userNotFound
    case usernameUnavailable
    case invalidUsername
    case userCanceled

    var errorDescription: String? {
        switch self {
        case .signInFailed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .invalidCredentials:
            return "Invalid credentials received from Apple"
        case .tokenSaveFailed:
            return "Failed to save authentication tokens"
        case .userNotFound:
            return "User not found"
        case .usernameUnavailable:
            return "Username is not available"
        case .invalidUsername:
            return "Invalid username format"
        case .userCanceled:
            return "Sign in was canceled"
        }
    }
}

@MainActor
final class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()

    @Published var isSigningIn = false
    @Published var signInError: AuthError?

    private var signInContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    weak var presentationAnchor: ASPresentationAnchor?

    private override init() {
        super.init()
    }

    // MARK: - Apple Sign In

    func signInWithApple() async throws {
        isSigningIn = true
        signInError = nil

        defer { isSigningIn = false }

        do {
            let credential = try await requestAppleCredential()
            try await exchangeAppleCredential(credential)
        } catch {
            let authError = error as? AuthError ?? .signInFailed(error)
            signInError = authError
            throw authError
        }
    }

    private func requestAppleCredential() async throws -> ASAuthorizationAppleIDCredential {
        authLog("🔐 Starting Apple Sign In")

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            controller.performRequests()
        }
    }

    private func exchangeAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        authLog("🔐 Exchanging Apple credential with backend")

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = credential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            authLog("🔐 Failed to extract tokens from credential")
            throw AuthError.invalidCredentials
        }

        var fullName: String? = nil
        if let givenName = credential.fullName?.givenName {
            if let familyName = credential.fullName?.familyName {
                fullName = "\(givenName) \(familyName)"
            } else {
                fullName = givenName
            }
        }

        let request = AppleSignInRequest(
            identityToken: identityToken,
            authorizationCode: authCode,
            fullName: fullName,
            email: credential.email
        )

        let response = try await sendToBackend(request)

        authLog("🔐 Backend exchange successful, saving tokens")

        do {
            try KeychainService.shared.saveTokens(response.toTokens())
        } catch {
            authLog("🔐 Failed to save tokens: \(error)")
            throw AuthError.tokenSaveFailed
        }

        CurrentUser.shared.setUser(response.user)
        authLog("🔐 Sign in complete")
    }

    private func sendToBackend(_ request: AppleSignInRequest) async throws -> AuthResponse {
        do {
            let response: AuthResponse = try await APIClient.shared.request(
                endpoint: "/auth/apple",
                method: .post,
                body: request,
                requiresAuth: false
            )
            return response
        } catch {
            authLog("🔐 Backend exchange failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Dev Sign In (for testing without Apple Sign-In)

    func devSignIn() async throws {
        isSigningIn = true
        signInError = nil

        defer { isSigningIn = false }

        do {
            authLog("🔐 DEV LOGIN: Attempting dev sign in")

            let response: AuthResponse = try await APIClient.shared.request(
                endpoint: "/auth/dev-login",
                method: .post,
                body: Optional<String>.none,
                requiresAuth: false
            )

            try KeychainService.shared.saveTokens(response.toTokens())
            CurrentUser.shared.setUser(response.user)

            authLog("🔐 DEV LOGIN: Success")

        } catch {
            authLog("🔐 DEV LOGIN: Failed - \(error)")
            let authError = AuthError.signInFailed(error)
            signInError = authError
            throw authError
        }
    }

    // MARK: - Session Management

    func restoreSession() async -> Bool {
        guard KeychainService.shared.hasTokens else {
            return false
        }

        CurrentUser.shared.setLoading(true)
        defer { CurrentUser.shared.setLoading(false) }

        do {
            let user: User = try await APIClient.shared.request(
                endpoint: "/users/me",
                method: .get
            )
            CurrentUser.shared.setUser(user)
            return true
        } catch {
            try? KeychainService.shared.deleteTokens()
            return false
        }
    }

    func signOut() async {
        try? await APIClient.shared.requestWithoutResponse(
            endpoint: "/auth/logout",
            method: .post
        )

        try? KeychainService.shared.deleteTokens()
        CurrentUser.shared.signOut()
    }

    // MARK: - Username Management

    func checkUsernameAvailability(_ username: String) async throws -> UsernameCheckResponse {
        let response: UsernameCheckResponse = try await APIClient.shared.request(
            endpoint: "/users/check-username/\(username)",
            method: .get
        )
        return response
    }

    func setUsername(_ username: String) async throws {
        guard isValidUsername(username) else {
            throw AuthError.invalidUsername
        }

        let availability = try await checkUsernameAvailability(username)
        guard availability.available else {
            throw AuthError.usernameUnavailable
        }

        let request = UsernameUpdateRequest(username: username)
        let user: User = try await APIClient.shared.request(
            endpoint: "/users/me/username",
            method: .post,
            body: request
        )

        CurrentUser.shared.updateUsername(user.username)
    }

    private func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authLog("🔐 Credential is not ASAuthorizationAppleIDCredential")
            signInContinuation?.resume(throwing: AuthError.invalidCredentials)
            signInContinuation = nil
            return
        }

        authLog("🔐 Got Apple ID credential for user: \(credential.user)")
        signInContinuation?.resume(returning: credential)
        signInContinuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        authLog("🔐 Authorization failed: \(error)")

        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                signInContinuation?.resume(throwing: AuthError.userCanceled)
            case .invalidResponse:
                signInContinuation?.resume(throwing: AuthError.invalidCredentials)
            case .unknown, .notHandled, .failed:
                signInContinuation?.resume(throwing: AuthError.signInFailed(error))
            @unknown default:
                signInContinuation?.resume(throwing: AuthError.signInFailed(error))
            }
        } else {
            signInContinuation?.resume(throwing: error)
        }
        signInContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {

            if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return window
            } else if let window = windowScene.windows.first {
                return window
            }
        }

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        if let window = UIApplication.shared.windows.first {
            return window
        }

        fatalError("No window available for Sign in with Apple presentation")

        #elseif os(macOS)
        if let window = NSApplication.shared.keyWindow {
            return window
        }

        if let window = NSApplication.shared.mainWindow {
            return window
        }

        if let window = NSApplication.shared.windows.first {
            return window
        }

        fatalError("No window available for Sign in with Apple presentation")

        #else
        fatalError("Sign in with Apple is not supported on this platform")
        #endif
    }
}
