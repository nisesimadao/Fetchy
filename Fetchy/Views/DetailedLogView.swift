import SwiftUI

struct DetailedLogView: View {
    @State private var entries: [VideoEntry] = []
    @State private var offset: Int = 0
    private let limit: Int = 20
    
    @State private var selectedLog: String? = nil
    @State private var showingLogViewer = false
    
    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Table Header
                HStack {
                    Text("DATE")
                        .frame(width: 80, alignment: .leading)
                    Text("ID/TITLE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("STATUS")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.nothingMeta)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            VStack(spacing: 0) {
                                Button(action: {
                                    selectedLog = DatabaseManager.shared.fetchRawLog(for: entry.id)
                                    showingLogViewer = true
                                }) {
                                    HStack(alignment: .top) {
                                        // Date
                                        Text(formatDate(entry.date))
                                            .font(.system(.caption2, design: .monospaced))
                                            .frame(width: 80, alignment: .leading)
                                        
                                        // Details
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.id.uuidString.prefix(8) + "...")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                            Text(entry.title)
                                                .font(.nothingBody)
                                                .lineLimit(1)
                                            Text(entry.url)
                                                .font(.system(size: 8))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Status
                                        Text(entry.status.rawValue.uppercased())
                                            .font(.nothingMeta)
                                            .foregroundStyle(statusColor(entry.status))
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .opacity(0.1)
                            }
                        }
                        
                        // "Load More" Button or pagination indicator
                        if entries.count >= limit && entries.count % limit == 0 {
                            Button(action: {
                                loadMore()
                            }) {
                                Text("LOAD MORE (OFFSET: \(offset))")
                                    .font(.nothingMeta)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(DesignSystem.Colors.nothingRed.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("RAW LOGS")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogViewer) {
            logViewerSheet
        }
        .onAppear {
            if entries.isEmpty {
                loadEntries()
            }
        }
    }
    
    private var logViewerSheet: some View {
        NavigationView {
            ScrollView {
                Text(selectedLog ?? "No log detail found.")
                    .font(.system(.caption2, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("RAW LOG OUTPUT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("CLOSE") { showingLogViewer = false }
                        .font(.nothingMeta)
                }
            }
        }
    }

    
    private func loadEntries() {
        let fetched = DatabaseManager.shared.fetchEntries(limit: limit, offset: 0)
        entries = fetched
        offset = limit
    }
    
    private func loadMore() {
        let more = DatabaseManager.shared.fetchEntries(limit: limit, offset: offset)
        if !more.isEmpty {
            entries.append(contentsOf: more)
            offset += limit
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func statusColor(_ status: VideoEntry.DownloadStatus) -> Color {
        switch status {
        case .completed: return DesignSystem.Colors.nothingRed
        case .failed: return .gray
        default: return .secondary
        }
    }
}

#Preview {
    NavigationView {
        DetailedLogView()
    }
}
