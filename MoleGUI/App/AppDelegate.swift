import AppKit
import SwiftUI

/// Manages NSStatusItem lifecycle and observes the Settings toggle
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var menuBarController: MenuBarController?
    private var observation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarObserver()
        updateMenuBarIcon()
    }

    private func setupMenuBarObserver() {
        // Observe UserDefaults for showMenuBarIcon changes using KVO
        observation = UserDefaults.standard.observe(
            \.showMenuBarIcon,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateMenuBarIcon()
            }
        }
    }

    private func updateMenuBarIcon() {
        let showMenuBarIcon = UserDefaults.standard.bool(forKey: "showMenuBarIcon")

        if showMenuBarIcon {
            if menuBarController == nil {
                menuBarController = MenuBarController(appDelegate: self)
            }
        } else {
            menuBarController?.remove()
            menuBarController = nil
        }
    }

    func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Find and activate the main window
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            // If no window exists, create one by opening the app
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func openSettings() {
        NotificationCenter.default.post(
            name: .menuBarNavigateToTab,
            object: nil,
            userInfo: ["tab": NavigationTab.settings]
        )
        showMainWindow()
    }
}

// MARK: - UserDefaults Extension for KVO

extension UserDefaults {
    @objc dynamic var showMenuBarIcon: Bool {
        bool(forKey: "showMenuBarIcon")
    }
}
