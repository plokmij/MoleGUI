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

            WhitelistSettingsView()
                .tabItem {
                    Label("Whitelist", systemImage: "shield")
                }

            OperationLogView()
                .tabItem {
                    Label("Log", systemImage: "doc.text")
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
        .frame(minWidth: 550, minHeight: 400)
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

struct WhitelistSettingsView: View {
    @State private var userPaths: [String] = []
    @State private var newPath = ""
    @State private var showFilePicker = false

    var body: some View {
        Form {
            Section("Custom Whitelist") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paths added here will never be cleaned or deleted by Mole.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Add path...", text: $newPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            guard !newPath.isEmpty else { return }
                            Whitelist.addToUserWhitelist(newPath)
                            refreshPaths()
                            newPath = ""
                        }

                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                Whitelist.addToUserWhitelist(url.path)
                                refreshPaths()
                            }
                        }
                    }
                }
            }

            Section("User-Defined Protected Paths") {
                if userPaths.isEmpty {
                    Text("No custom whitelist entries")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(userPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder.badge.minus")
                                .foregroundStyle(.orange)
                            Text(path)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(role: .destructive) {
                                Whitelist.removeFromUserWhitelist(path)
                                refreshPaths()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Built-in Protected Paths") {
                Text("The following paths are always protected and cannot be removed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(Whitelist.protectedPaths.subtracting(Whitelist.userWhitelistPaths)).sorted(), id: \.self) { path in
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(path)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { refreshPaths() }
    }

    private func refreshPaths() {
        userPaths = Array(Whitelist.userWhitelistPaths).sorted()
    }
}

struct OperationLogView: View {
    @State private var logEntries: [String] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Operation Log")
                    .font(.headline)

                Spacer()

                Button("Refresh") { loadLog() }

                Button("Clear Log") { clearLog() }
                    .foregroundStyle(.red)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if logEntries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No operations logged yet")
                        .foregroundStyle(.secondary)
                    Text("File operations will appear here after cleaning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logEntries.reversed().enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(entry.contains("FAIL") ? .red : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear { loadLog() }
    }

    private func loadLog() {
        isLoading = true
        Task {
            let entries = await OperationLogger.shared.recentEntries(count: 500)
            await MainActor.run {
                self.logEntries = entries
                self.isLoading = false
            }
        }
    }

    private func clearLog() {
        Task {
            await OperationLogger.shared.clearLog()
            await MainActor.run {
                logEntries = []
            }
        }
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
