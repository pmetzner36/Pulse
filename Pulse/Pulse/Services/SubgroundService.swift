import Foundation

@MainActor
final class SubgroundService {
    static let shared = SubgroundService()

    private init() {}

    // MARK: - Subgrounds

    func fetchSubgrounds(cityId: String, category: String = "general", sort: String = "activity", limit: Int = 20, offset: Int = 0) async throws -> SubgroundListResponse {
        let endpoint = "/subgrounds/city/\(cityId)?category=\(category)&sort=\(sort)&limit=\(limit)&offset=\(offset)"
        return try await APIClient.shared.request(endpoint: endpoint, method: .get, requiresAuth: false)
    }

    func createSubground(cityId: String, category: String, name: String, description: String?, emoji: String?) async throws -> Subground {
        let request = CreateSubgroundRequest(name: name, description: description, emoji: emoji, category: category)
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/city/\(cityId)",
            method: .post,
            body: request
        )
    }

    func getSubground(id: String) async throws -> Subground {
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(id)",
            method: .get,
            requiresAuth: false
        )
    }

    // MARK: - Messages

    func fetchMessages(subgroundId: String, cursor: String? = nil, limit: Int = 50) async throws -> SubgroundMessagesResponse {
        var endpoint = "/subgrounds/\(subgroundId)/messages?limit=\(limit)"
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        return try await APIClient.shared.request(endpoint: endpoint, method: .get)
    }

    func sendMessage(subgroundId: String, content: String, replyToId: String? = nil) async throws -> SubgroundMessage {
        let request = SendSubgroundMessageRequest(content: content, replyToId: replyToId)
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(subgroundId)/messages",
            method: .post,
            body: request
        )
    }

    // MARK: - Posts

    func fetchPosts(subgroundId: String, sort: String = "newest", cursor: String? = nil, limit: Int = 20) async throws -> SubgroundMessagesResponse {
        var endpoint = "/subgrounds/\(subgroundId)/posts?sort=\(sort)&limit=\(limit)"
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        return try await APIClient.shared.request(endpoint: endpoint, method: .get)
    }

    func createPost(subgroundId: String, title: String?, content: String?, postType: PostType, url: String?) async throws -> SubgroundMessage {
        let request = CreateSubgroundPostRequest(
            title: title,
            content: content,
            postType: postType.rawValue,
            url: url
        )
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(subgroundId)/posts",
            method: .post,
            body: request
        )
    }

    func fetchComments(subgroundId: String, postId: String, cursor: String? = nil, limit: Int = 50) async throws -> SubgroundMessagesResponse {
        var endpoint = "/subgrounds/\(subgroundId)/posts/\(postId)/comments?limit=\(limit)"
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        return try await APIClient.shared.request(endpoint: endpoint, method: .get)
    }

    func addComment(subgroundId: String, postId: String, content: String, url: String? = nil) async throws -> SubgroundMessage {
        let request = SendSubgroundCommentRequest(content: content, url: url)
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(subgroundId)/posts/\(postId)/comments",
            method: .post,
            body: request
        )
    }

    func fetchLinkPreview(url: String) async throws -> LinkPreviewData {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/link-preview?url=\(encoded)",
            method: .get
        )
    }

    // MARK: - Delete

    func deletePost(subgroundId: String, postId: String) async throws {
        try await APIClient.shared.requestWithoutResponse(
            endpoint: "/subgrounds/\(subgroundId)/posts/\(postId)",
            method: .delete
        )
    }

    func deleteComment(subgroundId: String, postId: String, commentId: String) async throws {
        try await APIClient.shared.requestWithoutResponse(
            endpoint: "/subgrounds/\(subgroundId)/posts/\(postId)/comments/\(commentId)",
            method: .delete
        )
    }

    // MARK: - Edit

    func editPost(subgroundId: String, postId: String, title: String?, content: String?, url: String?) async throws -> SubgroundMessage {
        let request = EditSubgroundPostRequest(title: title, content: content, url: url)
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(subgroundId)/posts/\(postId)",
            method: .put,
            body: request
        )
    }

    func editComment(subgroundId: String, postId: String, commentId: String, content: String) async throws -> SubgroundMessage {
        let request = EditSubgroundCommentRequest(content: content)
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(subgroundId)/posts/\(postId)/comments/\(commentId)",
            method: .put,
            body: request
        )
    }

    // MARK: - Reactions

    func addReaction(subgroundId: String, messageId: String, emoji: String) async throws -> ReactionInfo {
        let request = AddReactionRequest(emoji: emoji)
        return try await APIClient.shared.request(
            endpoint: "/subgrounds/\(subgroundId)/messages/\(messageId)/reactions",
            method: .post,
            body: request
        )
    }

    func removeReaction(subgroundId: String, messageId: String, emoji: String) async throws {
        try await APIClient.shared.requestWithoutResponse(
            endpoint: "/subgrounds/\(subgroundId)/messages/\(messageId)/reactions/\(emoji)",
            method: .delete
        )
    }
}
