import Foundation

enum ChatError: Error, LocalizedError {
    case notAuthenticated
    case connectionFailed
    case sendFailed
    case invalidMessage
    case contentModerated(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to chat"
        case .connectionFailed:
            return "Could not connect to chat"
        case .sendFailed:
            return "Failed to send message"
        case .invalidMessage:
            return "Invalid message"
        case .contentModerated(let reason):
            return reason
        }
    }
}

@MainActor
@Observable
final class ChatService {
    static let shared = ChatService()

    private(set) var isConnected = false
    private(set) var isConnecting = false
    private(set) var currentCityId: String?
    private(set) var currentCategory: ChatCategory = .general
    private(set) var connectionError: ChatError?

    private var webSocketTask: URLSessionWebSocketTask?
    private var messageHandlers: [(ChatMessage) -> Void] = []
    private var pollTimer: Timer?

    private let pollingInterval: TimeInterval = 5.0

    private init() {}

    // MARK: - Connection Management

    func connect(to cityId: String, category: ChatCategory = .general) async {
        guard CurrentUser.shared.isSignedIn else {
            connectionError = .notAuthenticated
            return
        }

        // Disconnect if city or category changed
        if currentCityId != cityId || currentCategory != category {
            disconnect()
        }

        currentCityId = cityId
        currentCategory = category
        isConnecting = true
        connectionError = nil

        do {
            try await establishWebSocket(cityId: cityId, category: category)
            isConnected = true
        } catch {
            startPolling(cityId: cityId, category: category)
        }

        isConnecting = false
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        pollTimer?.invalidate()
        pollTimer = nil
        isConnected = false
        currentCityId = nil
    }

    // MARK: - WebSocket

    private func establishWebSocket(cityId: String, category: ChatCategory) async throws {
        guard let tokens = try? KeychainService.shared.loadTokens() else {
            throw ChatError.notAuthenticated
        }

        let wsBase = AppConfiguration.apiBaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let urlString = "\(wsBase)/chat/\(cityId)/ws?token=\(tokens.accessToken)&category=\(category.rawValue)"
        guard let url = URL(string: urlString) else {
            throw ChatError.connectionFailed
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        Task {
            await receiveMessages()
        }
    }

    private func receiveMessages() async {
        guard let webSocket = webSocketTask else { return }

        do {
            while webSocket.state == .running {
                let message = try await webSocket.receive()

                switch message {
                case .string(let text):
                    handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            isConnected = false
            if let cityId = currentCityId {
                startPolling(cityId: cityId, category: currentCategory)
            }
        }
    }

    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let wsMessage = try? decoder.decode(WebSocketMessage.self, from: data) else {
            return
        }

        switch wsMessage.type {
        case .message:
            if let chatMessage = wsMessage.payload?.message {
                notifyHandlers(with: chatMessage)
            }
        case .joined, .left, .typing:
            break
        case .error:
            connectionError = .connectionFailed
        }
    }

    // MARK: - Polling Fallback

    private func startPolling(cityId: String, category: ChatCategory) {
        pollTimer?.invalidate()

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollMessages(cityId: cityId, category: category)
            }
        }

        isConnected = true
    }

    private var lastMessageTimestamp: Date?

    private func pollMessages(cityId: String, category: ChatCategory) async {
        do {
            let response = try await fetchMessages(cityId: cityId, category: category, since: lastMessageTimestamp)
            for message in response.messages {
                notifyHandlers(with: message)
                if lastMessageTimestamp == nil || message.timestamp > lastMessageTimestamp! {
                    lastMessageTimestamp = message.timestamp
                }
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Message Handlers

    func addMessageHandler(_ handler: @escaping (ChatMessage) -> Void) {
        messageHandlers.append(handler)
    }

    func removeAllHandlers() {
        messageHandlers.removeAll()
    }

    private func notifyHandlers(with message: ChatMessage) {
        for handler in messageHandlers {
            handler(message)
        }
    }

    // MARK: - API Calls

    func fetchMessages(cityId: String, category: ChatCategory = .general, cursor: String? = nil, limit: Int = 50, since: Date? = nil) async throws -> MessagesResponse {
        var endpoint = "/chat/\(cityId)/messages?limit=\(limit)&category=\(category.rawValue)"
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        if let since = since {
            let formatter = ISO8601DateFormatter()
            endpoint += "&since=\(formatter.string(from: since))"
        }

        return try await APIClient.shared.request(endpoint: endpoint, method: .get)
    }

    func sendMessage(to cityId: String, category: ChatCategory = .general, content: String) async throws -> ChatMessage {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatError.invalidMessage
        }

        let request = SendMessageRequest(content: content, category: category.rawValue)

        return try await APIClient.shared.request(
            endpoint: "/chat/\(cityId)/messages",
            method: .post,
            body: request
        )
    }

    func fetchRoomInfo(cityId: String, category: ChatCategory = .general) async throws -> ChatRoomInfo {
        return try await APIClient.shared.request(
            endpoint: "/chat/\(cityId)/info?category=\(category.rawValue)",
            method: .get
        )
    }

    func fetchCategories(cityId: String) async throws -> [ChatCategoryInfo] {
        return try await APIClient.shared.request(
            endpoint: "/chat/\(cityId)/categories",
            method: .get
        )
    }
}
