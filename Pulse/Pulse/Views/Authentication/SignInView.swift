import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var authService = AuthenticationService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)

                    Text("Sign In")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Create your account to access city chat and sync your preferences across devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Sign In Buttons
                VStack(spacing: 16) {
                    // Apple Sign In Button
                    Button {
                        Task {
                            await signIn()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                            Text("Sign in with Apple")
                                .font(.headline)
                        }
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(colorScheme == .dark ? .white : .black, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(authService.isSigningIn)

                    #if DEBUG
                    // Dev Sign In Button (for testing)
                    Button {
                        Task {
                            await devSignIn()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .font(.title3)
                            Text("Dev Sign In (Testing)")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(authService.isSigningIn)
                    #endif

                    // Loading overlay
                    if authService.isSigningIn {
                        ProgressView("Signing in...")
                            .padding()
                    }

                    // Error message
                    if let error = authService.signInError, !isUserCancellation(error) {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                // Terms
                VStack(spacing: 8) {
                    Text("By signing in, you agree to our")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Button("Terms of Service") {
                            // TODO: Open terms
                        }
                        .font(.caption)

                        Text("and")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Privacy Policy") {
                            // TODO: Open privacy policy
                        }
                        .font(.caption)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func signIn() async {
        do {
            try await authService.signInWithApple()
            dismiss()
        } catch {
            // Error is already set in authService
            // Don't show alerts for user cancellation
        }
    }

    private func devSignIn() async {
        do {
            try await authService.devSignIn()
            dismiss()
        } catch {
            // Error is already set in authService
        }
    }

    private func isUserCancellation(_ error: AuthError) -> Bool {
        if case .userCanceled = error {
            return true
        }
        return false
    }
}

#Preview {
    SignInView()
}
