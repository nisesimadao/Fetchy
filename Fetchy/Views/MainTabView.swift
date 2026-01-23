import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(0)
            
            DownloadView()
                .tabItem {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(DesignSystem.Colors.nothingRed)
    }
}

#Preview {
    MainTabView()
}
