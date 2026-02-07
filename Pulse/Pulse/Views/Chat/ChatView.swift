import SwiftUI

struct ChatView: View {
    @Bindable private var preferences = UserPreferences.shared
    @State private var currentUser = CurrentUser.shared
    @State private var viewModel = ChatViewModel()
    @State private var locationService = LocationService.shared
    @State private var showCitySelector = false
    @State private var showSubgrounds = false
    @State private var isDetectingLocation = false
    @State private var showLocationBanner = false
    @State private var subgroundsVM = SubgroundsListViewModel()
    @State private var showCreateSubground = false
    @State private var selectedSubground: Subground?

    private var isInDetectedCity: Bool {
        locationService.currentCity?.id == preferences.selectedCityId
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentUser.isSignedIn {
                    chatContent
                } else {
                    signInPrompt
                }
            }
            .navigationTitle(preferences.selectedCity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    cityHeaderButton
                }

                ToolbarItem(placement: .topBarLeading) {
                    if isDetectingLocation {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if !isInDetectedCity && locationService.currentCity != nil {
                        Button {
                            if let city = locationService.currentCity {
                                preferences.selectCity(city)
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.subheadline)
                                .foregroundStyle(.purple)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading && !viewModel.messages.isEmpty {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .sheet(isPresented: $showCitySelector) {
                CitySelectorView(preferences: preferences)
            }
            .onChange(of: preferences.selectedCityId) { _, _ in
                Task {
                    await viewModel.connect(to: preferences.selectedCity, category: viewModel.selectedCategory)
                    await subgroundsVM.loadSubgrounds(
                        for: preferences.selectedCityId,
                        category: viewModel.selectedCategory,
                        refresh: true
                    )
                }
            }
            .task {
                if currentUser.isSignedIn {
                    // Auto-detect location on first open
                    await detectLocationAndConnect()
                }
                await subgroundsVM.loadSubgrounds(
                    for: preferences.selectedCityId,
                    category: viewModel.selectedCategory
                )
            }
            .onDisappear {
                viewModel.disconnect()
            }
        }
    }

    // MARK: - Location Detection

    private func detectLocationAndConnect() async {
        isDetectingLocation = true

        // Try to detect current location
        if let detectedCity = await locationService.detectCurrentCity() {
            // If we detected a city, show banner briefly
            if detectedCity.id != preferences.selectedCityId {
                showLocationBanner = true
                // Auto-dismiss banner after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showLocationBanner = false
                }
            }
        }

        isDetectingLocation = false

        // Connect to chat for the selected city
        await viewModel.connect(to: preferences.selectedCity)
    }

    // MARK: - City Header Button

    private var cityHeaderButton: some View {
        Button {
            showCitySelector = true
        } label: {
            HStack(spacing: 4) {
                if isInDetectedCity {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                Text(preferences.selectedCity.name)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Location banner
            if isInDetectedCity {
                localAreaBanner
            } else if showLocationBanner, let detectedCity = locationService.currentCity {
                differentAreaBanner(detectedCity: detectedCity)
            }

            // Category tabs
            categoryTabs

            // Scrollable content: posts + chat
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Inline posts for selected category
                        inlinePosts

                        Divider()
                            .padding(.vertical, 4)

                        // Chat messages
                        LazyVStack(spacing: 4) {
                            if viewModel.hasMoreMessages && !viewModel.messages.isEmpty {
                                ProgressView()
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMessages()
                                        }
                                    }
                            }

                            ForEach(viewModel.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMoreIfNeeded(currentMessage: message)
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    if newCount > oldCount, let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error banner
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Retry") {
                        Task {
                            await viewModel.loadMessages()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }

            // Input
            ChatInputView(
                text: $viewModel.messageText,
                isSending: viewModel.isSending,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
        }
        .sheet(isPresented: $showCreateSubground) {
            CreateSubgroundView(
                cityId: preferences.selectedCityId,
                cityName: preferences.selectedCity.name,
                category: viewModel.selectedCategory
            ) { subground in
                selectedSubground = subground
            }
        }
        .navigationDestination(item: $selectedSubground) { subground in
            SubgroundDetailView(subground: subground)
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatCategory.allCases) { category in
                    CategoryTab(
                        category: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        Task {
                            await viewModel.switchCategory(category)
                            await subgroundsVM.loadSubgrounds(
                                for: preferences.selectedCityId,
                                category: category
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6).opacity(0.5))
    }

    // MARK: - Inline Posts

    private var inlinePosts: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("\(viewModel.selectedCategory.displayName) Posts")
                    .font(.headline)
                Spacer()
                Button {
                    showCreateSubground = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if subgroundsVM.isLoading && subgroundsVM.subgrounds.isEmpty {
                ProgressView("Loading posts...")
                    .padding()
            } else if subgroundsVM.subgrounds.isEmpty {
                VStack(spacing: 8) {
                    Text("No posts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Be the first to post!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            } else {
                ForEach(subgroundsVM.subgrounds) { subground in
                    Button {
                        selectedSubground = subground
                    } label: {
                        SubgroundRowView(subground: subground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 14)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Location Banners

    private var localAreaBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption)
            Text("You're chatting with people in your area")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.purple.gradient)
    }

    private func differentAreaBanner(detectedCity: City) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location")
                .font(.caption)
            Text("You're near \(detectedCity.name)")
                .font(.caption)
            Spacer()
            Button("Switch") {
                preferences.selectCity(detectedCity)
                showLocationBanner = false
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: Capsule())

            Button {
                showLocationBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.gradient)
    }

    // MARK: - Sign In Prompt

    private var signInPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple.opacity(0.5))

            VStack(spacing: 8) {
                Text("Join the Conversation")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Sign in to chat with others in \(preferences.selectedCity.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            NavigationLink {
                SignInView()
            } label: {
                Text("Sign In")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(.purple, in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let category: ChatCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? category.color : Color(.systemGray5),
                in: Capsule()
            )
        }
    }
}

#Preview {
    ChatView()
}
