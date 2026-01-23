import SwiftUI

struct HistoryView: View {
    @State private var entries: [VideoEntry] = []
    @State private var offset: Int = 0
    private let limit: Int = 20
    
    @State private var showingDeletePicker = false
    @State private var deleteBeforeDate = Date()
    @State private var titleTapCount = 0
    @State private var lastTapTime = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea() // Deep black background for Nothing OS feel
                
                ScrollView {
                    VStack(spacing: 12) {
                        if entries.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                DotMatrixText(text: "NO DOWNLOADS")
                            }
                            .padding(.top, 100)
                        } else {
                            // Header Meta
                            HStack {
                                DotMatrixText(text: "\(entries.count) ITEMS STORED")
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            LazyVStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    HistoryRow(entry: entry, onDelete: {
                                        deleteEntry(entry)
                                    })
                                }
                                
                                // Pagination
                                if entries.count >= limit && entries.count % limit == 0 {
                                    Button(action: loadMore) {
                                        Text("LOAD MORE")
                                            .font(.nothingMeta)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(DesignSystem.Colors.nothingRed.opacity(0.1))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100) // Space for floating bar
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingDeletePicker = true }) {
                        Image(systemName: "trash")
                            .foregroundStyle(DesignSystem.Colors.nothingRed)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.headline)
                        .onTapGesture {
                            handleTitleTap()
                        }
                }
            }
            .overlay {
                if showingDeletePicker {
                    bulkDeleteOverlay
                }
            }
            .onAppear {
                if entries.isEmpty {
                    loadEntries()
                }
            }
        }
    }
    
    private var bulkDeleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showingDeletePicker = false }
            
            VStack(spacing: 20) {
                DotMatrixText(text: "DELETE BEFORE")
                
                DatePicker("Select Date", selection: $deleteBeforeDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                
                HStack(spacing: 20) {
                    Button("CANCEL") { showingDeletePicker = false }
                        .font(.nothingBody)
                    
                    Button("DELETE") {
                        bulkDelete()
                        showingDeletePicker = false
                    }
                    .font(.nothingBody)
                    .foregroundStyle(DesignSystem.Colors.nothingRed)
                }
            }
            .padding()
            .background(Material.thin)
            .cornerRadius(20)
            .padding(40)
        }
    }
    
    private func handleTitleTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.5 {
            titleTapCount += 1
        } else {
            titleTapCount = 1
        }
        lastTapTime = now
        
        if titleTapCount >= 3 {
            insertMockData()
            titleTapCount = 0
        }
    }
    
    private func insertMockData() {
        let services = ["YouTube", "TikTok", "X", "Instagram", "Vimeo"]
        let statuses: [VideoEntry.DownloadStatus] = [.completed, .failed, .downloading, .pending]
        
        for i in 1...25 {
            let entry = VideoEntry(
                title: "Mock Video \(i)",
                url: "https://example.com/video/\(i)",
                service: services.randomElement()!,
                status: statuses.randomElement()!,
                localPath: "/tmp/mock\(i).mp4"
            )
            DatabaseManager.shared.insert(entry: entry, rawLog: "Mock log data for video \(i)")
        }
        
        // Reload
        loadEntries()
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
    
    private func deleteEntry(_ entry: VideoEntry) {
        DatabaseManager.shared.deleteEntry(id: entry.id)
        entries.removeAll { $0.id == entry.id }
    }
    
    private func bulkDelete() {
        DatabaseManager.shared.deleteEntries(before: deleteBeforeDate)
        loadEntries()
    }
}

struct HistoryRow: View {
    let entry: VideoEntry
    let onDelete: () -> Void
    @State private var isExpanded = false
    @State private var rawLog: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ServiceIcon(entry.service, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.nothingBody)
                        .lineLimit(1)
                    
                    Text(entry.url)
                        .font(.nothingMeta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                StatusIndicator(status: entry.status)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    if isExpanded && rawLog == nil {
                        rawLog = DatabaseManager.shared.fetchRawLog(for: entry.id)
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().opacity(0.1)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        DotMatrixText(text: "ACTIVITY LOG")
                        
                        Text(rawLog ?? "No log items recorded.")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    NavigationLink(destination: DetailedLogView(targetEntryID: entry.id)) {
                        HStack {
                            Text("OPEN FULL SEQUENCE LOG")
                            Image(systemName: "chevron.right")
                        }
                        .font(.nothingMeta)
                        .foregroundStyle(DesignSystem.Colors.nothingRed)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .liquidGlass(cornerRadius: 16) // Card look per row
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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

#Preview {
    HistoryView()
}
