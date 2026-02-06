import Foundation
import SwiftUI

// MARK: - Mood Metrics
struct MoodMetrics: Codable, Equatable {
    var stress: Float
    var energy: Float

    static let neutral = MoodMetrics(stress: 0.5, energy: 0.5)

    var moodCategory: MoodCategory {
        switch (stress > 0.5, energy > 0.5) {
        case (false, true): return .energized
        case (true, true): return .tense
        case (false, false): return .calm
        case (true, false): return .tired
        }
    }
}

// MARK: - Mood Category
enum MoodCategory: String, CaseIterable {
    case energized = "Energized"
    case tense = "Tense"
    case calm = "Calm"
    case tired = "Tired"

    var emoji: String {
        switch self {
        case .energized: return "⚡"
        case .tense: return "😤"
        case .calm: return "😌"
        case .tired: return "😴"
        }
    }

    var color: Color {
        switch self {
        case .energized: return .green
        case .tense: return .red
        case .calm: return .blue
        case .tired: return .orange
        }
    }

    var description: String {
        switch self {
        case .energized: return "High energy, low stress"
        case .tense: return "High energy, high stress"
        case .calm: return "Low energy, low stress"
        case .tired: return "Low energy, high stress"
        }
    }
}

// MARK: - Trend Direction
enum TrendDirection: String, Codable {
    case rising, falling, stable

    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .rising: return "Rising"
        case .falling: return "Falling"
        case .stable: return "Stable"
        }
    }
}

// MARK: - Aggregate Tile (City Region Data)
struct AggregateTile: Identifiable {
    let id = UUID()
    let name: String
    let metrics: MoodMetrics
    let sampleCount: Int
    let trend: TrendDirection
    let confidence: Float
    let latitude: Double
    let longitude: Double

    var moodCategory: MoodCategory { metrics.moodCategory }

    static let sampleData: [AggregateTile] = [
        AggregateTile(
            name: "Downtown",
            metrics: MoodMetrics(stress: 0.65, energy: 0.7),
            sampleCount: 156,
            trend: .rising,
            confidence: 0.92,
            latitude: 37.7849,
            longitude: -122.4094
        ),
        AggregateTile(
            name: "Mission District",
            metrics: MoodMetrics(stress: 0.35, energy: 0.6),
            sampleCount: 89,
            trend: .stable,
            confidence: 0.85,
            latitude: 37.7599,
            longitude: -122.4148
        ),
        AggregateTile(
            name: "Marina",
            metrics: MoodMetrics(stress: 0.25, energy: 0.75),
            sampleCount: 72,
            trend: .rising,
            confidence: 0.78,
            latitude: 37.8015,
            longitude: -122.4368
        ),
        AggregateTile(
            name: "SoMa",
            metrics: MoodMetrics(stress: 0.55, energy: 0.45),
            sampleCount: 134,
            trend: .falling,
            confidence: 0.88,
            latitude: 37.7785,
            longitude: -122.3950
        ),
        AggregateTile(
            name: "Castro",
            metrics: MoodMetrics(stress: 0.3, energy: 0.65),
            sampleCount: 67,
            trend: .stable,
            confidence: 0.82,
            latitude: 37.7609,
            longitude: -122.4350
        ),
        AggregateTile(
            name: "Financial District",
            metrics: MoodMetrics(stress: 0.7, energy: 0.6),
            sampleCount: 203,
            trend: .rising,
            confidence: 0.95,
            latitude: 37.7946,
            longitude: -122.3999
        )
    ]
}

// MARK: - Insight Card
struct InsightCard: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let icon: String
    let color: Color

    enum InsightType {
        case spike, comparison, trend, tip
    }

    static let sampleInsights: [InsightCard] = [
        InsightCard(
            type: .spike,
            title: "Stress Spike Detected",
            message: "Financial District stress is 35% higher than usual this hour. Consider alternative routes.",
            icon: "exclamationmark.triangle.fill",
            color: .red
        ),
        InsightCard(
            type: .comparison,
            title: "You're Calmer",
            message: "Your stress level is 20% lower than the city average right now.",
            icon: "face.smiling.fill",
            color: .green
        ),
        InsightCard(
            type: .trend,
            title: "Energy Rising",
            message: "City-wide energy has been climbing since 2pm. The evening rush is approaching.",
            icon: "arrow.up.right.circle.fill",
            color: .orange
        ),
        InsightCard(
            type: .tip,
            title: "Best Time to Relax",
            message: "Marina District is currently the calmest area. Great for a peaceful walk.",
            icon: "leaf.fill",
            color: .mint
        )
    ]
}

// MARK: - Category News
struct CategoryNews: Codable, Identifiable {
    var id: String { category }
    let category: String
    let news: [NewsItem]
}

struct NewsItem: Codable, Identifiable {
    var id: String { link }
    let title: String
    let link: String
    let source: String
    let published: String?
}

// MARK: - Map Mood Pin
struct MapMoodPin: Codable, Identifiable {
    let id: String
    let username: String
    let rating: Int
    let categories: [String]
    let timestamp: Date
    let latitude: Double
    let longitude: Double
}

// MARK: - Time Window
enum TimeWindow: String, CaseIterable {
    case fifteenMin = "15m"
    case oneHour = "1h"
    case twentyFourHours = "24h"

    var displayName: String {
        switch self {
        case .fifteenMin: return "15 min"
        case .oneHour: return "1 hour"
        case .twentyFourHours: return "24 hours"
        }
    }

    var minutes: Int {
        switch self {
        case .fifteenMin: return 15
        case .oneHour: return 60
        case .twentyFourHours: return 1440
        }
    }
}
