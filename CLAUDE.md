# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build from command line
xcodebuild -project MoleGUI.xcodeproj -scheme MoleGUI build

# Open in Xcode
open MoleGUI.xcodeproj
```

No test suite currently exists. No external package dependencies (uses only Apple frameworks).

## Architecture

MoleGUI is a native macOS system optimization app built with Swift/SwiftUI targeting macOS 13.0+.

### MVVM Pattern
- **Views** (`Views/`): SwiftUI components organized by feature (Dashboard, Cleaner, Uninstaller, Analyzer, Monitor, Purge, Settings)
- **ViewModels** (`ViewModels/`): `@MainActor ObservableObject` classes managing state and orchestration
- **Services** (`Services/`): Swift actors for thread-safe async operations (FileScanner, CacheManager, DiskAnalyzer, SystemMonitor, AppBundleAnalyzer, TrashManager)
- **Models** (`Models/`): Data structures (SystemStats, CacheItem, InstalledApp, DiskItem, ProjectArtifact)

### State Management
- `AppState`: Central `@MainActor` class with selected tab, scan status, and `@AppStorage`-backed settings
- `ViewModelContainer`: Singleton providing shared ViewModels to both main window and menu bar
- Navigation via `NavigationTab` enum in AppState

### Concurrency
All services use Swift actors. ViewModels and AppDelegate are `@MainActor`. File operations use async/await throughout.

### Menu Bar Integration
StatusItem via NSStatusBar with quick actions. Communication between menu bar and main window uses notifications and shared ViewModelContainer.

## Key Configuration Files

- `Config/CachePaths.swift`: Defines all cache locations to scan (user, system, browser, app-specific, Xcode, Docker)
- `Config/AppRemnantPaths.swift`: Patterns for app preference/support location detection
- `Config/Whitelist.swift`: Protected paths that should never be deleted

## File Operations

- Safe deletion uses `FileManager.trashItem()` (recoverable via Trash)
- Permanent deletion checks against Whitelist before removing
- Dry-run mode available via `AppState.enableDryRun`

## Adding New Features

- New cache category: Add to `CachePaths` enum methods
- New cleanup feature: Create ViewModel + View + Service (actor)
- New system metric: Extend `SystemMonitor` with Mach/Darwin kernel calls
