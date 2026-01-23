import SwiftUI

struct HistoryView: View {
    @State private var entries: [VideoEntry] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(entries) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                     DotMatrixText(text: "\(entries.count) ITEMS")
                }
            }
            .onAppear {
                loadEntries()
            }
        }
    }
    
    private func loadEntries() {
        // Fetch from DB (Mock for now or real if DB ready)
        // entries = DatabaseManager.shared.fetchEntries()
        // Mock data for UI Preview
        entries = [
            VideoEntry(title: "Test Video 1", url: "https://youtube.com/watch?v=123", service: "YouTube", status: .completed),
            VideoEntry(title: "Another Clip", url: "https://tiktok.com/@user/video/123", service: "TikTok", status: .failed)
        ]
    }
}

struct HistoryRow: View {
    let entry: VideoEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Service Icon
            ServiceIcon(entry.service)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.nothingBody)
                    .lineLimit(1)
                
                Text(entry.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status Indicator
            StatusIndicator(status: entry.status)
        }
        .padding()
        .liquidGlass()
    }
}

struct StatusIndicator: View {
    let status: VideoEntry.DownloadStatus
    
    var body: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignSystem.Colors.nothingRed)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.secondary)
        case .downloading:
            ProgressView()
                .scaleEffect(0.8)
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        }
    }
}
