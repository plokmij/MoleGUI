import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationTab

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach([NavigationTab.dashboard], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }

            Section("Tools") {
                ForEach([NavigationTab.cleaner, .uninstaller, .analyzer, .purge], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }

            Section("System") {
                ForEach([NavigationTab.monitor], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }

            Section {
                ForEach([NavigationTab.settings], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mole")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
        .frame(width: 220)
}
