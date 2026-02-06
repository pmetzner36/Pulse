import SwiftUI

struct CityRow: View {
    let city: City
    let isSelected: Bool
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(city.name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.purple)
                            .font(.caption)
                    }
                }

                Text(city.stateFullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedPopulation)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                onFavoriteToggle()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var formattedPopulation: String {
        if city.population >= 1_000_000 {
            return String(format: "%.1fM", Double(city.population) / 1_000_000)
        } else {
            return String(format: "%.0fK", Double(city.population) / 1_000)
        }
    }
}

#Preview {
    List {
        CityRow(
            city: City.defaultCity,
            isSelected: true,
            isFavorite: true,
            onFavoriteToggle: {}
        )
        CityRow(
            city: City.allCities[0],
            isSelected: false,
            isFavorite: false,
            onFavoriteToggle: {}
        )
    }
}
