import SwiftUI

struct InsightsView: View {
    @State private var viewModel = InsightsViewModel()

    private var cityId: String { UserPreferences.shared.selectedCityId }
    private var cityName: String { UserPreferences.shared.selectedCity.name }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.summary == nil {
                        ProgressView("Loading insights...")
                            .padding(.top, 60)
                    } else if !viewModel.hasData && !viewModel.isLoading {
                        emptyState
                    } else {
                        // Summary Card
                        SummaryCard(viewModel: viewModel)
                            .padding(.horizontal)

                        // Generated Insights
                        if !viewModel.insights.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Latest Insights")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(viewModel.insights) { insight in
                                    InsightCardView(insight: insight)
                                        .padding(.horizontal)
                                }
                            }
                        }

                        // Category Moods
                        if !viewModel.aggregates.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category Moods")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.aggregates) { agg in
                                            CategoryMoodCard(aggregate: agg)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }

                        // News by Category
                        if !viewModel.categoryNews.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Trending News")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(viewModel.categoryNews) { catNews in
                                    if let item = catNews.news.first {
                                        NewsBannerView(category: catNews.category, newsItem: item)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }

                        // Category Breakdown Table
                        if !viewModel.categoryBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mood by Category")
                                    .font(.headline)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    ForEach(viewModel.categoryBreakdown) { cat in
                                        CategoryBreakdownRow(category: cat)
                                    }
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
                                .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
            .task {
                await viewModel.loadData(for: cityId)
            }
            .refreshable {
                await viewModel.loadData(for: cityId, forceRefresh: true)
            }
            .onChange(of: UserPreferences.shared.selectedCityId) { _, newCityId in
                Task {
                    await viewModel.loadData(for: newCityId, forceRefresh: true)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundStyle(.purple.opacity(0.5))
                .padding(.top, 60)

            Text("No Mood Data Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Be the first to submit a mood report for \(cityName). Insights will appear once people start sharing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let viewModel: InsightsViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.cityName)
                        .font(.headline)
                    Text(viewModel.overallLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(viewModel.overallEmoji)
                    .font(.system(size: 40))
            }

            Divider()

            HStack(spacing: 24) {
                SummaryMetric(
                    label: "Rating",
                    value: String(format: "%.1f", viewModel.overallRating),
                    color: ratingColor(viewModel.overallRating)
                )
                SummaryMetric(
                    label: "Reports",
                    value: "\(viewModel.totalSubmissions)",
                    color: .purple
                )
                SummaryMetric(
                    label: "Categories",
                    value: "\(viewModel.categoryBreakdown.count)",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func ratingColor(_ rating: Double) -> Color {
        switch rating {
        case ..<2.0: return .red
        case 2.0..<3.0: return .orange
        case 3.0..<4.0: return .blue
        default: return .green
        }
    }
}

struct SummaryMetric: View {
    let label: String
    let value: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Insight Card View

struct InsightCardView: View {
    let insight: InsightCard

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(insight.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
    }
}

// MARK: - Category Mood Card

struct CategoryMoodCard: View {
    let aggregate: MoodAggregateResponse

    private var topic: MoodTopic? {
        MoodTopic(rawValue: aggregate.category)
    }

    private var trendDirection: TrendDirection {
        TrendDirection(rawValue: aggregate.trend) ?? .stable
    }

    private var ratingEmoji: String {
        switch aggregate.averageRating {
        case ..<1.5: return "😢"
        case 1.5..<2.5: return "😕"
        case 2.5..<3.5: return "😐"
        case 3.5..<4.5: return "🙂"
        default: return "😊"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((topic?.color ?? .gray).opacity(0.2))
                    .frame(width: 50, height: 50)

                Text(ratingEmoji)
                    .font(.title2)
            }

            VStack(spacing: 4) {
                Text(aggregate.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: trendDirection.icon)
                        .font(.caption2)
                    Text(String(format: "%.1f", aggregate.averageRating))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)

                Text("\(aggregate.submissionCount) votes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 100)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
    }
}

// MARK: - Category Breakdown Row

struct CategoryBreakdownRow: View {
    let category: CategoryMood

    private var topic: MoodTopic? {
        MoodTopic(rawValue: category.category)
    }

    private var ratingColor: Color {
        switch category.averageRating {
        case ..<2.0: return .red
        case 2.0..<3.0: return .orange
        case 3.0..<4.0: return .blue
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: topic?.icon ?? "questionmark.circle")
                .font(.subheadline)
                .foregroundStyle(topic?.color ?? .gray)
                .frame(width: 30)

            Text(category.category)
                .font(.subheadline)

            Spacer()

            // Rating bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ratingColor)
                        .frame(width: geo.size.width * CGFloat(category.averageRating / 5.0), height: 8)
                }
            }
            .frame(width: 80, height: 8)

            Text(String(format: "%.1f", category.averageRating))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(ratingColor)
                .frame(width: 30, alignment: .trailing)

            Text("(\(category.count))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - News Banner View

struct NewsBannerView: View {
    let category: String
    let newsItem: NewsItem

    private var topic: MoodTopic? {
        MoodTopic(rawValue: category)
    }

    var body: some View {
        Link(destination: URL(string: newsItem.link) ?? URL(string: "https://news.google.com")!) {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: topic?.icon ?? "newspaper.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(topic?.color ?? .gray)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(topic?.color ?? .secondary)
                        .textCase(.uppercase)

                    Text(newsItem.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(newsItem.source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

#Preview {
    InsightsView()
}
