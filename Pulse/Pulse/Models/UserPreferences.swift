import Foundation
import SwiftUI

@MainActor
@Observable
final class UserPreferences {
    static let shared = UserPreferences()

    var contributeLocation = true
    var contributeMotion = true
    var timeWindow: TimeWindow = .oneHour
    var showMeVsCity = false

    // City preferences
    var selectedCityId: String = City.defaultCity.id
    var favoriteCityIds: [String] = []
    var recentCityIds: [String] = []

    var selectedCity: City {
        City.city(byId: selectedCityId) ?? City.defaultCity
    }

    var favoriteCities: [City] {
        favoriteCityIds.compactMap { City.city(byId: $0) }
    }

    var recentCities: [City] {
        recentCityIds.compactMap { City.city(byId: $0) }
    }

    private init() {
        // Load from UserDefaults
        contributeLocation = UserDefaults.standard.bool(forKey: "contributeLocation")
        contributeMotion = UserDefaults.standard.bool(forKey: "contributeMotion")
        showMeVsCity = UserDefaults.standard.bool(forKey: "showMeVsCity")
        if let raw = UserDefaults.standard.string(forKey: "timeWindow"),
           let window = TimeWindow(rawValue: raw) {
            timeWindow = window
        }

        // Load city preferences
        if let cityId = UserDefaults.standard.string(forKey: "selectedCityId") {
            selectedCityId = cityId
        }
        if let favorites = UserDefaults.standard.stringArray(forKey: "favoriteCityIds") {
            favoriteCityIds = favorites
        }
        if let recents = UserDefaults.standard.stringArray(forKey: "recentCityIds") {
            recentCityIds = recents
        }

        // Set defaults if first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            contributeLocation = true
            contributeMotion = true
            UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }

    func save() {
        UserDefaults.standard.set(contributeLocation, forKey: "contributeLocation")
        UserDefaults.standard.set(contributeMotion, forKey: "contributeMotion")
        UserDefaults.standard.set(showMeVsCity, forKey: "showMeVsCity")
        UserDefaults.standard.set(timeWindow.rawValue, forKey: "timeWindow")
        UserDefaults.standard.set(selectedCityId, forKey: "selectedCityId")
        UserDefaults.standard.set(favoriteCityIds, forKey: "favoriteCityIds")
        UserDefaults.standard.set(recentCityIds, forKey: "recentCityIds")
    }

    // MARK: - City Management

    func selectCity(_ city: City) {
        selectedCityId = city.id
        addToRecents(city)
        save()
    }

    func toggleFavorite(_ city: City) {
        if favoriteCityIds.contains(city.id) {
            favoriteCityIds.removeAll { $0 == city.id }
        } else {
            favoriteCityIds.append(city.id)
        }
        save()
    }

    func isFavorite(_ city: City) -> Bool {
        favoriteCityIds.contains(city.id)
    }

    private func addToRecents(_ city: City) {
        recentCityIds.removeAll { $0 == city.id }
        recentCityIds.insert(city.id, at: 0)
        if recentCityIds.count > 5 {
            recentCityIds = Array(recentCityIds.prefix(5))
        }
    }
}
