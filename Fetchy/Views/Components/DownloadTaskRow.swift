import SwiftUI

struct DownloadTaskRow: View {
    @ObservedObject var task: DownloadTask
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.url)
                        .font(.nothingBody)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        DotMatrixText(text: "TYPE: \(task.audioOnly ? "AUDIO" : "VIDEO")")
                        DotMatrixText(text: "FORMAT: \(task.format.uppercased())")
                    }
                }
                
                Spacer()
                
                Text(task.status)
                    .font(.nothingMeta)
                    .if(availableiOS: 15.0, then: { 
                        if #available(iOS 15.0, *) {
                            $0.foregroundStyle(task.status == "COMPLETED" ? DesignSystem.Colors.nothingRed : .secondary)
                        } else {
                            $0
                        }
                    }, otherwise: { $0.foregroundColor(task.status == "COMPLETED" ? DesignSystem.Colors.nothingRed : .secondary) })
            }
            
            VStack(spacing: 6) {
                ProgressView(value: task.progress)
                    .if(availableiOS: 15.0, then: { 
                        if #available(iOS 15.0, *) {
                            $0.tint(DesignSystem.Colors.nothingRed)
                        } else {
                            $0
                        }
                    }, otherwise: { $0.accentColor(DesignSystem.Colors.nothingRed) })
                    .scaleEffect(x: 1, y: 1.2)
                
                HStack {
                    Text("\(Int(task.progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Spacer()
                    if task.status == "COMPLETED" {
                        Button(action: {
                            if let url = task.fileURL {
                                NotificationCenter.default.post(name: NSNotification.Name("OpenQuickLook"), object: url)
                            }
                        }) {
                            Text("PREVIEW")
                                .font(.nothingMeta)
                                .foregroundColor(DesignSystem.Colors.nothingRed)
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .if(availableiOS: 15.0) {
            if #available(iOS 15.0, *) {
                $0.listRowSeparator(.hidden)
            } else {
                $0
            }
        }
    }
}

#Preview {
    DownloadTaskRow(task: DownloadTask(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", quality: "1080p", audioOnly: false, format: "mp4", bitrate: "192"))
}
