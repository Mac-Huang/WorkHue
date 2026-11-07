import SwiftUI

private enum MainTab { case overview, statistics, track }

struct RootView: View {
    @Environment(TimeStore.self) private var store
    @State private var tab = MainTab.overview
    @State private var showSettings = false

    var body: some View {
        TabView(selection: $tab) {
            navigationScreen("Overview") { OverviewView() }
                .tabItem { Label("Home", systemImage: "calendar").environment(\.symbolVariants, .none) }
                .tag(MainTab.overview)
            navigationScreen("Statistics") { StatisticsView() }
                .tabItem { Label("Statistics", systemImage: "chart.bar.fill").environment(\.symbolVariants, .none) }
                .tag(MainTab.statistics)
            navigationScreen("Track") { TrackView() }
                .tabItem { Label(store.activeSession == nil ? "OUT" : "IN", systemImage: store.activeSession == nil ? "circle" : "poweron").environment(\.symbolVariants, .none) }
                .tag(MainTab.track)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("Cannot Save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private func navigationScreen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gear")
                                .font(.system(size: 23))
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settingsButton")
                    }
                }
        }
    }
}

struct SoftCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 15))
    }
}

extension Color {
    static var cardBackground: Color { Color(uiColor: .secondarySystemBackground) }
    static var overviewCard: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 11/255, green: 11/255, blue: 13/255, alpha: 1) : .secondarySystemBackground
        })
    }
}
