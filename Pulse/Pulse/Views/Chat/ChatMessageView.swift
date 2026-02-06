import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage

    private var isFromMe: Bool {
        message.isFromCurrentUser
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                // Username (only for others)
                if !isFromMe {
                    Text("@\(message.username)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                // Message bubble
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromMe ? Color.purple : Color(.systemGray5),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .foregroundStyle(isFromMe ? .white : .primary)

                // Timestamp
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isFromMe {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack(spacing: 8) {
        ChatMessageView(message: ChatMessage(
            id: "1",
            cityId: "sf",
            userId: "other",
            username: "marina_vibes",
            category: "general",
            content: "Anyone else feel like the city energy is wild today?",
            timestamp: Date().addingTimeInterval(-3600)
        ))

        ChatMessageView(message: ChatMessage(
            id: "2",
            cityId: "sf",
            userId: CurrentUser.shared.user?.id ?? "me",
            username: "me",
            category: "general",
            content: "Yeah totally! Downtown is buzzing",
            timestamp: Date().addingTimeInterval(-3000)
        ))

        ChatMessageView(message: ChatMessage(
            id: "3",
            cityId: "sf",
            userId: "other2",
            username: "sunset_walker",
            category: "general",
            content: "It's chill out here in the Sunset though. Very calm vibes, you should come check it out!",
            timestamp: Date().addingTimeInterval(-2400)
        ))
    }
    .padding(.vertical)
}
