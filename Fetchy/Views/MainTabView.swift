import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var splashActive = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Tab 0: History
                NavigationView {
                    HistoryView()
                }
                .tag(0)
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
                
                // Tab 1: Download
                DownloadView()
                    .tag(1)
                    .tabItem {
                        Image(systemName: "arrow.down.circle")
                        Text("Download")
                    }
                    
                // Tab 2: Settings
                NavigationView {
                    SettingsView()
                }
                .tag(2)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
            }
            .accentColor(DesignSystem.Colors.nothingRed)
            
            if splashActive {
                ZStack {
                    Rectangle()
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.fill(.ultraThinMaterial)
                            } else {
                                $0.fill(Color.black.opacity(0.4))
                            }
                        } otherwise: {
                            $0.fill(Color.black.opacity(0.4))
                        }
                        .ignoresSafeArea()
                    
                    SplashVideoView(videoName: "Splash.mov", isActive: $splashActive)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .if(availableiOS: 15.0) {
            if #available(iOS 15.0, *) {
                $0.animation(.easeInOut(duration: 0.8), value: splashActive)
            } else {
                $0
            }
        } otherwise: {
            $0.animation(.easeInOut(duration: 0.8))
        }
    }
}


struct TabItemData: Identifiable {
    let id = UUID()
    let tag: Int
    let title: String
    let icon: String
}

#Preview {
    MainTabView()
}
