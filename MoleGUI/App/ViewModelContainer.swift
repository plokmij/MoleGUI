import Foundation

/// Singleton container to share ViewModels between main window and menu bar
@MainActor
final class ViewModelContainer: ObservableObject {
    static let shared = ViewModelContainer()

    let cleanerViewModel = CleanerViewModel()
    let uninstallerViewModel = UninstallerViewModel()
    let analyzerViewModel = AnalyzerViewModel()
    let purgeViewModel = PurgeViewModel()
    let monitorViewModel = MonitorViewModel()

    private init() {}
}
