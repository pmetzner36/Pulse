import Foundation
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var summary: CityMoodSummary?
    private(set) var aggregates: [MoodAggregateResponse] = []
    private(set) var categoryNews: [CategoryNews] = []
    private(set) var moodHistory: [MonthlyMoodHistory] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private var loadedCityId: String?
    private let service = MoodService.shared

    var cityName: String {
        summary?.cityName ?? UserPreferences.shared.selectedCity.name
    }

    var overallRating: Double {
        summary?.overallRating ?? 3.0
    }

    var totalSubmissions: Int {
        summary?.totalSubmissions ?? 0
    }

    var categoryBreakdown: [CategoryMood] {
        summary?.categoryBreakdown ?? []
    }

    var hasData: Bool {
        totalSubmissions > 0
    }

    // MARK: - Overall Rating Emoji

    var overallEmoji: String {
        switch overallRating {
        case ..<1.5: return "😢"
        case 1.5..<2.5: return "😕"
        case 2.5..<3.5: return "😐"
        case 3.5..<4.5: return "🙂"
        default: return "😊"
        }
    }

    var overallLabel: String {
        switch overallRating {
        case ..<1.5: return "Very Negative"
        case 1.5..<2.5: return "Negative"
        case 2.5..<3.5: return "Neutral"
        case 3.5..<4.5: return "Positive"
        default: return "Very Positive"
        }
    }

    // MARK: - Generated Insights

    var insights: [InsightCard] {
        guard hasData else { return [] }

        var cards: [InsightCard] = []

        // Find best and worst categories
        let sorted = categoryBreakdown.sorted { $0.averageRating > $1.averageRating }
        if let best = sorted.first, best.averageRating >= 3.5 {
            let topic = MoodTopic(rawValue: best.category)
            cards.append(InsightCard(
                type: .trend,
                title: "\(best.category) is Thriving",
                message: "\(best.category) has the highest mood rating at \(String(format: "%.1f", best.averageRating))/5 based on \(best.count) submissions.",
                icon: topic?.icon ?? "star.fill",
                color: topic?.color ?? .green
            ))
        }

        if let worst = sorted.last, sorted.count > 1, worst.averageRating < 3.0 {
            let topic = MoodTopic(rawValue: worst.category)
            cards.append(InsightCard(
                type: .spike,
                title: "\(worst.category) Needs Attention",
                message: "\(worst.category) has the lowest mood at \(String(format: "%.1f", worst.averageRating))/5. \(worst.count) people have weighed in.",
                icon: topic?.icon ?? "exclamationmark.triangle.fill",
                color: topic?.color ?? .red
            ))
        }

        // Find trending categories
        let rising = aggregates.filter { $0.trend == "rising" }
        if let topRising = rising.sorted(by: { $0.submissionCount > $1.submissionCount }).first {
            let topic = MoodTopic(rawValue: topRising.category)
            cards.append(InsightCard(
                type: .trend,
                title: "\(topRising.category) Mood Rising",
                message: "The \(topRising.category.lowercased()) mood is trending upward compared to the previous period.",
                icon: "arrow.up.right.circle.fill",
                color: topic?.color ?? .orange
            ))
        }

        let falling = aggregates.filter { $0.trend == "falling" }
        if let topFalling = falling.sorted(by: { $0.submissionCount > $1.submissionCount }).first {
            let topic = MoodTopic(rawValue: topFalling.category)
            cards.append(InsightCard(
                type: .spike,
                title: "\(topFalling.category) Mood Declining",
                message: "The \(topFalling.category.lowercased()) mood has dipped since the last period.",
                icon: "arrow.down.right.circle.fill",
                color: topic?.color ?? .red
            ))
        }

        // Overall summary
        if totalSubmissions > 0 {
            cards.append(InsightCard(
                type: .comparison,
                title: "\(totalSubmissions) Mood Reports",
                message: "The overall mood in \(cityName) is \(overallLabel.lowercased()) with an average rating of \(String(format: "%.1f", overallRating))/5.",
                icon: "chart.bar.fill",
                color: .purple
            ))
        }

        return cards
    }

    // MARK: - News helpers

    func newsItem(for category: String) -> NewsItem? {
        categoryNews.first(where: { $0.category == category })?.news.first
    }

    // MARK: - Load Data

    func loadData(for cityId: String, forceRefresh: Bool = false) async {
        guard forceRefresh || cityId != loadedCityId else { return }

        isLoading = true
        error = nil
        loadedCityId = cityId

        await service.fetchCityMood(cityId: cityId)
        summary = service.cityMoodSummary

        await service.fetchMoodAggregates(cityId: cityId)
        aggregates = service.moodAggregates

        // Fetch news in parallel (non-blocking)
        await service.fetchCategoryNews(cityId: cityId)
        categoryNews = service.categoryNews

        await service.fetchMoodHistory(cityId: cityId)
        moodHistory = service.moodHistory

        if let serviceError = service.error {
            error = serviceError
        }

        isLoading = false
    }
}
