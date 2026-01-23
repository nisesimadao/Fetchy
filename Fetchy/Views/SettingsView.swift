import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: DotMatrixText(text: "HAPTICS")) {
                    Toggle("Vibration Feedback", isOn: $settings.vibrationEnabled)
                        .listRowBackground(Color.white.opacity(0.05))
                    
                    if settings.vibrationEnabled {
                        Picker("Intensity", selection: $settings.vibrationStrength) {
                            Text("Light").tag("light")
                            Text("Medium").tag("medium")
                            Text("Heavy").tag("heavy")
                        }
                        .listRowBackground(Color.white.opacity(0.05))
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
                .listRowBackground(Color.white.opacity(0.05))
                
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
                .listRowBackground(Color.white.opacity(0.05))
                
                Section(header: DotMatrixText(text: "DIAGNOSTICS")) {
                    NavigationLink(destination: DetailedLogView(targetEntryID: nil)) {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundStyle(DesignSystem.Colors.nothingRed)
                            Text("Detailed Logs (Raw DB)")
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section {
                    Text("Version 1.4.0 (Build 5)")
                        .font(.nothingMeta)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                
                // Extra space for floating bar
                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}
