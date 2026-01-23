import SwiftUI

struct DetailedLogView: View {
    let targetEntryID: UUID? // Optional ID to auto-open
    
    @State private var entries: [VideoEntry] = []
    @State private var offset: Int = 0
    private let limit: Int = 20
    
    @State private var selectedLog: String? = nil
    @State private var selectedTitle: String = ""
    @State private var showingLogViewer = false
    
    init(targetEntryID: UUID? = nil) {
        self.targetEntryID = targetEntryID
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
                .background(Color.white.opacity(0.05))
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            VStack(spacing: 0) {
                                Button(action: {
                                    openLog(for: entry)
                                }) {
                                    HStack(alignment: .top) {
                                        Text(formatDate(entry.date))
                                            .font(.nothingMeta)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.id.uuidString.prefix(8).uppercased())
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(DesignSystem.Colors.nothingRed)
                                            
                                            Text(entry.title)
                                                .font(.nothingBody)
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                            
                                            Text(entry.url)
                                                .font(.system(size: 8, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
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
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                        
                        if entries.count >= limit && entries.count % limit == 0 {
                            Button(action: loadMore) {
                                Text("LOAD MORE RECORDS")
                                    .font(.nothingMeta)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(DesignSystem.Colors.nothingRed.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding()
                        }
                        
                        // Bottom spacer for floating tab bar
                        Color.clear.frame(height: 100)
                    }
                }
            }
        }
        .navigationTitle("SEQUENCE LOGS")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogViewer) {
            logViewerSheet
        }
        .onAppear {
            if entries.isEmpty {
                loadEntries()
            }
            
            // Auto open if ID provided
            if let targetID = targetEntryID {
                if let entry = DatabaseManager.shared.fetchEntries(limit: 100, offset: 0).first(where: { $0.id == targetID }) {
                    openLog(for: entry)
                }
            }
        }
    }
    
    private func openLog(for entry: VideoEntry) {
        selectedTitle = entry.title
        selectedLog = DatabaseManager.shared.fetchRawLog(for: entry.id)
        showingLogViewer = true
    }
    
    private var logViewerSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedTitle)
                        .font(.nothingHeader)
                        .padding(.top)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    Text(selectedLog ?? "Log details are unavailable for this entry.")
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled) // Allow user to copy logs
                        .padding(.bottom, 40)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("RAW OUTPUT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DISMISS") { showingLogViewer = false }
                        .font(.nothingMeta)
                        .foregroundColor(DesignSystem.Colors.nothingRed)
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
