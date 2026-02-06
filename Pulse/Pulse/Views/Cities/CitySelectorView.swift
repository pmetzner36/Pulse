import SwiftUI

struct CitySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: UserPreferences

    @State private var searchText = ""

    private var filteredCities: [City] {
        City.cities(matching: searchText)
    }

    private var groupedCities: [(String, [City])] {
        let grouped = Dictionary(grouping: filteredCities) { city in
            String(city.name.prefix(1))
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                // Favorites Section
                if !preferences.favoriteCities.isEmpty && searchText.isEmpty {
                    Section("Favorites") {
                        ForEach(preferences.favoriteCities) { city in
                            cityRow(for: city)
                        }
                    }
                }

                // Recents Section
                if !preferences.recentCities.isEmpty && searchText.isEmpty {
                    Section("Recent") {
                        ForEach(preferences.recentCities) { city in
                            cityRow(for: city)
                        }
                    }
                }

                // All Cities (grouped by first letter when not searching)
                if searchText.isEmpty {
                    ForEach(groupedCities, id: \.0) { letter, cities in
                        Section(letter) {
                            ForEach(cities) { city in
                                cityRow(for: city)
                            }
                        }
                    }
                } else {
                    // Flat list when searching
                    Section("Results") {
                        ForEach(filteredCities) { city in
                            cityRow(for: city)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search cities...")
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cityRow(for city: City) -> some View {
        CityRow(
            city: city,
            isSelected: city.id == preferences.selectedCityId,
            isFavorite: preferences.isFavorite(city),
            onFavoriteToggle: {
                preferences.toggleFavorite(city)
            }
        )
        .onTapGesture {
            preferences.selectCity(city)
            dismiss()
        }
    }
}

#Preview {
    CitySelectorView(preferences: UserPreferences.shared)
}
