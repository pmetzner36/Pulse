import SwiftUI

struct MoodPinDetailSheet: View {
    let pin: MapMoodPin
    @Environment(\.dismiss) private var dismiss

    private var moodRating: MoodRating {
        MoodRating(rawValue: pin.rating) ?? .neutral
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with rating emoji
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(moodRating.color.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Circle()
                                .fill(moodRating.color)
                                .frame(width: 80, height: 80)
                                .shadow(color: moodRating.color.opacity(0.4), radius: 10)

                            Text(moodRating.emoji)
                                .font(.system(size: 36))
                        }

                        Text("\(moodRating.emoji) \(moodRating.label)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top)

                    // Category chips
                    if !pin.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categories")
                                .font(.headline)

                            FlowLayout(spacing: 8) {
                                ForEach(pin.categories, id: \.self) { category in
                                    let topic = MoodTopic(rawValue: category)
                                    HStack(spacing: 4) {
                                        if let topic = topic {
                                            Image(systemName: topic.icon)
                                                .font(.caption)
                                        }
                                        Text(category)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background((topic?.color ?? .gray).opacity(0.15))
                                    .foregroundColor(topic?.color ?? .primary)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // Time and user info
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Shared \(pin.timestamp.relativeDescription)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                            Text(pin.username)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Privacy note
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("All mood data is shared anonymously")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Flow Layout for category chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Date Relative Description
extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    MoodPinDetailSheet(pin: MapMoodPin(
        id: "preview",
        username: "j***",
        rating: 4,
        categories: ["Political", "Social"],
        timestamp: Date().addingTimeInterval(-3600),
        latitude: 37.7749,
        longitude: -122.4194
    ))
}
