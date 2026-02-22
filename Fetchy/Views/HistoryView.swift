import SwiftUI

struct HistoryView: View {
    @State private var entries: [VideoEntry] = []
    @State private var offset: Int = 0
    private let limit: Int = 20
    
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var showingDeletePicker = false
    @State private var deleteBeforeDate = Date()
    @State private var titleTapCount = 0
    @State private var lastTapTime = Date()
    @State private var previewURL: URL?
    @State private var showingLogEntry: VideoEntry?
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            List {
                if entries.isEmpty && downloadManager.tasks.isEmpty {
                    Section {
                        VStack(spacing: 20) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 44))
                                .if(availableiOS: 15.0) {
                                    if #available(iOS 15.0, *) {
                                        $0.foregroundStyle(.quaternary)
                                    } else {
                                        $0
                                    }
                                } otherwise: {
                                    $0.foregroundColor(Color.secondary.opacity(0.3))
                                }
                            DotMatrixText(text: "NO RECORDS FOUND", usesUppercase: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 100)
                    }
                    .listRowBackground(Color.clear)
                } else if !entries.isEmpty {
                    Section(header: DotMatrixText(text: "RECENT SEQUENCES")) {
                        ForEach(entries) { entry in
                            HistoryRow(entry: entry, onDelete: { deleteEntry(entry) }, onShowLog: { showingLogEntry = entry })
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                deleteEntry(entries[index])
                            }
                        }
                        
                        if entries.count >= limit && entries.count % limit == 0 {
                            Button(action: loadMore) {
                                Text("LOAD MORE")
                                    .font(.nothingMeta)
                                    .foregroundColor(DesignSystem.Colors.nothingRed)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingDeletePicker = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(DesignSystem.Colors.nothingRed)
                }
            }
        }
        .sheet(item: $showingLogEntry) { entry in
            NavigationView {
                DetailedLogView(targetEntryID: entry.id)
                    .navigationTitle("System Log")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") { showingLogEntry = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingDeletePicker) {
            Group {
                NavigationView {
                    VStack(spacing: 20) {
                        DotMatrixText(text: "DELETE RECORDS BEFORE DATE")
                            .padding(.top)
                        
                        DatePicker("Before Date", selection: $deleteBeforeDate, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .padding()
                        
                        Spacer()
                        
                        Button(action: {
                            bulkDelete()
                            showingDeletePicker = false
                        }) {
                            Text("DELETE RECORDS")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IndustrialButtonStyle()) // Assuming this style exists, or use plain button
                        .padding()
                    }
                    .navigationTitle("Clear History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showingDeletePicker = false }
                        }
                    }
                }
            }
            .modifier(PresentationDetentsIfAvailable())
        }
        .onAppear {
            loadEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenQuickLook"))) { notification in
            if let url = notification.object as? URL {
                self.previewURL = url
            }
        }
        .sheet(item: Binding(
            get: { previewURL.map { IdentifiableURL(url: $0) } },
            set: { previewURL = $0?.url }
        )) { idURL in
            QuickLookView(url: idURL.url)
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
    let onShowLog: () -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row Content
            HStack(alignment: .top, spacing: 16) {
                ServiceIcon(entry.service, size: 36)
                    .animation(nil, value: isExpanded)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(isExpanded ? .system(size: 18, weight: .semibold) : .nothingBody)
                        .lineLimit(isExpanded ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(entry.url)
                        .font(.nothingMeta)
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.foregroundStyle(.secondary)
                            } else {
                                $0
                            }
                        } otherwise: {
                            $0.foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                        .animation(nil, value: isExpanded)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusIndicator(status: entry.status, task: nil, entry: entry)
                        .animation(nil, value: isExpanded)
                    
                    Text(formatDate(entry.date))
                        .font(.nothingMeta)
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.foregroundStyle(.secondary)
                            } else {
                                $0
                            }
                        } otherwise: {
                            $0.foregroundColor(.secondary)
                        }
                        .animation(nil, value: isExpanded)
                    
                    // Expansion Indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.foregroundStyle(.tertiary)
                            } else {
                                $0
                            }
                        } otherwise: {
                            $0.foregroundColor(Color.secondary.opacity(0.5))
                        }
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(nil, value: isExpanded)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if isExpanded {
                    // Collapsing - Snappy
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                } else {
                    // Expanding - Bouncy/Rich
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        Text(entry.rawLog ?? "No log data available")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        Button(action: onShowLog) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("SHOW LOG")
                            }
                            .font(.nothingMeta)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: onDelete) {
                            HStack {
                                Image(systemName: "trash")
                                Text("DELETE")
                            }
                            .font(.nothingMeta)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(DesignSystem.Colors.nothingRed.opacity(0.1))
                            .foregroundColor(DesignSystem.Colors.nothingRed)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity)
                .clipped()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct ActiveTaskIndicator: View {
    @ObservedObject var task: DownloadTask
    
    var body: some View {
        ProgressView(value: task.progress)
            .scaleEffect(0.8)
    }
}

struct StatusIndicator: View {
    let status: VideoEntry.DownloadStatus
    let task: DownloadTask?
    let entry: VideoEntry
    
    var body: some View {
        if let task = task {
            ActiveTaskIndicator(task: task)
        } else {
            // History items are logs only; no local file access
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.foregroundStyle(DesignSystem.Colors.nothingRed)
                        } else {
                            $0
                        }
                    } otherwise: {
                        $0.foregroundColor(DesignSystem.Colors.nothingRed)
                    }
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.foregroundStyle(.secondary)
                        } else {
                            $0
                        }
                    } otherwise: {
                        $0.foregroundColor(.secondary)
                    }
            case .downloading:
                ProgressView()
                    .scaleEffect(0.8)
            case .pending:
                Image(systemName: "clock")
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.foregroundStyle(.secondary)
                        } else {
                            $0
                        }
                    } otherwise: {
                        $0.foregroundColor(.secondary)
                    }
            case .cancelled:
                Image(systemName: "stop.circle")
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.foregroundStyle(.secondary)
                        } else {
                            $0
                        }
                    } otherwise: {
                        $0.foregroundColor(.secondary)
                    }
            case .aborted:
                Image(systemName: "xmark.circle")
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.foregroundStyle(.secondary)
                        } else {
                            $0
                        }
                    } otherwise: {
                        $0.foregroundColor(.secondary)
                    }
            }
        }
    }
}

fileprivate struct PresentationDetentsIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}

#Preview {
    HistoryView()
}
