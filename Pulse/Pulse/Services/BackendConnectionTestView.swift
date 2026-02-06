import SwiftUI

/// Simple view to test backend connectivity
/// Add this to your app temporarily to debug connection issues
struct BackendConnectionTestView: View {
    @State private var status: ConnectionStatus = .idle
    @State private var errorMessage: String = ""
    @State private var serverURL: String = ""
    
    enum ConnectionStatus {
        case idle
        case testing
        case success
        case failed
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: 60))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.bounce, value: status)
                
                Text(statusText)
                    .font(.title2.bold())
                
                if !serverURL.isEmpty {
                    Text(serverURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            
            // Error message
            if !errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Error Details", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Test button
            Button {
                Task {
                    await testConnection()
                }
            } label: {
                HStack {
                    if status == .testing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(status == .testing ? "Testing..." : "Test Connection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(status == .testing)
            .padding(.horizontal)
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Troubleshooting Checklist:")
                    .font(.headline)
                
                ChecklistItem(
                    text: "Backend server is running",
                    command: "lsof -i :8000"
                )
                
                ChecklistItem(
                    text: "Server listens on 0.0.0.0:8000",
                    command: "python manage.py runserver 0.0.0.0:8000"
                )
                
                ChecklistItem(
                    text: "Mac IP hasn't changed",
                    command: "ipconfig getifaddr en0"
                )
                
                ChecklistItem(
                    text: "Same Wi-Fi network",
                    command: nil
                )
                
                ChecklistItem(
                    text: "Firewall allows connections",
                    command: nil
                )
                
                ChecklistItem(
                    text: "NSAllowsLocalNetworking in Info.plist",
                    command: nil
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Connection Test")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var statusIcon: String {
        switch status {
        case .idle:
            return "network"
        case .testing:
            return "antenna.radiowaves.left.and.right"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle:
            return .gray
        case .testing:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return "Ready to Test"
        case .testing:
            return "Testing Connection..."
        case .success:
            return "Connected ✓"
        case .failed:
            return "Connection Failed"
        }
    }
    
    private func testConnection() async {
        status = .testing
        errorMessage = ""
        serverURL = ""
        
        // Get the current base URL from APIClient
        #if DEBUG
        serverURL = "http://192.168.1.52:8000/v1"
        #else
        serverURL = "https://api.yourapp.com/v1"
        #endif
        
        do {
            // Try to create a simple test request
            guard let url = URL(string: serverURL) else {
                throw NSError(domain: "BackendTest", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid URL: \(serverURL)"
                ])
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.httpMethod = "GET"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    status = .success
                    errorMessage = "✓ Server is reachable\n✓ Status: \(httpResponse.statusCode)"
                } else if httpResponse.statusCode == 404 {
                    // 404 is actually good - means server is there but endpoint doesn't exist
                    status = .success
                    errorMessage = "✓ Server is reachable (returned 404 - endpoint doesn't exist, but connection works!)"
                } else {
                    status = .failed
                    errorMessage = "Server responded with status code: \(httpResponse.statusCode)"
                }
            } else {
                status = .failed
                errorMessage = "Invalid response from server"
            }
            
        } catch let error as URLError {
            status = .failed
            
            switch error.code {
            case .cannotConnectToHost:
                errorMessage = """
                ❌ Cannot connect to host
                
                The server is not reachable. Make sure:
                • Your backend is running
                • It's listening on 0.0.0.0:8000
                • Your firewall allows connections
                """
                
            case .cannotFindHost:
                errorMessage = """
                ❌ Cannot find host
                
                The IP address may be wrong. Check:
                • Your Mac's current IP address
                • Update APIClient.swift if it changed
                """
                
            case .timedOut:
                errorMessage = """
                ❌ Connection timed out
                
                The server is not responding. Check:
                • Your backend is actually running
                • You're on the same Wi-Fi network
                """
                
            case .appTransportSecurityRequiresSecureConnection:
                errorMessage = """
                ❌ App Transport Security blocking
                
                You need to add to Info.plist:
                NSAppTransportSecurity → NSAllowsLocalNetworking = YES
                """
                
            default:
                errorMessage = "Network error: \(error.localizedDescription)\nCode: \(error.code.rawValue)"
            }
            
        } catch {
            status = .failed
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
    }
}

private struct ChecklistItem: View {
    let text: String
    let command: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.purple)
                Text(text)
                    .font(.subheadline)
            }
            
            if let command = command {
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BackendConnectionTestView()
    }
}
