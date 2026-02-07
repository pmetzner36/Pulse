import SwiftUI
import MapKit

struct MoodMapView: View {
    @Bindable private var preferences = UserPreferences.shared
    @State private var moodService = MoodService.shared
    @State private var selectedPin: MapMoodPin?
    @State private var showingDetail = false
    @State private var showingCitySelector = false
    @State private var showingMoodSubmission = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var cityRegion: MKCoordinateRegion {
        let city = preferences.selectedCity
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Map
                Map(position: $cameraPosition) {
                    ForEach(moodService.mapPins) { pin in
                        Annotation("", coordinate: CLLocationCoordinate2D(
                            latitude: pin.latitude,
                            longitude: pin.longitude
                        )) {
                            MoodPinView(rating: pin.rating)
                                .onTapGesture {
                                    selectedPin = pin
                                    showingDetail = true
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))

                // Overlay Controls
                VStack(spacing: 0) {
                    // Top bar with time picker
                    VStack(spacing: 12) {
                        // City selector
                        Button {
                            showingCitySelector = true
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.purple)
                                Text(preferences.selectedCity.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Live")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }

                        // Time window picker
                        Picker("Time", selection: $preferences.timeWindow) {
                            ForEach(TimeWindow.allCases, id: \.self) { window in
                                Text(window.displayName).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(.ultraThinMaterial)

                    Spacer()

                    // Loading indicator
                    if moodService.isLoadingPins {
                        ProgressView()
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }

                    // Empty state
                    if !moodService.isLoadingPins && moodService.mapPins.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No moods shared yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    Spacer()

                    // Me vs City toggle
                    if preferences.showMeVsCity {
                        MeVsCityCard()
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Bottom controls
                    VStack(spacing: 12) {
                        // Action buttons
                        HStack(spacing: 12) {
                            // Share Mood button
                            Button {
                                showingMoodSubmission = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Share Mood")
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                            }

                            // Me vs City toggle
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    preferences.showMeVsCity.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: preferences.showMeVsCity ? "person.fill" : "person")
                                    Text("Me vs City")
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(preferences.showMeVsCity ? Color.purple : Color.gray.opacity(0.3))
                                .foregroundColor(preferences.showMeVsCity ? .white : .primary)
                                .cornerRadius(20)
                            }
                        }

                        // Rating legend
                        MoodRatingLegend()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("PULSIVITY")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDetail) {
                if let pin = selectedPin {
                    MoodPinDetailSheet(pin: pin)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingCitySelector) {
                CitySelectorView(preferences: preferences)
            }
            .sheet(isPresented: $showingMoodSubmission) {
                MoodSubmissionView()
            }
            .task {
                cameraPosition = .region(cityRegion)
                await fetchPins()
            }
            .onChange(of: preferences.selectedCityId) { _, _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(cityRegion)
                }
                Task { await fetchPins() }
            }
            .onChange(of: preferences.timeWindow) { _, _ in
                Task { await fetchPins() }
            }
            .onChange(of: showingMoodSubmission) { _, newValue in
                if !newValue {
                    Task { await fetchPins() }
                }
            }
        }
    }

    private func fetchPins() async {
        await moodService.fetchMapPins(
            cityId: preferences.selectedCityId,
            minutes: preferences.timeWindow.minutes
        )
    }
}

// MARK: - Mood Pin View
struct MoodPinView: View {
    let rating: Int

    private var moodRating: MoodRating {
        MoodRating(rawValue: rating) ?? .neutral
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(moodRating.color)
                .frame(width: 40, height: 40)
                .shadow(color: moodRating.color.opacity(0.5), radius: 4, y: 2)

            Text(moodRating.emoji)
                .font(.system(size: 20))
        }
    }
}

// MARK: - Mood Rating Legend
struct MoodRatingLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(MoodRating.allCases, id: \.self) { rating in
                HStack(spacing: 4) {
                    Circle()
                        .fill(rating.color)
                        .frame(width: 10, height: 10)
                    Text(rating.emoji)
                        .font(.caption2)
                }
            }
        }
    }
}

// MARK: - Me vs City Card
struct MeVsCityCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.purple)
                Text("Your Mood vs City")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                MoodMeter(label: "Stress", value: 0.35, cityValue: 0.52, lowColor: .blue, highColor: .red)
                MoodMeter(label: "Energy", value: 0.65, cityValue: 0.58, lowColor: .orange, highColor: .green)
            }

            Text("You're calmer and more energized than the city average")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

struct MoodMeter: View {
    let label: String
    let value: Float
    let cityValue: Float
    let lowColor: Color
    let highColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 80)

                // City marker
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 50, height: 3)
                    .offset(y: -CGFloat(cityValue) * 77)

                // Personal bar
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [lowColor, highColor], startPoint: .bottom, endPoint: .top))
                    .frame(width: 44, height: CGFloat(value) * 80)
            }
            .frame(height: 80)

            // Labels
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(Color.purple).frame(width: 6, height: 6)
                    Text("\(Int(value * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.gray).frame(width: 6, height: 6)
                    Text("\(Int(cityValue * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    MoodMapView()
}
