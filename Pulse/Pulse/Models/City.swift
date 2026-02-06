import Foundation

struct City: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let state: String
    let stateFullName: String
    let latitude: Double
    let longitude: Double
    let population: Int
    let timezone: String

    var displayName: String {
        "\(name), \(state)"
    }

    var fullDisplayName: String {
        "\(name), \(stateFullName)"
    }

    // MARK: - All US Cities (50+)
    static let allCities: [City] = [
        // Top 10 by population
        City(id: "nyc", name: "New York", state: "NY", stateFullName: "New York", latitude: 40.7128, longitude: -74.0060, population: 8336817, timezone: "America/New_York"),
        City(id: "la", name: "Los Angeles", state: "CA", stateFullName: "California", latitude: 34.0522, longitude: -118.2437, population: 3979576, timezone: "America/Los_Angeles"),
        City(id: "chi", name: "Chicago", state: "IL", stateFullName: "Illinois", latitude: 41.8781, longitude: -87.6298, population: 2693976, timezone: "America/Chicago"),
        City(id: "hou", name: "Houston", state: "TX", stateFullName: "Texas", latitude: 29.7604, longitude: -95.3698, population: 2320268, timezone: "America/Chicago"),
        City(id: "phx", name: "Phoenix", state: "AZ", stateFullName: "Arizona", latitude: 33.4484, longitude: -112.0740, population: 1680992, timezone: "America/Phoenix"),
        City(id: "phl", name: "Philadelphia", state: "PA", stateFullName: "Pennsylvania", latitude: 39.9526, longitude: -75.1652, population: 1584064, timezone: "America/New_York"),
        City(id: "sat", name: "San Antonio", state: "TX", stateFullName: "Texas", latitude: 29.4241, longitude: -98.4936, population: 1547253, timezone: "America/Chicago"),
        City(id: "sd", name: "San Diego", state: "CA", stateFullName: "California", latitude: 32.7157, longitude: -117.1611, population: 1423851, timezone: "America/Los_Angeles"),
        City(id: "dal", name: "Dallas", state: "TX", stateFullName: "Texas", latitude: 32.7767, longitude: -96.7970, population: 1343573, timezone: "America/Chicago"),
        City(id: "sf", name: "San Francisco", state: "CA", stateFullName: "California", latitude: 37.7749, longitude: -122.4194, population: 881549, timezone: "America/Los_Angeles"),

        // 11-20
        City(id: "aus", name: "Austin", state: "TX", stateFullName: "Texas", latitude: 30.2672, longitude: -97.7431, population: 978908, timezone: "America/Chicago"),
        City(id: "jax", name: "Jacksonville", state: "FL", stateFullName: "Florida", latitude: 30.3322, longitude: -81.6557, population: 911507, timezone: "America/New_York"),
        City(id: "sj", name: "San Jose", state: "CA", stateFullName: "California", latitude: 37.3382, longitude: -121.8863, population: 1021795, timezone: "America/Los_Angeles"),
        City(id: "ftw", name: "Fort Worth", state: "TX", stateFullName: "Texas", latitude: 32.7555, longitude: -97.3308, population: 909585, timezone: "America/Chicago"),
        City(id: "col", name: "Columbus", state: "OH", stateFullName: "Ohio", latitude: 39.9612, longitude: -82.9988, population: 905748, timezone: "America/New_York"),
        City(id: "ind", name: "Indianapolis", state: "IN", stateFullName: "Indiana", latitude: 39.7684, longitude: -86.1581, population: 876384, timezone: "America/Indiana/Indianapolis"),
        City(id: "clt", name: "Charlotte", state: "NC", stateFullName: "North Carolina", latitude: 35.2271, longitude: -80.8431, population: 872498, timezone: "America/New_York"),
        City(id: "sea", name: "Seattle", state: "WA", stateFullName: "Washington", latitude: 47.6062, longitude: -122.3321, population: 753675, timezone: "America/Los_Angeles"),
        City(id: "den", name: "Denver", state: "CO", stateFullName: "Colorado", latitude: 39.7392, longitude: -104.9903, population: 727211, timezone: "America/Denver"),
        City(id: "dc", name: "Washington", state: "DC", stateFullName: "District of Columbia", latitude: 38.9072, longitude: -77.0369, population: 689545, timezone: "America/New_York"),

        // 21-30
        City(id: "bos", name: "Boston", state: "MA", stateFullName: "Massachusetts", latitude: 42.3601, longitude: -71.0589, population: 675647, timezone: "America/New_York"),
        City(id: "elp", name: "El Paso", state: "TX", stateFullName: "Texas", latitude: 31.7619, longitude: -106.4850, population: 681728, timezone: "America/Denver"),
        City(id: "det", name: "Detroit", state: "MI", stateFullName: "Michigan", latitude: 42.3314, longitude: -83.0458, population: 670031, timezone: "America/Detroit"),
        City(id: "nash", name: "Nashville", state: "TN", stateFullName: "Tennessee", latitude: 36.1627, longitude: -86.7816, population: 689447, timezone: "America/Chicago"),
        City(id: "mem", name: "Memphis", state: "TN", stateFullName: "Tennessee", latitude: 35.1495, longitude: -90.0490, population: 650100, timezone: "America/Chicago"),
        City(id: "pdx", name: "Portland", state: "OR", stateFullName: "Oregon", latitude: 45.5152, longitude: -122.6784, population: 652573, timezone: "America/Los_Angeles"),
        City(id: "okc", name: "Oklahoma City", state: "OK", stateFullName: "Oklahoma", latitude: 35.4676, longitude: -97.5164, population: 681054, timezone: "America/Chicago"),
        City(id: "lv", name: "Las Vegas", state: "NV", stateFullName: "Nevada", latitude: 36.1699, longitude: -115.1398, population: 641903, timezone: "America/Los_Angeles"),
        City(id: "lou", name: "Louisville", state: "KY", stateFullName: "Kentucky", latitude: 38.2527, longitude: -85.7585, population: 617638, timezone: "America/Kentucky/Louisville"),
        City(id: "bal", name: "Baltimore", state: "MD", stateFullName: "Maryland", latitude: 39.2904, longitude: -76.6122, population: 585708, timezone: "America/New_York"),

        // 31-40
        City(id: "mil", name: "Milwaukee", state: "WI", stateFullName: "Wisconsin", latitude: 43.0389, longitude: -87.9065, population: 577222, timezone: "America/Chicago"),
        City(id: "abq", name: "Albuquerque", state: "NM", stateFullName: "New Mexico", latitude: 35.0844, longitude: -106.6504, population: 564559, timezone: "America/Denver"),
        City(id: "tuc", name: "Tucson", state: "AZ", stateFullName: "Arizona", latitude: 32.2226, longitude: -110.9747, population: 542629, timezone: "America/Phoenix"),
        City(id: "fre", name: "Fresno", state: "CA", stateFullName: "California", latitude: 36.7378, longitude: -119.7871, population: 531576, timezone: "America/Los_Angeles"),
        City(id: "sac", name: "Sacramento", state: "CA", stateFullName: "California", latitude: 38.5816, longitude: -121.4944, population: 513624, timezone: "America/Los_Angeles"),
        City(id: "kc", name: "Kansas City", state: "MO", stateFullName: "Missouri", latitude: 39.0997, longitude: -94.5786, population: 508090, timezone: "America/Chicago"),
        City(id: "lb", name: "Long Beach", state: "CA", stateFullName: "California", latitude: 33.7701, longitude: -118.1937, population: 466742, timezone: "America/Los_Angeles"),
        City(id: "mesa", name: "Mesa", state: "AZ", stateFullName: "Arizona", latitude: 33.4152, longitude: -111.8315, population: 504258, timezone: "America/Phoenix"),
        City(id: "atl", name: "Atlanta", state: "GA", stateFullName: "Georgia", latitude: 33.7490, longitude: -84.3880, population: 498715, timezone: "America/New_York"),
        City(id: "colo", name: "Colorado Springs", state: "CO", stateFullName: "Colorado", latitude: 38.8339, longitude: -104.8214, population: 478961, timezone: "America/Denver"),

        // 41-50
        City(id: "ral", name: "Raleigh", state: "NC", stateFullName: "North Carolina", latitude: 35.7796, longitude: -78.6382, population: 467665, timezone: "America/New_York"),
        City(id: "mia", name: "Miami", state: "FL", stateFullName: "Florida", latitude: 25.7617, longitude: -80.1918, population: 467963, timezone: "America/New_York"),
        City(id: "oak", name: "Oakland", state: "CA", stateFullName: "California", latitude: 37.8044, longitude: -122.2712, population: 433031, timezone: "America/Los_Angeles"),
        City(id: "mpls", name: "Minneapolis", state: "MN", stateFullName: "Minnesota", latitude: 44.9778, longitude: -93.2650, population: 425403, timezone: "America/Chicago"),
        City(id: "tul", name: "Tulsa", state: "OK", stateFullName: "Oklahoma", latitude: 36.1540, longitude: -95.9928, population: 413066, timezone: "America/Chicago"),
        City(id: "clv", name: "Cleveland", state: "OH", stateFullName: "Ohio", latitude: 41.4993, longitude: -81.6944, population: 381009, timezone: "America/New_York"),
        City(id: "wic", name: "Wichita", state: "KS", stateFullName: "Kansas", latitude: 37.6872, longitude: -97.3301, population: 397532, timezone: "America/Chicago"),
        City(id: "arl", name: "Arlington", state: "TX", stateFullName: "Texas", latitude: 32.7357, longitude: -97.1081, population: 394266, timezone: "America/Chicago"),
        City(id: "no", name: "New Orleans", state: "LA", stateFullName: "Louisiana", latitude: 29.9511, longitude: -90.0715, population: 383997, timezone: "America/Chicago"),
        City(id: "bak", name: "Bakersfield", state: "CA", stateFullName: "California", latitude: 35.3733, longitude: -119.0187, population: 384145, timezone: "America/Los_Angeles"),

        // 51-55 (bonus cities)
        City(id: "tam", name: "Tampa", state: "FL", stateFullName: "Florida", latitude: 27.9506, longitude: -82.4572, population: 387050, timezone: "America/New_York"),
        City(id: "hon", name: "Honolulu", state: "HI", stateFullName: "Hawaii", latitude: 21.3069, longitude: -157.8583, population: 350964, timezone: "Pacific/Honolulu"),
        City(id: "ana", name: "Anaheim", state: "CA", stateFullName: "California", latitude: 33.8366, longitude: -117.9143, population: 350365, timezone: "America/Los_Angeles"),
        City(id: "aur", name: "Aurora", state: "CO", stateFullName: "Colorado", latitude: 39.7294, longitude: -104.8319, population: 386261, timezone: "America/Denver"),
        City(id: "slc", name: "Salt Lake City", state: "UT", stateFullName: "Utah", latitude: 40.7608, longitude: -111.8910, population: 199723, timezone: "America/Denver")
    ]

    // MARK: - City Lookup
    static func city(byId id: String) -> City? {
        allCities.first { $0.id == id }
    }

    static func cities(matching query: String) -> [City] {
        guard !query.isEmpty else { return allCities }
        let lowercased = query.lowercased()
        return allCities.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.state.lowercased().contains(lowercased) ||
            $0.stateFullName.lowercased().contains(lowercased)
        }
    }

    // Default city (San Francisco)
    static let defaultCity = allCities.first { $0.id == "sf" }!
}
