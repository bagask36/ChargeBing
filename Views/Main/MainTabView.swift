import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StationsMapView()
                .tabItem {
                    Label("Peta SPKLU", systemImage: "map.fill")
                }
                .tag(0)

            SessionsListView()
                .tabItem {
                    Label("Sesi Pengisian", systemImage: "bolt.fill")
                }
                .tag(1)

            EvCatalogView()
                .tabItem {
                    Label("Mobil Listrik", systemImage: "car.side.fill")
                }
                .tag(2)

            StatsView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar.xaxis")
                }
                .tag(3)
        }
        .tint(Color.emerald)
    }
}

