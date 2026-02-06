import SwiftUI

struct LinkPreviewCardView: View {
    let url: String
    let preview: LinkPreviewData?

    var body: some View {
        Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
            VStack(alignment: .leading, spacing: 0) {
                // OG Image
                if let imageUrl = preview?.imageUrl, let imgURL = URL(string: imageUrl) {
                    AsyncImage(url: imgURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 180)
                                .clipped()
                        case .failure:
                            imagePlaceholder
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 100)
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let title = preview?.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    if let description = preview?.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // Domain
                    if let host = URL(string: url)?.host {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(host)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 80)
            .overlay {
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    LinkPreviewCardView(
        url: "https://example.com/article",
        preview: LinkPreviewData(
            title: "Example Article Title",
            description: "This is a description of the linked article that provides context.",
            imageUrl: nil
        )
    )
    .padding()
}
