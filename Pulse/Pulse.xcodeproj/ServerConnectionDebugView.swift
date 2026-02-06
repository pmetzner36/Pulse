import SwiftUI

/// A debug view to test server connectivity
/// Use this during development to verify your backend is reachable
struct ServerConnectionDebugView: View {
    @State private var isChecking = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var errorMessage: String?
    
    enum ConnectionStatus {
        case unknown
        case connected
        case failed
        case checking
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Server Connection Test")
                .font(.title2)
                .bold()
            
            // Status indicator
            HStack(spacing: 12) {
                statusIcon
                statusText
            }
            .padding()
            .background(statusColor.opacity(0.1))
            .cornerRadius(12)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                Task {
                    await checkConnection()
                }
            } label: {
                HStack {
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isChecking ? "Checking..." : "Test Connection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isChecking)
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips:")
                    .font(.headline)
                
                Text("• Make sure your backend server is running on port 8000")
                Text("• Check that NSAllowsLocalNetworking is enabled in Info.plist")
                Text("• If testing on a device, use your Mac's IP address instead of localhost")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Debug")
    }
    
    private var statusIcon: some View {
        Group {
            switch connectionStatus {
            case .unknown:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.gray)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .checking:
                ProgressView()
            }
        }
        .font(.title)
    }
    
    private var statusText: some View {
        Group {
            switch connectionStatus {
            case .unknown:
                Text("Not tested")
            case .connected:
                Text("Connected ✓")
            case .failed:
                Text("Connection failed")
            case .checking:
                Text("Checking connection...")
            }
        }
        .font(.headline)
    }
    
    private var statusColor: Color {
        switch connectionStatus {
        case .unknown:
            return .gray
        case .connected:
            return .green
        case .failed:
            return .red
        case .checking:
            return .blue
        }
    }
    
    private func checkConnection() async {
        isChecking = true
        connectionStatus = .checking
        errorMessage = nil
        
        do {
            // Try a simple health check endpoint
            let url = URL(string: "http://localhost:8000/v1/health")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                connectionStatus = .connected
                errorMessage = "Server is reachable at http://localhost:8000"
            } else {
                connectionStatus = .failed
                errorMessage = "Server responded with unexpected status"
            }
        } catch let error as URLError {
            connectionStatus = .failed
            
            switch error.code {
            case .cannotConnectToHost:
                errorMessage = "Cannot connect to server. Is it running on port 8000?"
            case .cannotFindHost:
                errorMessage = "Cannot find host. Check your network connection."
            case .timedOut:
                errorMessage = "Connection timed out. Server may be slow or unreachable."
            case .appTransportSecurityRequiresSecureConnection:
                errorMessage = "App Transport Security blocking connection. Add NSAllowsLocalNetworking to Info.plist"
            default:
                errorMessage = "Network error: \(error.localizedDescription)"
            }
        } catch {
            connectionStatus = .failed
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        
        isChecking = false
    }
}

#Preview {
    NavigationStack {
        ServerConnectionDebugView()
    }
}
