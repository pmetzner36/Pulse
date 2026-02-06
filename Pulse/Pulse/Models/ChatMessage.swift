import Foundation
import SwiftUI

// MARK: - Chat Category

enum ChatCategory: String, CaseIterable, Codable, Identifiable {
    case general = "general"
    case political = "political"
    case social = "social"
    case travel = "travel"
    case work = "work"
    case weather = "weather"
    case health = "health"
    case economy = "economy"
    case safety = "safety"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "General"
        case .political: return "Political"
        case .social: return "Social"
        case .travel: return "Travel"
        case .work: return "Work"
        case .weather: return "Weather"
        case .health: return "Health"
        case .economy: return "Economy"
        case .safety: return "Safety"
        }
    }

    var icon: String {
        switch self {
        case .general: return "bubble.left.and.bubble.right.fill"
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
        case .general: return .gray
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

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let cityId: String
    let userId: String
    let username: String
    let category: String
    let content: String
    let timestamp: Date

    var chatCategory: ChatCategory {
        ChatCategory(rawValue: category) ?? .general
    }

    var isFromCurrentUser: Bool {
        userId == CurrentUser.shared.user?.id
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: timestamp)
    }
}

// MARK: - API Request/Response Models

struct SendMessageRequest: Codable {
    let content: String
    let category: String
}

struct MessagesResponse: Codable {
    let messages: [ChatMessage]
    let hasMore: Bool
    let nextCursor: String?
}

struct ChatRoomInfo: Codable {
    let cityId: String
    let cityName: String
    let category: String
    let memberCount: Int
    let activeNow: Int
}

struct ChatCategoryInfo: Codable, Identifiable {
    let category: String
    let displayName: String
    let icon: String
    let messageCount: Int
    let activeNow: Int

    var id: String { category }
}

// MARK: - WebSocket Message Types

enum WebSocketMessageType: String, Codable {
    case message = "message"
    case joined = "joined"
    case left = "left"
    case typing = "typing"
    case error = "error"
}

struct WebSocketMessage: Codable {
    let type: WebSocketMessageType
    let payload: WebSocketPayload?
}

struct WebSocketPayload: Codable {
    let message: ChatMessage?
    let userId: String?
    let username: String?
    let error: String?
}

// MARK: - Sample Data

extension ChatMessage {
    static let sampleMessages: [ChatMessage] = [
        ChatMessage(
            id: "1",
            cityId: "sf",
            userId: "user1",
            username: "marina_vibes",
            category: "general",
            content: "Anyone else feel like the city energy is wild today?",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        ChatMessage(
            id: "2",
            cityId: "sf",
            userId: "user2",
            username: "soma_techie",
            category: "general",
            content: "Yeah the Financial District is intense right now",
            timestamp: Date().addingTimeInterval(-3000)
        ),
        ChatMessage(
            id: "3",
            cityId: "sf",
            userId: "user3",
            username: "sunset_walker",
            category: "general",
            content: "It's pretty chill out here in the Sunset. Come west!",
            timestamp: Date().addingTimeInterval(-2400)
        ),
        ChatMessage(
            id: "4",
            cityId: "sf",
            userId: "user1",
            username: "marina_vibes",
            category: "general",
            content: "Good idea, might head that way",
            timestamp: Date().addingTimeInterval(-1800)
        ),
        ChatMessage(
            id: "5",
            cityId: "sf",
            userId: "user4",
            username: "castro_coffee",
            category: "general",
            content: "Castro is having a great afternoon vibe",
            timestamp: Date().addingTimeInterval(-600)
        )
    ]
}
