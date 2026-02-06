import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(spacing: 12) {
            // Text field
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)
                .focused($isFocused)

            // Send button
            Button {
                onSend()
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? Color.purple : Color(.systemGray4))
                        .frame(width: 36, height: 36)

                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputView(
            text: .constant(""),
            isSending: false,
            onSend: {}
        )
        ChatInputView(
            text: .constant("Hello there!"),
            isSending: false,
            onSend: {}
        )
        ChatInputView(
            text: .constant("Sending..."),
            isSending: true,
            onSend: {}
        )
    }
}
