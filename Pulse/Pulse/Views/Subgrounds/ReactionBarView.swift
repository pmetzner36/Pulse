import SwiftUI

struct ReactionBarView: View {
    let reactions: [ReactionInfo]
    let onReaction: (String) -> Void

    @State private var showReactionPicker = false

    private let quickReactions = ["👍", "❤️", "😂", "🔥", "😢", "😮"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.emoji) { reaction in
                Button {
                    onReaction(reaction.emoji)
                } label: {
                    HStack(spacing: 2) {
                        Text(reaction.emoji)
                            .font(.caption)
                        Text("\(reaction.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        reaction.userReacted ? Color.purple.opacity(0.2) : Color(.systemGray5),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(reaction.userReacted ? Color.purple : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                showReactionPicker = true
            } label: {
                Image(systemName: "face.smiling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Color(.systemGray5), in: Circle())
            }
            .popover(isPresented: $showReactionPicker) {
                HStack(spacing: 8) {
                    ForEach(quickReactions, id: \.self) { emoji in
                        Button {
                            onReaction(emoji)
                            showReactionPicker = false
                        } label: {
                            Text(emoji)
                                .font(.title2)
                        }
                    }
                }
                .padding()
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

#Preview {
    ReactionBarView(
        reactions: [
            ReactionInfo(emoji: "👍", count: 5, users: [], userReacted: true),
            ReactionInfo(emoji: "❤️", count: 3, users: [], userReacted: false)
        ],
        onReaction: { _ in }
    )
    .padding()
}
