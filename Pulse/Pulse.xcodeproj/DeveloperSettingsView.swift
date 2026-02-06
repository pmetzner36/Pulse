import SwiftUI

/// Developer settings for debugging and testing
/// Only available in DEBUG builds
struct DeveloperSettingsView: View {
    @AppStorage("UseMockAPI") private var useMockAPI = false
    @State private var showingServerTest = false
    @State private var currentIP = "192.168.1.52"
    
    var body: some View {
        List {
            Section {
                Toggle("Use Mock API (No Backend Required)", isOn: $useMockAPI)
                    .tint(.purple)
                
                if useMockAPI {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Mock mode enabled - Sign in will work without backend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                        Text("Real API mode - Backend must be running")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("API Configuration")
            } footer: {
                Text("Enable mock mode to test the app without a running backend server. Disable to connect to your real API.")
            }
            
            Section("Server Information") {
                LabeledContent("Backend URL") {
                    Text("http://\(currentIP):8000/v1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    showingServerTest = true
                } label: {
                    Label("Test Connection", systemImage: "network.badge.shield.half.filled")
                }
            }
            
            Section("Quick Actions") {
                Button(role: .destructive) {
                    Task {
                        await AuthenticationService.shared.signOut()
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                
                Button {
                    clearAllData()
                } label: {
                    Label("Clear All Local Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
            
            Section("How to Fix Connection Issues") {
                VStack(alignment: .leading, spacing: 12) {
                    StepView(
                        number: 1,
                        title: "Start your backend",
                        description: "Make sure your server is running on port 8000"
                    )
                    
                    StepView(
                        number: 2,
                        title: "Check your Mac's IP",
                        description: "System Settings → Network. Update APIClient.swift if changed."
                    )
                    
                    StepView(
                        number: 3,
                        title: "Same network",
                        description: "Device and Mac must be on the same Wi-Fi"
                    )
                    
                    StepView(
                        number: 4,
                        title: "Or use Mock Mode",
                        description: "Toggle above to test without backend"
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Developer Settings")
        .sheet(isPresented: $showingServerTest) {
            NavigationStack {
                ServerConnectionDebugView()
            }
        }
    }
    
    private func clearAllData() {
        // Clear keychain
        try? KeychainService.shared.deleteTokens()
        
        // Clear user defaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Sign out
        CurrentUser.shared.signOut()
        
        print("🧹 All local data cleared")
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.purple)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
#endif
