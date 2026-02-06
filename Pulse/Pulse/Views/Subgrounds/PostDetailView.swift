import SwiftUI

struct PostDetailView: View {
    let subgroundId: String
    let post: SubgroundMessage

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PostDetailViewModel
    @State private var showEditPost = false
    @State private var editingComment: SubgroundMessage?
    @State private var editCommentText = ""

    init(subgroundId: String, post: SubgroundMessage) {
        self.subgroundId = subgroundId
        self.post = post
        self._viewModel = State(initialValue: PostDetailViewModel(subgroundId: subgroundId, post: post))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Full post content
                    postContent

                    Divider()
                        .padding(.vertical, 12)

                    // Comments header
                    HStack {
                        Text("Comments")
                            .font(.headline)
                        Text("(\(viewModel.comments.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Comments list
                    if viewModel.isLoading && viewModel.comments.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else if viewModel.comments.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 8) {
                            Text("No comments yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Be the first to comment")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.comments) { comment in
                                CommentView(comment: comment, onReaction: { emoji in
                                    Task {
                                        await viewModel.toggleReaction(on: comment, emoji: emoji)
                                    }
                                }, onEdit: {
                                    editCommentText = comment.content
                                    editingComment = comment
                                }, onDelete: {
                                    Task {
                                        await viewModel.deleteComment(comment)
                                    }
                                })
                            }

                            if viewModel.hasMoreComments && !viewModel.comments.isEmpty {
                                ProgressView()
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await viewModel.loadComments()
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }

            // Error banner
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }

            // Comment input
            CommentInputView(viewModel: viewModel)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                        Text("Back")
                    }
                    .foregroundStyle(.purple)
                }
            }

            if viewModel.post.isFromCurrentUser {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditPost = true
                        } label: {
                            Label("Edit Post", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            Task {
                                try await SubgroundService.shared.deletePost(
                                    subgroundId: subgroundId,
                                    postId: post.id
                                )
                                dismiss()
                            }
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditPost) {
            EditPostView(post: viewModel.post, subgroundId: subgroundId) { updated in
                viewModel.post = updated
            }
        }
        .alert("Edit Comment", isPresented: Binding(
            get: { editingComment != nil },
            set: { if !$0 { editingComment = nil } }
        )) {
            TextField("Comment", text: $editCommentText)
            Button("Save") {
                if let comment = editingComment {
                    Task {
                        await viewModel.editComment(comment, content: editCommentText)
                    }
                }
                editingComment = nil
            }
            Button("Cancel", role: .cancel) {
                editingComment = nil
            }
        }
        .task {
            await viewModel.loadComments()
        }
    }

    // MARK: - Post Content

    private var postContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Author + timestamp
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("@\(viewModel.post.username)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(viewModel.post.formattedPostDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if let postType = viewModel.post.postType, postType != "text" {
                    Label(viewModel.post.resolvedPostType.displayName, systemImage: viewModel.post.resolvedPostType.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5), in: Capsule())
                }
            }

            // Title
            if let title = viewModel.post.title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            // Content by type
            switch viewModel.post.resolvedPostType {
            case .text:
                if !viewModel.post.content.isEmpty {
                    Text(viewModel.post.content)
                        .font(.body)
                }
            case .link:
                if let url = viewModel.post.url {
                    LinkPreviewCardView(url: url, preview: viewModel.post.linkPreview)
                }
                if !viewModel.post.content.isEmpty {
                    Text(viewModel.post.content)
                        .font(.body)
                        .padding(.top, 4)
                }
            case .image:
                if let url = viewModel.post.url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(height: 150)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 100)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                if !viewModel.post.content.isEmpty {
                    Text(viewModel.post.content)
                        .font(.body)
                        .padding(.top, 4)
                }
            }

            // Reaction bar
            ReactionBarView(reactions: viewModel.post.reactions) { emoji in
                Task {
                    await viewModel.toggleReaction(on: viewModel.post, emoji: emoji)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Comment View

struct CommentView: View {
    let comment: SubgroundMessage
    let onReaction: (String) -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Username + timestamp
            HStack(spacing: 6) {
                Text("@\(comment.username)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(comment.formattedPostDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            // Comment content
            Text(comment.content)
                .font(.subheadline)

            // Link preview
            if let url = comment.url {
                LinkPreviewCardView(url: url, preview: comment.linkPreview)
            }

            // Reactions
            if !comment.reactions.isEmpty {
                ReactionBarView(reactions: comment.reactions, onReaction: onReaction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button {
                UIPasteboard.general.string = comment.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            if comment.isFromCurrentUser {
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Comment", systemImage: "pencil")
                    }
                }
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Comment", systemImage: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - Comment Input View

struct CommentInputView: View {
    @Bindable var viewModel: PostDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showLinkField {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://...", text: $viewModel.commentURL)
                        .font(.subheadline)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        viewModel.commentURL = ""
                        viewModel.showLinkField = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.showLinkField.toggle()
                } label: {
                    Image(systemName: "link.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.showLinkField ? .purple : .secondary)
                }

                TextField("Add a comment...", text: $viewModel.commentText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))

                Button {
                    Task {
                        await viewModel.sendComment()
                    }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(viewModel.commentText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .purple)
                    }
                }
                .disabled(viewModel.commentText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(
            subgroundId: "1",
            post: SubgroundMessage.samples[0]
        )
    }
}
