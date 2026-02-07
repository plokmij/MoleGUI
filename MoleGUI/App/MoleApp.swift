import SwiftUI

@main
struct MoleApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    // TODO: Implement update check
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $appState.selectedTab)
        } detail: {
            switch appState.selectedTab {
            case .dashboard:
                DashboardView()
            case .cleaner:
                CleanerView()
            case .uninstaller:
                UninstallerView()
            case .analyzer:
                AnalyzerView()
            case .monitor:
                MonitorView()
            case .purge:
                PurgeView()
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
