import SwiftUI

struct EditPostView: View {
    let post: SubgroundMessage
    let subgroundId: String
    let onSave: (SubgroundMessage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var urlString: String
    @State private var isSubmitting = false
    @State private var error: String?

    init(post: SubgroundMessage, subgroundId: String, onSave: @escaping (SubgroundMessage) -> Void) {
        self.post = post
        self.subgroundId = subgroundId
        self.onSave = onSave
        self._title = State(initialValue: post.title ?? "")
        self._content = State(initialValue: post.content)
        self._urlString = State(initialValue: post.url ?? "")
    }

    private var isValid: Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedContent.isEmpty || !trimmedUrl.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if post.title != nil || !title.isEmpty {
                            TextField("Title", text: $title)
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        TextField("What's on your mind?", text: $content, axis: .vertical)
                            .font(.body)
                            .lineLimit(3...20)

                        if post.resolvedPostType == .link || post.resolvedPostType == .image {
                            HStack(spacing: 8) {
                                Image(systemName: post.resolvedPostType == .link ? "link" : "photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("URL", text: $urlString)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                        }

                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await savePost()
                        }
                    } label: {
                        Text("Save")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                isValid && !isSubmitting ? Color.purple : Color.purple.opacity(0.4),
                                in: Capsule()
                            )
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    private func savePost() async {
        isSubmitting = true
        error = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let updated = try await SubgroundService.shared.editPost(
                subgroundId: subgroundId,
                postId: post.id,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                content: trimmedContent.isEmpty ? nil : trimmedContent,
                url: trimmedUrl.isEmpty ? nil : trimmedUrl
            )
            onSave(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}
