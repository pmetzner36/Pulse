import Foundation
import SwiftUI

@MainActor
@Observable
final class SubgroundsListViewModel {
    private(set) var subgrounds: [Subground] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var total = 0

    var currentCityId: String?
    var currentCategory: ChatCategory = .general
    var sortOption: SortOption = .activity

    enum SortOption: String, CaseIterable {
        case activity = "activity"
        case newest = "newest"
        case popular = "popular"

        var displayName: String {
            switch self {
            case .activity: return "Most Active"
            case .newest: return "Newest"
            case .popular: return "Most Popular"
            }
        }

        var icon: String {
            switch self {
            case .activity: return "flame.fill"
            case .newest: return "clock.fill"
            case .popular: return "star.fill"
            }
        }
    }

    func loadSubgrounds(for cityId: String, category: ChatCategory, refresh: Bool = false) async {
        if refresh || cityId != currentCityId || category != currentCategory {
            subgrounds = []
        }

        currentCityId = cityId
        currentCategory = category
        isLoading = true
        error = nil

        do {
            let response = try await SubgroundService.shared.fetchSubgrounds(
                cityId: cityId,
                category: category.rawValue,
                sort: sortOption.rawValue
            )
            subgrounds = response.subgrounds
            total = response.total
        } catch {
            self.error = error.localizedDescription
            if subgrounds.isEmpty {
                subgrounds = Subground.samples.filter { $0.cityId == cityId && $0.category == category.rawValue }
            }
        }

        isLoading = false
    }

    func createSubground(name: String, description: String?, emoji: String?) async -> Subground? {
        guard let cityId = currentCityId else {
            self.error = "No city selected"
            return nil
        }

        do {
            let subground = try await SubgroundService.shared.createSubground(
                cityId: cityId,
                category: currentCategory.rawValue,
                name: name,
                description: description,
                emoji: emoji
            )
            subgrounds.insert(subground, at: 0)
            total += 1
            return subground
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}

// MARK: - SubgroundDetailViewModel (Posts Feed)

@MainActor
@Observable
final class SubgroundDetailViewModel {
    let subground: Subground

    private(set) var posts: [SubgroundMessage] = []
    private(set) var isLoading = false
    private(set) var hasMorePosts = true
    private(set) var error: String?

    var postSortOption: PostSortOption = .newest

    enum PostSortOption: String, CaseIterable {
        case newest = "newest"
        case mostReactions = "most_reactions"

        var displayName: String {
            switch self {
            case .newest: return "Newest"
            case .mostReactions: return "Most Reactions"
            }
        }

        var icon: String {
            switch self {
            case .newest: return "clock.fill"
            case .mostReactions: return "flame.fill"
            }
        }
    }

    private var nextCursor: String?
    private let service = SubgroundService.shared

    init(subground: Subground) {
        self.subground = subground
    }

    func loadPosts(refresh: Bool = false) async {
        if refresh {
            posts = []
            nextCursor = nil
            hasMorePosts = true
        }

        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let response = try await service.fetchPosts(
                subgroundId: subground.id,
                sort: postSortOption.rawValue,
                cursor: nextCursor
            )

            if nextCursor == nil {
                posts = response.messages
            } else {
                posts.append(contentsOf: response.messages)
            }

            hasMorePosts = response.hasMore
            nextCursor = response.nextCursor
        } catch {
            self.error = error.localizedDescription
            if posts.isEmpty {
                posts = SubgroundMessage.samples.filter { $0.subgroundId == subground.id }
            }
        }

        isLoading = false
    }

    func addPost(_ post: SubgroundMessage) {
        posts.insert(post, at: 0)
    }

    func updatePost(_ post: SubgroundMessage) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }

    func deletePost(_ post: SubgroundMessage) async -> Bool {
        do {
            try await service.deletePost(subgroundId: subground.id, postId: post.id)
            posts.removeAll { $0.id == post.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func editPost(_ post: SubgroundMessage, title: String?, content: String?, url: String?) async -> Bool {
        do {
            let updated = try await service.editPost(
                subgroundId: subground.id,
                postId: post.id,
                title: title,
                content: content,
                url: url
            )
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = updated
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func toggleReaction(on post: SubgroundMessage, emoji: String) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        do {
            let updatedReaction = try await service.addReaction(
                subgroundId: subground.id,
                messageId: post.id,
                emoji: emoji
            )

            var updatedPost = posts[index]
            var updatedReactions = updatedPost.reactions.filter { $0.emoji != emoji }
            if updatedReaction.count > 0 {
                updatedReactions.append(updatedReaction)
            }
            updatedPost.reactions = updatedReactions
            posts[index] = updatedPost
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - PostDetailViewModel

@MainActor
@Observable
final class PostDetailViewModel {
    let subgroundId: String
    var post: SubgroundMessage

    private(set) var comments: [SubgroundMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var hasMoreComments = true
    private(set) var error: String?

    var commentText = ""
    var commentURL = ""
    var showLinkField = false

    private var nextCursor: String?
    private let service = SubgroundService.shared

    init(subgroundId: String, post: SubgroundMessage) {
        self.subgroundId = subgroundId
        self.post = post
    }

    func loadComments(refresh: Bool = false) async {
        if refresh {
            comments = []
            nextCursor = nil
            hasMoreComments = true
        }

        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let response = try await service.fetchComments(
                subgroundId: subgroundId,
                postId: post.id,
                cursor: nextCursor
            )

            if nextCursor == nil {
                comments = response.messages
            } else {
                comments.append(contentsOf: response.messages)
            }

            hasMoreComments = response.hasMore
            nextCursor = response.nextCursor
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func sendComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let urlString = commentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let url: String? = urlString.isEmpty ? nil : urlString

        commentText = ""
        commentURL = ""
        showLinkField = false
        isSending = true
        error = nil

        do {
            let comment = try await service.addComment(
                subgroundId: subgroundId,
                postId: post.id,
                content: content,
                url: url
            )
            if !comments.contains(where: { $0.id == comment.id }) {
                comments.append(comment)
            }
        } catch {
            self.error = error.localizedDescription
            commentText = content
        }

        isSending = false
    }

    func deleteComment(_ comment: SubgroundMessage) async -> Bool {
        do {
            try await service.deleteComment(
                subgroundId: subgroundId,
                postId: post.id,
                commentId: comment.id
            )
            comments.removeAll { $0.id == comment.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func editComment(_ comment: SubgroundMessage, content: String) async -> Bool {
        do {
            let updated = try await service.editComment(
                subgroundId: subgroundId,
                postId: post.id,
                commentId: comment.id,
                content: content
            )
            if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                comments[index] = updated
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func toggleReaction(on message: SubgroundMessage, emoji: String) async {
        // Check if it's the post itself or a comment
        if message.id == post.id {
            do {
                let updatedReaction = try await service.addReaction(
                    subgroundId: subgroundId,
                    messageId: post.id,
                    emoji: emoji
                )
                var updatedReactions = post.reactions.filter { $0.emoji != emoji }
                if updatedReaction.count > 0 {
                    updatedReactions.append(updatedReaction)
                }
                post.reactions = updatedReactions
            } catch {
                self.error = error.localizedDescription
            }
        } else if let index = comments.firstIndex(where: { $0.id == message.id }) {
            do {
                let updatedReaction = try await service.addReaction(
                    subgroundId: subgroundId,
                    messageId: message.id,
                    emoji: emoji
                )
                var updatedReactions = comments[index].reactions.filter { $0.emoji != emoji }
                if updatedReaction.count > 0 {
                    updatedReactions.append(updatedReaction)
                }
                comments[index].reactions = updatedReactions
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
