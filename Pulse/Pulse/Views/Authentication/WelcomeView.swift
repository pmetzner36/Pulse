import SwiftUI

struct WelcomeView: View {
    @State private var showSignIn = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 80))
                        .foregroundStyle(.purple)
                        .symbolEffect(.pulse)

                    Text("PULSE")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Feel the city's heartbeat")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Features
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "map.fill",
                        title: "Live Mood Map",
                        description: "See how your city feels in real-time"
                    )

                    FeatureRow(
                        icon: "building.2.fill",
                        title: "50+ Cities",
                        description: "Explore moods across major US cities"
                    )

                    FeatureRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "City Chat",
                        description: "Connect with others in your city"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Get Started button
                Button {
                    showSignIn = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.purple, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)

                // Privacy note
                Text("Your data stays private and anonymous")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView()
}
