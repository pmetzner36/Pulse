import Foundation

@MainActor
@Observable
final class MoodService {
    static let shared = MoodService()
    
    private(set) var isSubmitting = false
    private(set) var lastSubmission: MoodSubmission?
    private(set) var cityMoodSummary: CityMoodSummary?
    private(set) var moodAggregates: [MoodAggregateResponse] = []
    private(set) var mapPins: [MapMoodPin] = []
    private(set) var isLoadingPins = false
    private(set) var categoryNews: [CategoryNews] = []
    private(set) var moodHistory: [MonthlyMoodHistory] = []
    private(set) var error: String?
    
    private init() {}
    
    // MARK: - Submit Mood
    
    func submitMood(
        cityId: String,
        categories: [MoodTopic],
        rating: Int,
        note: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        
        let request = SubmitMoodRequest(
            cityId: cityId,
            categories: categories.map { $0.rawValue },
            rating: rating,
            note: note,
            latitude: latitude,
            longitude: longitude
        )
        
        do {
            let submission: MoodSubmission = try await APIClient.shared.request(
                endpoint: "/mood/submit",
                method: .post,
                body: request
            )
            lastSubmission = submission
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Fetch Mood Data
    
    func fetchCityMood(cityId: String) async {
        error = nil
        
        do {
            let summary: CityMoodSummary = try await APIClient.shared.request(
                endpoint: "/mood/city/\(cityId)",
                method: .get,
                requiresAuth: false
            )
            cityMoodSummary = summary
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func fetchMoodAggregates(cityId: String, category: MoodTopic? = nil) async {
        error = nil
        
        var endpoint = "/mood/aggregates/\(cityId)"
        if let category = category {
            endpoint += "?category=\(category.rawValue)"
        }
        
        do {
            let aggregates: [MoodAggregateResponse] = try await APIClient.shared.request(
                endpoint: endpoint,
                method: .get,
                requiresAuth: false
            )
            moodAggregates = aggregates
        } catch {
            self.error = error.localizedDescription
        }
    }

    func fetchMapPins(cityId: String, minutes: Int = 1440) async {
        isLoadingPins = true
        error = nil
        defer { isLoadingPins = false }

        do {
            let pins: [MapMoodPin] = try await APIClient.shared.request(
                endpoint: "/mood/map/\(cityId)?minutes=\(minutes)",
                method: .get,
                requiresAuth: false
            )
            mapPins = pins
        } catch {
            self.error = error.localizedDescription
            mapPins = []
        }
    }

    func fetchMoodHistory(cityId: String, months: Int = 12) async {
        do {
            let history: [MonthlyMoodHistory] = try await APIClient.shared.request(
                endpoint: "/mood/history/\(cityId)?months=\(months)",
                method: .get,
                requiresAuth: false
            )
            moodHistory = history
        } catch {
            // History is non-critical, silently fail
            moodHistory = []
        }
    }

    func fetchCategoryNews(cityId: String) async {
        do {
            let news: [CategoryNews] = try await APIClient.shared.request(
                endpoint: "/mood/news/\(cityId)",
                method: .get,
                requiresAuth: false
            )
            categoryNews = news
        } catch {
            // News is non-critical, silently fail
            categoryNews = []
        }
    }
}
