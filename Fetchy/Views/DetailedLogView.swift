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
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Table Header
                HStack {
                    Text("DATE")
                        .frame(width: 80, alignment: .leading)
                    Text("INFO / TITLE")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("STATUS")
                        .frame(width: 80, alignment: .trailing)
                }
                .if(availableiOS: 15.0) {
                    if #available(iOS 15.0, *) {
                        $0.foregroundStyle(.secondary)
                    } else {
                        $0
                    }
                } otherwise: {
                    $0.foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                
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
                                            .if(availableiOS: 15.0) {
                                                if #available(iOS 15.0, *) {
                                                    $0.foregroundStyle(.secondary)
                                                } else {
                                                    $0
                                                }
                                            } otherwise: {
                                                $0.foregroundColor(.secondary)
                                            }
                                            .frame(width: 80, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.id.uuidString.prefix(8).uppercased())
                                                .font(.system(size: 9, design: .monospaced))
                                                .if(availableiOS: 15.0) {
                                                    if #available(iOS 15.0, *) {
                                                        $0.foregroundStyle(DesignSystem.Colors.nothingRed)
                                                    } else {
                                                        $0
                                                    }
                                                } otherwise: {
                                                    $0.foregroundColor(DesignSystem.Colors.nothingRed)
                                                }
                                            
                                            Text(entry.title)
                                                .font(.nothingBody)
                                                .lineLimit(1)
                                                .if(availableiOS: 15.0) {
                                                    if #available(iOS 15.0, *) {
                                                        $0.foregroundStyle(.primary)
                                                    } else {
                                                        $0
                                                    }
                                                } otherwise: {
                                                    $0.foregroundColor(.primary)
                                                }
                                            
                                            Text(entry.url)
                                                .font(.system(size: 8, design: .monospaced))
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
                                        }
                                        
                                        Spacer()
                                        
                                        Text(entry.status.rawValue.uppercased())
                                            .font(.nothingMeta)
                                            .if(availableiOS: 15.0) {
                                                if #available(iOS 15.0, *) {
                                                    $0.foregroundStyle(statusColor(entry.status))
                                                } else {
                                                    $0
                                                }
                                            } otherwise: {
                                                $0.foregroundColor(statusColor(entry.status))
                                            }
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                            }
                        }
                        
                        if entries.count >= limit && entries.count % limit == 0 {
                            Button(action: loadMore) {
                                Text("LOAD MORE RECORDS")
                                    .font(.nothingMeta)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(DesignSystem.Colors.nothingRed.opacity(0.05))
                                    .cornerRadius(12)
                            }
                            .padding()
                        }
                        
                        // Bottom spacer
                        Color.clear.frame(height: 100)
                    }
                }
            }
        }
        .navigationTitle("Sequence Logs")
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
            VStack(alignment: .leading, spacing: 0) {
                // Header (non-scrolling)
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedTitle)
                        .font(.nothingHeader)
                    
                    Divider()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Selectable, Wrapping, Scrolling Log Area
                SelectableLogView(text: selectedLog ?? "Log details are unavailable for this entry.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 20)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Raw Output")
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
    
    // Selectable TextView using UIKit for partial selection and wrapping support
    struct SelectableLogView: UIViewRepresentable {
        let text: String
        @Environment(\.colorScheme) var colorScheme
        
        func makeUIView(context: Context) -> UITextView {
            let textView = UITextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = true 
            textView.backgroundColor = .clear
            textView.textColor = colorScheme == .dark ? .white : .black
            textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            textView.textContainerInset = UIEdgeInsets(top: 10, left: 16, bottom: 20, right: 16)
            textView.textContainer.lineFragmentPadding = 0
            textView.textContainer.lineBreakMode = .byWordWrapping
            textView.textContainer.widthTracksTextView = true
            
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            return textView
        }
        
        func updateUIView(_ uiView: UITextView, context: Context) {
            uiView.text = text
            uiView.textColor = colorScheme == .dark ? .white : .black
            uiView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
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
