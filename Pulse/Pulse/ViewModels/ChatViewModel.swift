import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var hasMoreMessages = true
    private(set) var error: String?
    private(set) var categories: [ChatCategoryInfo] = []

    var messageText = ""
    var selectedCategory: ChatCategory = .general

    private var currentCityId: String?
    private var nextCursor: String?
    private let chatService = ChatService.shared

    // MARK: - Lifecycle

    func connect(to city: City, category: ChatCategory = .general) async {
        let cityChanged = city.id != currentCityId
        let categoryChanged = category != selectedCategory

        if cityChanged {
            messages = []
            hasMoreMessages = true
            nextCursor = nil
            currentCityId = city.id
        }

        if categoryChanged {
            messages = []
            hasMoreMessages = true
            nextCursor = nil
            selectedCategory = category
        }

        error = nil

        // Setup message handler
        chatService.removeAllHandlers()
        chatService.addMessageHandler { [weak self] message in
            self?.handleNewMessage(message)
        }

        // Connect to WebSocket/polling for this category
        await chatService.connect(to: city.id, category: category)

        // Load messages and categories
        await loadMessages()
        await loadCategories()
    }

    func switchCategory(_ category: ChatCategory) async {
        guard let cityId = currentCityId else { return }

        selectedCategory = category
        messages = []
        hasMoreMessages = true
        nextCursor = nil
        error = nil

        chatService.removeAllHandlers()
        chatService.addMessageHandler { [weak self] message in
            self?.handleNewMessage(message)
        }

        await chatService.connect(to: cityId, category: category)
        await loadMessages()
    }

    func disconnect() {
        chatService.disconnect()
        chatService.removeAllHandlers()
        currentCityId = nil
    }

    // MARK: - Categories

    func loadCategories() async {
        guard let cityId = currentCityId else { return }

        do {
            categories = try await chatService.fetchCategories(cityId: cityId)
        } catch {
            // Use default categories
            categories = ChatCategory.allCases.map { cat in
                ChatCategoryInfo(
                    category: cat.rawValue,
                    displayName: cat.displayName,
                    icon: cat.icon,
                    messageCount: 0,
                    activeNow: 0
                )
            }
        }
    }

    // MARK: - Messages

    func loadMessages() async {
        guard let cityId = currentCityId, !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let response = try await chatService.fetchMessages(
                cityId: cityId,
                category: selectedCategory,
                cursor: nextCursor
            )

            if nextCursor == nil {
                messages = response.messages.reversed()
            } else {
                let oldMessages = response.messages.reversed()
                messages.insert(contentsOf: oldMessages, at: 0)
            }

            hasMoreMessages = response.hasMore
            nextCursor = response.nextCursor

        } catch {
            self.error = error.localizedDescription

            if messages.isEmpty {
                messages = ChatMessage.sampleMessages.filter { $0.category == selectedCategory.rawValue }
            }
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentMessage: ChatMessage) async {
        guard let index = messages.firstIndex(where: { $0.id == currentMessage.id }),
              index < 5,
              hasMoreMessages,
              !isLoading else { return }

        await loadMessages()
    }

    func sendMessage() async {
        guard let cityId = currentCityId,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let content = messageText
        messageText = ""
        isSending = true
        error = nil

        do {
            let message = try await chatService.sendMessage(
                to: cityId,
                category: selectedCategory,
                content: content
            )
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            self.error = error.localizedDescription
            messageText = content
        }

        isSending = false
    }

    // MARK: - Private

    private func handleNewMessage(_ message: ChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        guard message.cityId == currentCityId else { return }
        guard message.category == selectedCategory.rawValue else { return }

        messages.append(message)
    }
}
