import Foundation

enum AppConfiguration {
    // MARK: - Environment
    
    enum Environment {
        case development
        case staging
        case production
        
        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }
    
    // MARK: - API Configuration
    
    static var apiBaseURL: String {
        switch Environment.current {
        case .development:
            #if targetEnvironment(simulator)
            // Simulator - use localhost
            return "http://localhost:8000/v1"
            #else
            // Physical device - use Railway or local network
            // To use local network: find your Mac's IP with `ipconfig getifaddr en0`
            // return "http://192.168.1.53:8000/v1"
            
            // Or use Railway for physical device testing:
            return railwayURL
            #endif
            
        case .staging:
            return railwayURL
            
        case .production:
            return railwayURL
        }
    }
    
    // MARK: - Railway Configuration
    
    /// Your Railway deployment URL
    /// After deploying to Railway, replace this with your actual URL
    /// Example: "https://pulse-production.up.railway.app/v1"
    private static let railwayURL = "https://pulse-production-82b3.up.railway.app/v1"
    
    // MARK: - Feature Flags
    
    static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var enableDetailedLogging: Bool {
        isDebugMode
    }
}
