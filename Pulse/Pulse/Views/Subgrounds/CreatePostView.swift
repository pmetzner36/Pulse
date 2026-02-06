import SwiftUI

struct CreatePostView: View {
    let subgroundId: String
    let onPostCreated: (SubgroundMessage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var urlString = ""
    @State private var imageUrlString = ""
    @State private var linkPreview: LinkPreviewData?
    @State private var isLoadingPreview = false
    @State private var isSubmitting = false
    @State private var error: String?

    @State private var showTitle = false
    @State private var showLinkField = false
    @State private var showImageField = false

    @State private var previewDebounceTask: Task<Void, Never>?
    @FocusState private var contentFocused: Bool

    // Infer post type from attachments
    private var inferredPostType: PostType {
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageUrl = imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedImageUrl.isEmpty {
            return .image
        } else if !trimmedUrl.isEmpty || detectedUrl != nil {
            return .link
        }
        return .text
    }

    // Auto-detect URL from content text
    private var detectedUrl: String? {
        let pattern = "https?://[^\\s]+"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range, in: content) else {
            return nil
        }
        return String(content[range])
    }

    // Effective URL for the post (manual attachment takes priority)
    private var effectiveUrl: String? {
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedImageUrl = imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedImageUrl.isEmpty { return trimmedImageUrl }
        if !trimmedUrl.isEmpty { return trimmedUrl }
        return detectedUrl
    }

    private var isValid: Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !trimmedContent.isEmpty
        let hasUrl = effectiveUrl != nil
        return hasContent || hasUrl
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Optional title field
                        if showTitle {
                            TextField("Title", text: $title)
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        // Main content area
                        TextField("What's on your mind?", text: $content, axis: .vertical)
                            .font(.body)
                            .lineLimit(3...20)
                            .focused($contentFocused)
                            .onChange(of: content) { _, newValue in
                                handleContentChange(newValue)
                            }

                        // Auto-detected or manual link preview
                        if let preview = linkPreview, let url = effectiveUrl {
                            LinkPreviewCardView(url: url, preview: preview)
                        } else if isLoadingPreview {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading preview...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        // Image preview
                        if !imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let url = URL(string: imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                case .failure:
                                    Label("Could not load image", systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        // Error message
                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .padding()
                }

                // Attachment bar (pinned to bottom)
                VStack(spacing: 0) {
                    // Expandable link URL input
                    if showLinkField {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("https://example.com", text: $urlString)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.subheadline)
                                .onChange(of: urlString) { _, newValue in
                                    fetchPreviewDebounced(for: newValue)
                                }
                            Button {
                                urlString = ""
                                linkPreview = nil
                                showLinkField = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                    }

                    // Expandable image URL input
                    if showImageField {
                        HStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("https://example.com/image.jpg", text: $imageUrlString)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.subheadline)
                            Button {
                                imageUrlString = ""
                                showImageField = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                    }

                    Divider()

                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTitle.toggle()
                            }
                        } label: {
                            Text("Aa")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(showTitle ? .purple : .secondary)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showLinkField.toggle()
                                if showLinkField { showImageField = false }
                            }
                        } label: {
                            Image(systemName: "link")
                                .font(.subheadline)
                                .foregroundStyle(showLinkField ? .purple : .secondary)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showImageField.toggle()
                                if showImageField { showLinkField = false }
                            }
                        } label: {
                            Image(systemName: "photo")
                                .font(.subheadline)
                                .foregroundStyle(showImageField ? .purple : .secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .background(.bar)
            }
            .navigationTitle("New Post")
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
                            await submitPost()
                        }
                    } label: {
                        Text("Post")
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
            .onAppear {
                contentFocused = true
            }
        }
    }

    // MARK: - Auto-Link Detection

    private func handleContentChange(_ newValue: String) {
        // Only auto-fetch preview if no manual link/image attachment
        guard urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if let detected = detectedUrl {
            fetchPreviewDebounced(for: detected)
        } else {
            previewDebounceTask?.cancel()
            linkPreview = nil
            isLoadingPreview = false
        }
    }

    // MARK: - Link Preview

    private func fetchPreviewDebounced(for url: String) {
        previewDebounceTask?.cancel()
        linkPreview = nil

        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return }

        previewDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }

            isLoadingPreview = true
            do {
                let preview = try await SubgroundService.shared.fetchLinkPreview(url: trimmed)
                if !Task.isCancelled {
                    linkPreview = preview
                }
            } catch {
                // Preview fetch failed silently
            }
            isLoadingPreview = false
        }
    }

    // MARK: - Submit

    private func submitPost() async {
        isSubmitting = true
        error = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        let postType = inferredPostType
        let postUrl = effectiveUrl

        do {
            let post = try await SubgroundService.shared.createPost(
                subgroundId: subgroundId,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                content: trimmedContent.isEmpty ? nil : trimmedContent,
                postType: postType,
                url: postUrl
            )
            onPostCreated(post)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}

#Preview {
    CreatePostView(subgroundId: "1") { _ in }
}
