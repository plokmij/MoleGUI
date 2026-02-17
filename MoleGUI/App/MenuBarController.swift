import AppKit
import SwiftUI

/// Handles the menu bar UI and actions
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "ant.fill", accessibilityDescription: "Mole")
            image?.isTemplate = true
            button.image = image
        }

        statusItem?.menu = createMenu()
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Header
        let headerItem = NSMenuItem(title: "Quick Actions", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Quick actions
        menu.addItem(createMenuItem(
            title: "Start Deep Clean Scan",
            action: #selector(startDeepCleanScan),
            icon: "bubbles.and.sparkles"
        ))

        menu.addItem(createMenuItem(
            title: "Quick Clean",
            action: #selector(quickClean),
            icon: "sparkles"
        ))

        menu.addItem(createMenuItem(
            title: "Scan Applications",
            action: #selector(scanApplications),
            icon: "trash"
        ))

        menu.addItem(createMenuItem(
            title: "Analyze Storage",
            action: #selector(analyzeStorage),
            icon: "chart.pie"
        ))

        menu.addItem(createMenuItem(
            title: "Scan Dev Artifacts",
            action: #selector(scanDevArtifacts),
            icon: "folder.badge.minus"
        ))

        menu.addItem(createMenuItem(
            title: "Optimize System",
            action: #selector(optimizeSystem),
            icon: "bolt.fill"
        ))

        menu.addItem(createMenuItem(
            title: "Find Installer Files",
            action: #selector(findInstallers),
            icon: "shippingbox"
        ))

        menu.addItem(NSMenuItem.separator())

        // Show main window
        menu.addItem(createMenuItem(
            title: "Show Main Window",
            action: #selector(showMainWindow),
            icon: "macwindow"
        ))

        menu.addItem(NSMenuItem.separator())

        // Settings
        menu.addItem(createMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            icon: "gearshape",
            keyEquivalent: ","
        ))

        // Quit
        let quitItem = createMenuItem(
            title: "Quit Mole",
            action: #selector(quitApp),
            icon: "power",
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    private func createMenuItem(
        title: String,
        action: Selector,
        icon: String,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self

        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
            image.isTemplate = true
            item.image = image
        }

        return item
    }

    func remove() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    // MARK: - Actions

    @objc private func startDeepCleanScan() {
        navigateToTabAndShowWindow(.cleaner)
        Task { @MainActor in
            ViewModelContainer.shared.cleanerViewModel.startScan()
        }
    }

    @objc private func quickClean() {
        navigateToTabAndShowWindow(.cleaner)
        Task { @MainActor in
            let vm = ViewModelContainer.shared.cleanerViewModel
            if vm.results.isEmpty {
                vm.startScan()
            }
        }
    }

    @objc private func scanApplications() {
        navigateToTabAndShowWindow(.uninstaller)
        Task { @MainActor in
            let vm = ViewModelContainer.shared.uninstallerViewModel
            if vm.apps.isEmpty {
                vm.startScan()
            }
        }
    }

    @objc private func analyzeStorage() {
        navigateToTabAndShowWindow(.analyzer)
        Task { @MainActor in
            ViewModelContainer.shared.analyzerViewModel.analyzeHome()
        }
    }

    @objc private func scanDevArtifacts() {
        navigateToTabAndShowWindow(.purge)
        Task { @MainActor in
            ViewModelContainer.shared.purgeViewModel.startScan()
        }
    }

    @objc private func optimizeSystem() {
        navigateToTabAndShowWindow(.optimizer)
        Task { @MainActor in
            ViewModelContainer.shared.optimizerViewModel.checkStatus()
        }
    }

    @objc private func findInstallers() {
        navigateToTabAndShowWindow(.installer)
        Task { @MainActor in
            let vm = ViewModelContainer.shared.installerViewModel
            if vm.items.isEmpty {
                vm.startScan()
            }
        }
    }

    @objc private func showMainWindow() {
        appDelegate?.showMainWindow()
    }

    @objc private func openSettings() {
        navigateToTabAndShowWindow(.settings)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func navigateToTabAndShowWindow(_ tab: NavigationTab) {
        NotificationCenter.default.post(
            name: .menuBarNavigateToTab,
            object: nil,
            userInfo: ["tab": tab]
        )
        appDelegate?.showMainWindow()
    }
}

extension Notification.Name {
    static let menuBarNavigateToTab = Notification.Name("menuBarNavigateToTab")
}
