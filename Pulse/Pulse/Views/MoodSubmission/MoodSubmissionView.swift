import SwiftUI
import CoreLocation

struct MoodSubmissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var locationService = LocationService.shared
    @State private var moodService = MoodService.shared
    @Bindable private var preferences = UserPreferences.shared
    
    @State private var selectedCategories: Set<MoodTopic> = []
    @State private var rating: Int = 3
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Location Section
                    locationSection
                    
                    // Categories Section
                    categoriesSection
                    
                    // Rating Section
                    ratingSection
                    
                    // Note Section (optional)
                    noteSection
                    
                    // Submit Button
                    submitButton
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Share Your Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Mood Shared!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thanks for sharing how you're feeling about \(preferences.selectedCity.name)!")
            }
            .task {
                if locationService.currentLocation == nil {
                    await locationService.detectCurrentCity()
                }
            }
        }
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "location.fill")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.selectedCity.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(preferences.selectedCity.stateFullName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await locationService.detectCurrentCity()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if locationService.isLocating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.circle.fill")
                        }
                        Text("Detect")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(locationService.isLocating)
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What's on your mind?", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)
            
            Text("Select one or more topics")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MoodTopic.allCases) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Rating Section
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How are you feeling?", systemImage: "face.smiling")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Emoji display
                Text(MoodRating(rawValue: rating)?.emoji ?? "😐")
                    .font(.system(size: 60))
                
                Text(MoodRating(rawValue: rating)?.label ?? "Neutral")
                    .font(.headline)
                    .foregroundStyle(MoodRating(rawValue: rating)?.color ?? .gray)
                
                // Rating slider
                HStack {
                    Text("😢")
                    Slider(value: Binding(
                        get: { Double(rating) },
                        set: { rating = Int($0) }
                    ), in: 1...5, step: 1)
                    .tint(.purple)
                    Text("😊")
                }
                
                // Rating buttons
                HStack(spacing: 8) {
                    ForEach(MoodRating.allCases, id: \.rawValue) { mood in
                        Button {
                            rating = mood.rawValue
                        } label: {
                            Text(mood.emoji)
                                .font(.title2)
                                .padding(8)
                                .background(
                                    rating == mood.rawValue ? mood.color.opacity(0.3) : Color.clear,
                                    in: Circle()
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(rating == mood.rawValue ? mood.color : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Note Section
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add a note (optional)", systemImage: "text.bubble")
                .font(.headline)
            
            TextField("What's happening?", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button {
            Task {
                await submitMood()
            }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSubmitting ? "Sharing..." : "Share Mood")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selectedCategories.isEmpty ? Color.gray : Color.purple,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(selectedCategories.isEmpty || isSubmitting)
    }
    
    // MARK: - Submit
    
    private func submitMood() async {
        isSubmitting = true
        errorMessage = nil
        
        do {
            try await moodService.submitMood(
                cityId: preferences.selectedCityId,
                categories: Array(selectedCategories),
                rating: rating,
                note: note.isEmpty ? nil : note,
                latitude: locationService.currentLocation?.coordinate.latitude,
                longitude: locationService.currentLocation?.coordinate.longitude
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSubmitting = false
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: MoodTopic
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.body)
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : category.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? category.color : category.color.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

#Preview {
    MoodSubmissionView()
}
