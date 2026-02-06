import Foundation

// MARK: - Subground Model

struct Subground: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let cityId: String
    let category: String
    let creatorId: String
    let creatorUsername: String
    let name: String
    let description: String?
    let emoji: String?
    let isActive: Bool
    let memberCount: Int
    let messageCount: Int
    let createdAt: Date
    let lastActivity: Date

    var chatCategory: ChatCategory {
        ChatCategory(rawValue: category) ?? .general
    }

    var displayName: String {
        if let emoji = emoji {
            return "\(emoji) \(name)"
        }
        return name
    }

    var formattedLastActivity: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}

// MARK: - Post Type

enum PostType: String, Codable, CaseIterable {
    case text
    case link
    case image

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        }
    }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .link: return "link"
        case .image: return "photo"
        }
    }
}

// MARK: - Link Preview

struct LinkPreviewData: Codable, Equatable, Hashable {
    let title: String?
    let description: String?
    let imageUrl: String?
}

// MARK: - Subground Message

struct SubgroundMessage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let subgroundId: String
    let userId: String
    let username: String
    let content: String
    let replyToId: String?
    let timestamp: Date
    var reactions: [ReactionInfo]

    // Post fields
    let title: String?
    let postType: String?
    let url: String?
    let linkPreview: LinkPreviewData?
    let commentCount: Int?

    var isFromCurrentUser: Bool {
        userId == CurrentUser.shared.user?.id
    }

    var resolvedPostType: PostType {
        if let postType = postType {
            return PostType(rawValue: postType) ?? .text
        }
        return .text
    }

    var isPost: Bool {
        postType != nil
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

    var formattedPostDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    static func == (lhs: SubgroundMessage, rhs: SubgroundMessage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Reaction

struct ReactionInfo: Codable, Equatable, Hashable {
    let emoji: String
    let count: Int
    let users: [String]
    let userReacted: Bool
}

// MARK: - API Request/Response Models

struct CreateSubgroundRequest: Codable {
    let name: String
    let description: String?
    let emoji: String?
    let category: String
}

struct SubgroundListResponse: Codable {
    let subgrounds: [Subground]
    let total: Int
}

struct SendSubgroundMessageRequest: Codable {
    let content: String
    let replyToId: String?
}

struct CreateSubgroundPostRequest: Codable {
    let title: String?
    let content: String?
    let postType: String
    let url: String?
}

struct EditSubgroundPostRequest: Codable {
    let title: String?
    let content: String?
    let url: String?
}

struct SendSubgroundCommentRequest: Codable {
    let content: String
    let url: String?
}

struct EditSubgroundCommentRequest: Codable {
    let content: String
}

struct SubgroundMessagesResponse: Codable {
    let messages: [SubgroundMessage]
    let hasMore: Bool
    let nextCursor: String?
}

struct AddReactionRequest: Codable {
    let emoji: String
}

// MARK: - Sample Data

extension Subground {
    static let samples: [Subground] = [
        Subground(
            id: "1",
            cityId: "sf",
            category: "economy",
            creatorId: "user1",
            creatorUsername: "marina_vibes",
            name: "Tech Layoffs Discussion",
            description: "Discussing the impact of recent tech layoffs in the Bay Area",
            emoji: "💼",
            isActive: true,
            memberCount: 156,
            messageCount: 892,
            createdAt: Date().addingTimeInterval(-86400 * 7),
            lastActivity: Date().addingTimeInterval(-3600)
        ),
        Subground(
            id: "2",
            cityId: "sf",
            category: "social",
            creatorId: "user2",
            creatorUsername: "soma_techie",
            name: "Best Coffee Spots",
            description: "Share your favorite local coffee shops",
            emoji: "☕",
            isActive: true,
            memberCount: 89,
            messageCount: 234,
            createdAt: Date().addingTimeInterval(-86400 * 14),
            lastActivity: Date().addingTimeInterval(-7200)
        ),
        Subground(
            id: "3",
            cityId: "sf",
            category: "economy",
            creatorId: "user3",
            creatorUsername: "sunset_walker",
            name: "Housing Market",
            description: "Rent prices, buying tips, and housing news",
            emoji: "🏠",
            isActive: true,
            memberCount: 312,
            messageCount: 1547,
            createdAt: Date().addingTimeInterval(-86400 * 30),
            lastActivity: Date().addingTimeInterval(-1800)
        )
    ]
}

extension SubgroundMessage {
    static let samples: [SubgroundMessage] = [
        SubgroundMessage(
            id: "1",
            subgroundId: "1",
            userId: "user1",
            username: "marina_vibes",
            content: "Has anyone else noticed more companies doing stealth layoffs lately? I've heard from multiple friends that their companies are doing quiet cuts.",
            replyToId: nil,
            timestamp: Date().addingTimeInterval(-3600),
            reactions: [
                ReactionInfo(emoji: "👍", count: 12, users: ["user2", "user3"], userReacted: false),
                ReactionInfo(emoji: "😢", count: 5, users: ["user4"], userReacted: true)
            ],
            title: "Stealth layoffs increasing in Bay Area tech",
            postType: "text",
            url: nil,
            linkPreview: nil,
            commentCount: 24
        ),
        SubgroundMessage(
            id: "2",
            subgroundId: "1",
            userId: "user2",
            username: "soma_techie",
            content: "Great breakdown of the current situation",
            replyToId: nil,
            timestamp: Date().addingTimeInterval(-3000),
            reactions: [
                ReactionInfo(emoji: "❤️", count: 8, users: ["user1", "user3"], userReacted: false)
            ],
            title: "SF Tech Hiring Freeze Tracker",
            postType: "link",
            url: "https://example.com/tracker",
            linkPreview: LinkPreviewData(title: "SF Tech Hiring Freeze Tracker", description: "Real-time tracking of hiring freezes across Bay Area companies", imageUrl: nil),
            commentCount: 12
        )
    ]
}
