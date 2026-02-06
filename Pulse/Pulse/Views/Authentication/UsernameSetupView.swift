import SwiftUI

struct UsernameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool? = nil
    @State private var suggestion: String? = nil
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var isValidFormat: Bool {
        let pattern = "^[a-zA-Z0-9_]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }

    private var canSave: Bool {
        isValidFormat && isAvailable == true && !isSaving
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "at.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(.purple)

                    Text("Choose Your Username")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This is how others will see you in chat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Username input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("@")
                            .foregroundStyle(.secondary)
                            .font(.title3)

                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.title3)
                            .onChange(of: username) { _, newValue in
                                // Reset state when typing
                                isAvailable = nil
                                suggestion = nil
                                errorMessage = nil
                            }

                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let available = isAvailable {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(available ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    // Validation messages
                    if username.count > 0 && username.count < 3 {
                        Text("Username must be at least 3 characters")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if username.count > 20 {
                        Text("Username must be 20 characters or less")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if !username.isEmpty && !isValidFormat {
                        Text("Only letters, numbers, and underscores allowed")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if isAvailable == false {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Username is taken")
                                .font(.caption)
                                .foregroundStyle(.red)

                            if let suggestion = suggestion {
                                Button {
                                    username = suggestion
                                    checkAvailability()
                                } label: {
                                    Text("Try \(suggestion)?")
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)

                // Check button
                if isValidFormat && isAvailable == nil {
                    Button("Check Availability") {
                        checkAvailability()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                // Continue button
                Button {
                    saveUsername()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Continue")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? .purple : .gray, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSave)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    private func checkAvailability() {
        guard isValidFormat else { return }

        isChecking = true

        Task {
            do {
                let response = try await AuthenticationService.shared.checkUsernameAvailability(username)
                isAvailable = response.available
                suggestion = response.suggestion
            } catch {
                errorMessage = "Could not check availability"
            }
            isChecking = false
        }
    }

    private func saveUsername() {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await AuthenticationService.shared.setUsername(username)
                dismiss()
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Failed to save username"
            }
            isSaving = false
        }
    }
}

#Preview {
    UsernameSetupView()
}
