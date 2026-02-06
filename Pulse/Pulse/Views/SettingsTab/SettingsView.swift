import SwiftUI

struct SettingsView: View {
    @Bindable private var preferences = UserPreferences.shared
    @State private var currentUser = CurrentUser.shared
    @State private var showingPrivacy = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showingCitySelector = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            List {
                // Account Section (if signed in)
                if currentUser.isSignedIn {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.purple)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(currentUser.displayName)")
                                    .font(.headline)
                                if let email = currentUser.user?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            showingSignOutConfirmation = true
                        } label: {
                            HStack {
                                if isSigningOut {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text("Sign Out")
                            }
                        }
                        .disabled(isSigningOut)
                    } header: {
                        Text("Account")
                    }
                }

                // City Section
                Section {
                    Button {
                        showingCitySelector = true
                    } label: {
                        HStack {
                            SettingRow(
                                icon: "building.2.fill",
                                iconColor: .indigo,
                                title: "Current City",
                                subtitle: preferences.selectedCity.displayName
                            )
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Location")
                }

                // Contribution Section
                Section {
                    Toggle(isOn: $preferences.contributeLocation) {
                        SettingRow(
                            icon: "location.fill",
                            iconColor: .blue,
                            title: "Share Location",
                            subtitle: "City-level only, never precise"
                        )
                    }
                    .tint(.purple)

                    Toggle(isOn: $preferences.contributeMotion) {
                        SettingRow(
                            icon: "figure.walk",
                            iconColor: .green,
                            title: "Share Activity",
                            subtitle: "Processed on your device"
                        )
                    }
                    .tint(.purple)
                } header: {
                    Text("Contribute to City Mood")
                } footer: {
                    Text("Your data is anonymized and aggregated with at least 30 other people before being shown.")
                }

                // Display Section
                Section("Display") {
                    Picker("Default Time Window", selection: $preferences.timeWindow) {
                        ForEach(TimeWindow.allCases, id: \.self) { window in
                            Text(window.displayName).tag(window)
                        }
                    }

                    Toggle(isOn: $preferences.showMeVsCity) {
                        SettingRow(
                            icon: "person.2.fill",
                            iconColor: .purple,
                            title: "Show Me vs City",
                            subtitle: "Compare your mood to the city"
                        )
                    }
                    .tint(.purple)
                }

                // Privacy Section
                Section {
                    Button {
                        showingPrivacy = true
                    } label: {
                        SettingRow(
                            icon: "hand.raised.fill",
                            iconColor: .orange,
                            title: "Privacy & Data",
                            subtitle: "Learn how we protect you"
                        )
                    }
                    .foregroundColor(.primary)

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        SettingRow(
                            icon: "trash.fill",
                            iconColor: .red,
                            title: "Delete My Data",
                            subtitle: "Remove all your contributions"
                        )
                    }
                } header: {
                    Text("Privacy")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://pulse-app.example.com")!) {
                        HStack {
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("About")
                } footer: {
                    VStack(spacing: 8) {
                        Text("PULSE shows aggregated mood trends based on anonymous activity patterns.")
                        Text("This is not medical advice.")
                            .fontWeight(.medium)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPrivacy) {
                PrivacyView()
            }
            .alert("Delete Your Data?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Handle deletion
                }
            } message: {
                Text("This will permanently remove all your contributed mood data. This action cannot be undone.")
            }
            .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("You'll need to sign in again to access chat and sync your preferences.")
            }
            .sheet(isPresented: $showingCitySelector) {
                CitySelectorView(preferences: preferences)
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        Task {
            await AuthenticationService.shared.signOut()
            isSigningOut = false
        }
    }
}

// MARK: - Setting Row
struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Privacy View
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)

                        Text("Your Privacy Matters")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("PULSE is designed with privacy at its core")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)

                    // Privacy Features
                    VStack(spacing: 16) {
                        PrivacyFeature(
                            icon: "cpu",
                            title: "On-Device Processing",
                            description: "All mood calculations happen locally. Raw sensor data never leaves your phone."
                        )

                        PrivacyFeature(
                            icon: "location.slash",
                            title: "No Precise Location",
                            description: "We only use city-block level areas. Your exact address is never collected."
                        )

                        PrivacyFeature(
                            icon: "person.3.fill",
                            title: "k-Anonymity",
                            description: "Data is only shown when 30+ people contribute, making individuals unidentifiable."
                        )

                        PrivacyFeature(
                            icon: "eye.slash",
                            title: "No Personal Info",
                            description: "No names, emails, or accounts. Contributions are completely anonymous."
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct PrivacyFeature: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 44, height: 44)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    SettingsView()
}
