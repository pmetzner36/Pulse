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
                }
            }
            .task {
                if currentUser.isSignedIn {
                    // Auto-detect location on first open
                    await detectLocationAndConnect()
                }
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

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
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
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChatCategory.allCases) { category in
                        CategoryTab(
                            category: category,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            Task {
                                await viewModel.switchCategory(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGray6).opacity(0.5))

            // Posts entry point
            NavigationLink {
                SubgroundsListView(
                    cityId: preferences.selectedCityId,
                    cityName: preferences.selectedCity.name,
                    category: viewModel.selectedCategory
                )
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.selectedCategory.color)
                        .frame(width: 36, height: 36)
                        .background(viewModel.selectedCategory.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.selectedCategory.displayName) Posts")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Share with your community")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6).opacity(0.8))
            }
        }
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
