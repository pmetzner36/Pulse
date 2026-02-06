import SwiftUI

struct PostCardView: View {
    let post: SubgroundMessage
    let onReaction: (String) -> Void
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image for link posts (OG image) and image posts
            if post.resolvedPostType == .link {
                if let imageUrl = post.linkPreview?.imageUrl,
                   let imgURL = URL(string: imageUrl) {
                    AsyncImage(url: imgURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 200)
                                .clipped()
                        case .failure:
                            linkPlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(Color(.systemGray6))
                        @unknown default:
                            linkPlaceholder
                        }
                    }
                } else {
                    linkPlaceholder
                }
            } else if post.resolvedPostType == .image,
                      let url = post.url,
                      let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 250)
                            .clipped()
                    case .failure:
                        imageErrorPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(Color(.systemGray6))
                    @unknown default:
                        imageErrorPlaceholder
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                // Author + timestamp header
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("@\(post.username)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(post.formattedPostDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let postType = post.postType, postType != "text" {
                        Image(systemName: post.resolvedPostType.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Title
                if let title = post.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(3)
                }

                // Content by type
                switch post.resolvedPostType {
                case .text:
                    if !post.content.isEmpty {
                        Text(post.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                case .link:
                    // Domain label
                    if let url = post.url, let host = URL(string: url)?.host {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(host)
                                .font(.caption)
                        }
                        .foregroundStyle(.purple)
                    }
                    if !post.content.isEmpty {
                        Text(post.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                case .image:
                    if !post.content.isEmpty {
                        Text(post.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                // Footer: reactions + comment count
                HStack {
                    if !post.reactions.isEmpty {
                        ReactionBarView(reactions: post.reactions, onReaction: onReaction)
                    } else {
                        Button {
                            onReaction("👍")
                        } label: {
                            Image(systemName: "face.smiling")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(4)
                                .background(Color(.systemGray5), in: Circle())
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.caption)
                        Text("\(post.commentCount ?? 0)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .contextMenu {
            if post.isFromCurrentUser {
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Post", systemImage: "pencil")
                    }
                }
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Post", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var linkPlaceholder: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.9))
            if let url = post.url, let host = URL(string: url)?.host {
                Text(host)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            LinearGradient(
                colors: [.purple, .purple.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var imageErrorPlaceholder: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.systemGray5))
            .frame(height: 100)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        PostCardView(
            post: SubgroundMessage.samples[0],
            onReaction: { _ in }
        )
        PostCardView(
            post: SubgroundMessage.samples[1],
            onReaction: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
