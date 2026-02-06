import Foundation
import CoreLocation

@MainActor
@Observable
final class LocationService: NSObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    private(set) var currentLocation: CLLocation?
    private(set) var currentCity: City?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isLocating = false
    private(set) var error: String?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func detectCurrentCity() async -> City? {
        error = nil
        isLocating = true
        defer { isLocating = false }
        
        // Check authorization
        if authorizationStatus == .notDetermined {
            requestPermission()
            // Wait a moment for user to respond
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            error = "Location permission required"
            return nil
        }
        
        do {
            let location = try await getCurrentLocation()
            currentLocation = location

            // Find nearest city
            let nearestCity = findNearestCity(to: location)
            currentCity = nearestCity

            // Note: We no longer auto-change the user's selected city
            // The ChatView will show a banner letting them choose to switch

            return nearestCity
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    private func findNearestCity(to location: CLLocation) -> City? {
        var nearestCity: City?
        var shortestDistance: CLLocationDistance = .infinity
        
        for city in City.allCities {
            let cityLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)
            let distance = location.distance(from: cityLocation)
            
            if distance < shortestDistance {
                shortestDistance = distance
                nearestCity = city
            }
        }
        
        return nearestCity
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
}
