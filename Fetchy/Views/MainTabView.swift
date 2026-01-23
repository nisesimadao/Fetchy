import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // View Content
            Group {
                switch selectedTab {
                case 0:
                    HistoryView()
                case 1:
                    DownloadView()
                case 2:
                    SettingsView()
                default:
                    HistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Tab Bar
            NothingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 20)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
}

struct NothingTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs = [
        TabItemData(tag: 0, title: "History", icon: "clock"),
        TabItemData(tag: 1, title: "Download", icon: "arrow.down.circle"),
        TabItemData(tag: 2, title: "Settings", icon: "gearshape")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button(action: {
                    if selectedTab != tab.tag {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab.tag
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                        
                        Text(tab.title.uppercased())
                            .font(.nothingMeta)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selectedTab == tab.tag ? DesignSystem.Colors.nothingRed : .secondary)
                    .background(
                        ZStack {
                            if selectedTab == tab.tag {
                                Circle()
                                    .fill(DesignSystem.Colors.nothingRed.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 72)
        .frame(maxWidth: 340)
        .liquidGlass(cornerRadius: 36)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
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
