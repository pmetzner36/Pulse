import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MoodMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(0)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }
                .tag(1)

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.purple)
    }
}

#Preview {
    ContentView()
}
