import SwiftUI

struct SubgroundDetailView: View {
    let subground: Subground

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SubgroundDetailViewModel
    @State private var showCreatePost = false
    @State private var selectedPost: SubgroundMessage?
    @State private var editingPost: SubgroundMessage?

    init(subground: Subground) {
        self.subground = subground
        self._viewModel = State(initialValue: SubgroundDetailViewModel(subground: subground))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView("Loading posts...")
                        .padding(.top, 40)
                } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ForEach(viewModel.posts) { post in
                        PostCardView(post: post, onReaction: { emoji in
                            Task {
                                await viewModel.toggleReaction(on: post, emoji: emoji)
                            }
                        }, onDelete: {
                            Task {
                                await viewModel.deletePost(post)
                            }
                        }, onEdit: {
                            editingPost = post
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPost = post
                        }
                    }

                    if viewModel.hasMorePosts && !viewModel.posts.isEmpty {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task {
                                    await viewModel.loadPosts()
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subground.displayName)
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

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreatePost = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(subgroundId: subground.id) { newPost in
                viewModel.addPost(newPost)
            }
        }
        .sheet(item: $editingPost) { post in
            EditPostView(post: post, subgroundId: subground.id) { updated in
                viewModel.updatePost(updated)
            }
        }
        .navigationDestination(item: $selectedPost) { post in
            PostDetailView(subgroundId: subground.id, post: post)
        }
        .task {
            await viewModel.loadPosts()
        }
        .refreshable {
            await viewModel.loadPosts(refresh: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundStyle(.purple.opacity(0.5))
                .padding(.top, 60)

            Text("No Posts Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Be the first to post in \(subground.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showCreatePost = true
            } label: {
                Label("Create Post", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.purple, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SubgroundDetailViewModel.PostSortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.postSortOption = option
                    Task {
                        await viewModel.loadPosts(refresh: true)
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

// MARK: - SubgroundInputView (reused by PostDetailView for comments)

struct SubgroundInputView: View {
    @Binding var text: String
    let isSending: Bool
    let placeholder: String
    let onSend: () -> Void

    init(text: Binding<String>, isSending: Bool, placeholder: String = "Message...", onSend: @escaping () -> Void) {
        self._text = text
        self.isSending = isSending
        self.placeholder = placeholder
        self.onSend = onSend
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))

            Button {
                onSend()
            } label: {
                if isSending {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .purple)
                }
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        SubgroundDetailView(subground: Subground.samples[0])
    }
}
