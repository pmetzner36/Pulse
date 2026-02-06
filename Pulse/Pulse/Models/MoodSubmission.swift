import Foundation
import SwiftUI

// MARK: - Mood Topics (aspects of city life users can rate)

enum MoodTopic: String, CaseIterable, Codable, Identifiable {
    case political = "Political"
    case social = "Social"
    case travel = "Travel"
    case work = "Work"
    case weather = "Weather"
    case health = "Health"
    case economy = "Economy"
    case safety = "Safety"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .political: return "building.columns.fill"
        case .social: return "person.3.fill"
        case .travel: return "airplane"
        case .work: return "briefcase.fill"
        case .weather: return "cloud.sun.fill"
        case .health: return "heart.fill"
        case .economy: return "chart.line.uptrend.xyaxis"
        case .safety: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .political: return .purple
        case .social: return .blue
        case .travel: return .orange
        case .work: return .brown
        case .weather: return .cyan
        case .health: return .red
        case .economy: return .green
        case .safety: return .indigo
        }
    }
}

// MARK: - Mood Rating

enum MoodRating: Int, CaseIterable, Codable {
    case veryNegative = 1
    case negative = 2
    case neutral = 3
    case positive = 4
    case veryPositive = 5
    
    var emoji: String {
        switch self {
        case .veryNegative: return "😢"
        case .negative: return "😕"
        case .neutral: return "😐"
        case .positive: return "🙂"
        case .veryPositive: return "😊"
        }
    }
    
    var label: String {
        switch self {
        case .veryNegative: return "Very Negative"
        case .negative: return "Negative"
        case .neutral: return "Neutral"
        case .positive: return "Positive"
        case .veryPositive: return "Very Positive"
        }
    }
    
    var color: Color {
        switch self {
        case .veryNegative: return .red
        case .negative: return .orange
        case .neutral: return .gray
        case .positive: return .mint
        case .veryPositive: return .green
        }
    }
}

// MARK: - Mood Submission

struct MoodSubmission: Codable, Identifiable {
    let id: String
    let userId: String
    let cityId: String
    let categories: [MoodTopic]
    let rating: Int
    let note: String?
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?
}

// MARK: - API Models

struct SubmitMoodRequest: Codable {
    let cityId: String
    let categories: [String]
    let rating: Int
    let note: String?
    let latitude: Double?
    let longitude: Double?
}

struct MoodAggregateResponse: Codable, Identifiable {
    let id: String
    let cityId: String
    let category: String
    let averageRating: Double
    let submissionCount: Int
    let trend: String // "rising", "falling", "stable"
    let latitude: Double
    let longitude: Double
}

struct CityMoodSummary: Codable {
    let cityId: String
    let cityName: String
    let overallRating: Double
    let totalSubmissions: Int
    let categoryBreakdown: [CategoryMood]
    let lastUpdated: Date
}

struct CategoryMood: Codable, Identifiable {
    var id: String { category }
    let category: String
    let averageRating: Double
    let count: Int
}
