import SwiftUI

struct SubgroundsListView: View {
    let cityId: String
    let cityName: String
    let category: ChatCategory

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SubgroundsListViewModel()
    @State private var showCreateSheet = false
    @State private var selectedSubground: Subground?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.subgrounds.isEmpty {
                ProgressView("Loading posts...")
            } else if viewModel.subgrounds.isEmpty {
                emptyState
            } else {
                subgroundsList
            }
        }
        .navigationTitle("\(category.displayName) Posts")
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
                        Text("Chat")
                    }
                    .foregroundStyle(.purple)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                
            }

            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSubgroundView(cityId: cityId, cityName: cityName, category: category) { subground in
                selectedSubground = subground
            }
        }
        .navigationDestination(item: $selectedSubground) { subground in
            SubgroundDetailView(subground: subground)
        }
        .task {
            await viewModel.loadSubgrounds(for: cityId, category: category)
        }
        .refreshable {
            await viewModel.loadSubgrounds(for: cityId, category: category, refresh: true)
        }
    }

    private var subgroundsList: some View {
        List {
            ForEach(viewModel.subgrounds) { subground in
                SubgroundRowView(subground: subground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSubground = subground
                    }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 50))
                .foregroundStyle(category.color.opacity(0.6))

            Text("No \(category.displayName) Posts Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Be the first to post in \(cityName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showCreateSheet = true
            } label: {
                Label("Create Post", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(category.color, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SubgroundsListViewModel.SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                    Task {
                        await viewModel.loadSubgrounds(for: cityId, category: category, refresh: true)
                    }
                } label: {
                    Label(option.displayName, systemImage: option.icon)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }
}

struct SubgroundRowView: View {
    let subground: Subground

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let emoji = subground.emoji {
                    Text(emoji)
                        .font(.title2)
                }

                Text(subground.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(subground.formattedLastActivity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let description = subground.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label("\(subground.memberCount)", systemImage: "person.2.fill")
                Label("\(subground.messageCount)", systemImage: "doc.text.fill")

                Spacer()

                Text("by @\(subground.creatorUsername)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SubgroundsListView(cityId: "sf", cityName: "San Francisco", category: .political)
    }
}
