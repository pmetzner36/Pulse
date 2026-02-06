import SwiftUI

struct CreateSubgroundView: View {
    let cityId: String
    let cityName: String
    let category: ChatCategory
    var onCreate: ((Subground) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SubgroundsListViewModel()

    @State private var name = ""
    @State private var description = ""
    @State private var selectedEmoji: String?
    @State private var isCreating = false
    @State private var error: String?

    private let emojiOptions = ["💬", "🔥", "💼", "🏠", "☕", "🎮", "📱", "🎵", "⚽", "🍔", "🚗", "✈️", "💰", "❤️", "🎉", "😤", "🤔", "📰"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Community name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Choose a clear name that describes the topic")
                }

                Section("Icon (Optional)") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedEmoji == emoji ? Color.purple.opacity(0.2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedEmoji == emoji ? Color.purple : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    if selectedEmoji == emoji {
                                        selectedEmoji = nil
                                    } else {
                                        selectedEmoji = emoji
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task {
                            await createSubground()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Community")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 3 || isCreating)
                }
            }
            .navigationTitle("New \(category.displayName) Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createSubground() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)

        guard trimmedName.count >= 3 else {
            error = "Name must be at least 3 characters"
            return
        }

        isCreating = true
        error = nil

        viewModel.currentCityId = cityId
        viewModel.currentCategory = category

        if let subground = await viewModel.createSubground(
            name: trimmedName,
            description: trimmedDesc.isEmpty ? nil : trimmedDesc,
            emoji: selectedEmoji
        ) {
            onCreate?(subground)
            dismiss()
        } else {
            error = viewModel.error ?? "Failed to create community"
        }

        isCreating = false
    }
}

#Preview {
    CreateSubgroundView(cityId: "sf", cityName: "San Francisco", category: .political)
}
