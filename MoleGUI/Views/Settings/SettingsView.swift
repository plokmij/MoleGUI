import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            CleaningSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Cleaning", systemImage: "bubbles.and.sparkles")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 450, minHeight: 300)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("checkForUpdates") private var checkForUpdates = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)

                Toggle("Check for updates automatically", isOn: $checkForUpdates)

                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            }

            Section {
                Toggle("Enable dry-run mode (preview before delete)", isOn: $appState.enableDryRun)

                Toggle("Show hidden files in scans", isOn: $appState.showHiddenFiles)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct CleaningSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("cleanBrowserCache") private var cleanBrowserCache = true
    @AppStorage("cleanSystemCache") private var cleanSystemCache = true
    @AppStorage("cleanAppCache") private var cleanAppCache = true
    @AppStorage("cleanLogs") private var cleanLogs = true
    @AppStorage("cleanXcodeData") private var cleanXcodeData = false
    @AppStorage("cleanDockerData") private var cleanDockerData = false

    var body: some View {
        Form {
            Section("Default Categories") {
                Toggle("Browser caches (Safari, Chrome, Firefox)", isOn: $cleanBrowserCache)
                Toggle("System caches", isOn: $cleanSystemCache)
                Toggle("Application caches", isOn: $cleanAppCache)
                Toggle("Log files", isOn: $cleanLogs)
            }

            Section("Developer Data") {
                Toggle("Xcode derived data & caches", isOn: $cleanXcodeData)
                Toggle("Docker data", isOn: $cleanDockerData)
            }

            Section {
                HStack {
                    Text("Protected paths are never deleted")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("View Whitelist") {
                        // Show whitelist
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Full Disk Access Required", systemImage: "lock.shield")
                        .font(.headline)

                    Text("Mole needs Full Disk Access to scan and clean protected folders like ~/Library.")
                        .foregroundStyle(.secondary)

                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Data Collection") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("No data collected")
                            .fontWeight(.medium)
                        Text("Mole runs entirely on your Mac. No data is sent anywhere.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "ant.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Mole")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("A native macOS system optimization tool")
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 20) {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/mole-app/mole") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("License") {
                    // Show license
                }

                Button("Acknowledgments") {
                    // Show acknowledgments
                }
            }
            .buttonStyle(.link)

            Text("Made with SwiftUI")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
