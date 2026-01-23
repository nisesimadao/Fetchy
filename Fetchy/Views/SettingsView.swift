import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: DotMatrixText(text: "HAPTICS")) {
                    Toggle("Vibration Feedback", isOn: $settings.vibrationEnabled)
                    
                    if settings.vibrationEnabled {
                        Picker("Intensity", selection: $settings.vibrationStrength) {
                            Text("Light").tag("light")
                            Text("Medium").tag("medium")
                            Text("Heavy").tag("heavy")
                        }
                    }
                }
                
                Section(header: DotMatrixText(text: "VISUALS")) {
                    Toggle("Show Progress Initially", isOn: $settings.progressVisible)
                    Toggle("Toast Notifications", isOn: $settings.toastEnabled)
                    
                    if settings.toastEnabled {
                        HStack {
                            Text("Notify At (min)")
                            Spacer()
                            TextField("5, 8", text: $settings.toastIntervals)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                }
                
                Section(header: DotMatrixText(text: "QUALITY")) {
                    Picker("Default Resolution", selection: $settings.defaultResolution) {
                        Text("1080p").tag("1080p")
                        Text("720p").tag("720p")
                        Text("480p").tag("480p")
                        Text("Highest").tag("best")
                    }
                    
                    Picker("Audio Quality", selection: $settings.defaultQuality) {
                        Text("44.1kHz").tag("44.1k")
                        Text("48kHz").tag("48k")
                        Text("96kHz").tag("96k")
                        Text("Lossless").tag("lossless")
                    }
                }
                
                Section(header: DotMatrixText(text: "DIAGNOSTICS")) {
                    NavigationLink(destination: DetailedLogView()) {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundStyle(DesignSystem.Colors.nothingRed)
                            Text("Detailed Logs (Raw DB)")
                        }
                    }
                }
                
                Section {
                    Text("Version 1.0.0 (Build 1)")
                        .font(.nothingMeta)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
