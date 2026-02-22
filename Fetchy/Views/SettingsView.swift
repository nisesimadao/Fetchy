import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var proTapCount = 0
    @State private var playingSplash = false
    
    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "App"
    }
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
    
    var body: some View {
        ZStack {
            List {
                Section(header: DotMatrixText(text: "HAPTICS", usesUppercase: true)) {
                    Toggle("Vibration Feedback", isOn: $settings.vibrationEnabled)
                    
                    if settings.vibrationEnabled {
                        Picker("Intensity", selection: $settings.vibrationStrength) {
                            Text("Light").tag("light")
                            Text("Medium").tag("medium")
                            Text("Heavy").tag("heavy")
                        }
                        
                        Stepper(value: $settings.hapticFrequency, in: 1...10, step: 1) {
                            HStack {
                                Text("Frequency Steps")
                                Spacer()
                                Text("\(settings.hapticFrequency)%")
                                    .if(availableiOS: 15.0) {
                                        if #available(iOS 15.0, *) {
                                            $0.foregroundStyle(DesignSystem.Colors.nothingRed)
                                        } else {
                                            $0
                                        }
                                    } otherwise: {
                                        $0.foregroundColor(DesignSystem.Colors.nothingRed)
                                    }
                                    .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .bold))
                            }
                        }
                    }
                }
                
                Section(header: DotMatrixText(text: "VISUALS", usesUppercase: true)) {
                    Toggle("Default Progress Visible", isOn: $settings.progressVisible)
                    Toggle("Safety Warnings (Toasts)", isOn: $settings.toastEnabled)
                    
                    if settings.toastEnabled {
                        Stepper(value: $settings.toastDelaySeconds, in: 1...30, step: 1) {
                            HStack {
                                Text("Warning Delay")
                                Spacer()
                                Text("\(settings.toastDelaySeconds)s")
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
                
                Section(header: DotMatrixText(text: "DEFAULTS", usesUppercase: true)) {
                    NavigationLink(destination: DefaultsManagementView()) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .if(availableiOS: 15.0) {
                                    if #available(iOS 15.0, *) {
                                        $0.foregroundStyle(.blue)
                                    } else {
                                        $0
                                    }
                                } otherwise: {
                                    $0.foregroundColor(.blue)
                                }
                            Text("Default Management")
                        }
                    }
                }
                
                Section(header: DotMatrixText(text: "DIAGNOSTICS", usesUppercase: true)) {
                    NavigationLink(destination: DetailedLogView(targetEntryID: nil)) {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .if(availableiOS: 15.0) {
                                    if #available(iOS 15.0, *) {
                                        $0.foregroundStyle(DesignSystem.Colors.nothingRed)
                                    } else {
                                        $0
                                    }
                                } otherwise: {
                                    $0.foregroundColor(DesignSystem.Colors.nothingRed)
                                }
                            Text("Detailed Sequence Logs")
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/nisesimadao/Fetchy")!) {
                        HStack {
                            Image(systemName: "safari.fill")
                                .if(availableiOS: 15.0) {
                                    if #available(iOS 15.0, *) {
                                        $0.foregroundStyle(.blue)
                                    } else {
                                        $0
                                    }
                                } otherwise: {
                                    $0.foregroundColor(.blue)
                                }
                            Text("Project Documentation")
                        }
                    }
                }
                
                Section(header: DotMatrixText(text: "BACKEND", usesUppercase: true)) {
                    TextField("Backend URL", text: $settings.backendURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(appDisplayName)
                                .font(.nothingMeta)
                                .if(availableiOS: 15.0) {
                                    if #available(iOS 15.0, *) {
                                        $0.foregroundStyle(.primary)
                                    } else {
                                        $0
                                    }
                                } otherwise: {
                                    $0.foregroundColor(.primary)
                                }
                                .onTapGesture {
                                    proTapCount += 1
                                    if proTapCount >= 3 {
                                        proTapCount = 0
                                        playingSplash = true
                                    }
                                }
                            Text("Version \(appVersion) (Build \(appBuild))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
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
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                // Extra space for floating bar
                Color.clear
                    .frame(height: 100)
                    .listRowBackground(Color.clear)
                    .if(availableiOS: 15.0) {
                        if #available(iOS 15.0, *) {
                            $0.listRowSeparator(.hidden)
                        } else {
                            $0
                        }
                    }
            }
            .navigationTitle("Settings")
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .toolbar { // Added back toolbar to ensure trailing item is still there
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { playingSplash = false }
                        .opacity(playingSplash ? 1 : 0) // Only visible when playingSplash is true
                }
            }
            
            if playingSplash {
                ZStack {
                    Rectangle()
                        .if(availableiOS: 15.0) {
                            if #available(iOS 15.0, *) {
                                $0.fill(.ultraThinMaterial)
                            } else {
                                $0.fill(Color.black.opacity(0.4))
                            }
                        } otherwise: {
                            $0.fill(Color.black.opacity(0.4))
                        }
                        .ignoresSafeArea()
                    
                    SplashVideoView(videoName: "Splash.mov", isActive: $playingSplash)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .if(availableiOS: 15.0) {
            if #available(iOS 15.0, *) {
                $0.animation(.easeInOut(duration: 0.8), value: playingSplash)
            } else {
                $0
            }
        } otherwise: {
            $0.animation(.easeInOut(duration: 0.8))
        }
    }
}

