import SwiftUI

@main
struct PulseApp: App {
    @State private var currentUser = CurrentUser.shared
    @State private var isCheckingSession = true
    @State private var showUsernameSetup = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    // Loading state while checking session
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 60))
                                .foregroundStyle(.purple)
                                .symbolEffect(.pulse)
                            ProgressView()
                        }
                    }
                } else if currentUser.isSignedIn {
                    // Main app for authenticated users
                    ContentView()
                        .sheet(isPresented: $showUsernameSetup) {
                            UsernameSetupView()
                        }
                        .onChange(of: currentUser.needsUsername) { _, needsUsername in
                            showUsernameSetup = needsUsername
                        }
                        .onAppear {
                            showUsernameSetup = currentUser.needsUsername
                        }
                } else {
                    // Welcome/sign in for unauthenticated users
                    WelcomeView()
                }
            }
            .task {
                await checkSession()
                #if DEBUG
                printDeveloperAccountInfo()
                #endif
            }
            .onChange(of: currentUser.isAuthenticated) { _, _ in
                // Update UI when auth state changes
            }
        }
    }

    private func checkSession() async {
        // Try to restore existing session
        _ = await AuthenticationService.shared.restoreSession()
        isCheckingSession = false
    }
    
    #if DEBUG
    private func printDeveloperAccountInfo() {
        print("🔍 ===== DEVELOPER ACCOUNT CHECK =====")

        if let bundleId = Bundle.main.bundleIdentifier {
            print("🔍 Bundle ID: \(bundleId)")
        } else {
            print("🔍 ⚠️ No Bundle ID found")
        }

        if let entitlements = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.applesignin") {
            print("🔍 ✅ Sign in with Apple entitlement found: \(entitlements)")
        } else {
            print("🔍 ❌ Sign in with Apple entitlement NOT found")
        }

        #if os(iOS)
        let sceneCount = UIApplication.shared.connectedScenes.count
        print("🔍 Connected scenes: \(sceneCount)")
        #endif

        print("🔍 =====================================")
    }
    #endif
}
