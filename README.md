# 🐹 MoleGUI

A native macOS GUI application for deep cleaning and optimizing your Mac. MoleGUI brings the power of the [Mole CLI tool](https://github.com/tw93/Mole) to a beautiful, intuitive SwiftUI interface.

## Features

### 🧹 Cache Cleaner
- Remove browser caches (Safari, Chrome, Firefox, Edge)
- Clean system and application caches
- Clear log files
- Delete Xcode derived data and build artifacts
- Remove Docker containers and images
- Smart categorization and size calculation

### 🗑️ App Uninstaller
- Complete application removal including remnants
- Detect and clean leftover preferences, caches, and support files
- Bulk selection and multi-delete support
- Fast size calculation for installed apps

### 📊 Disk Analyzer
- Visual breakdown of disk usage
- Interactive treemap visualization
- Navigate through directory structures
- Identify large files and folders

### 📈 System Monitor
- Real-time CPU, memory, disk, and network metrics
- System health score calculation
- Temperature and battery monitoring
- Background menu bar integration

### 🔍 Project Analyzer
- Find and clean development artifacts (node_modules, build folders)
- Support for multiple project types
- Reclaim gigabytes from unused dependencies

### 🚮 Trash Manager
- Quick access to Trash contents
- Size calculation and item count
- Empty trash with confirmation

## Requirements

- macOS 13.0 (Ventura) or later
- Full Disk Access permission for complete scanning capabilities

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/mole-app/molegui.git
cd MoleGUI
```

2. Open in Xcode:
```bash
open MoleGUI.xcodeproj
```

3. Build and run (⌘R) or build from command line:
```bash
xcodebuild -project MoleGUI.xcodeproj -scheme MoleGUI build
```

### Granting Permissions

For MoleGUI to access protected system folders like `~/Library`, you need to grant Full Disk Access:

1. Open System Settings → Privacy & Security → Full Disk Access
2. Click the + button and add MoleGUI
3. Restart the application

## Usage

### Main Window
Navigate through different tools using the sidebar:
- **Dashboard**: Overview of system stats and quick actions
- **Cleaner**: Scan and remove cache files
- **Uninstaller**: Manage installed applications
- **Analyzer**: Visualize disk usage
- **Monitor**: Real-time system metrics
- **Purge**: Clean project artifacts
- **Settings**: Configure preferences

### Menu Bar
Enable the menu bar icon in Settings for quick access to:
- System stats at a glance
- Quick clean operations
- Direct navigation to any tool

### Safety Features
- **Dry Run Mode**: Preview deletions before executing
- **Whitelist Protection**: Critical system paths are never deleted
- **Trash Integration**: Deleted items go to Trash (recoverable)
- **Confirmation Dialogs**: Double-check before permanent operations

## Architecture

MoleGUI is built with modern Swift and SwiftUI using the MVVM pattern:

- **Views**: SwiftUI components organized by feature
- **ViewModels**: `@MainActor` classes managing state and orchestration
- **Services**: Swift actors for thread-safe async operations
- **Models**: Data structures for system stats, cache items, and apps

All file operations use async/await and are designed to be safe and performant.

## Development

### Project Structure
```
MoleGUI/
├── Config/           # Cache paths, whitelists, app remnant patterns
├── Models/           # Data structures
├── Services/         # File scanning, cache management, disk analysis
├── ViewModels/       # State management and business logic
├── Views/            # SwiftUI interface components
└── Resources/        # Assets and configuration
```

### Adding Features
- **New cache category**: Add to `Config/CachePaths.swift`
- **New cleanup feature**: Create ViewModel + View + Service (actor)
- **New system metric**: Extend `SystemMonitor` with Mach/Darwin kernel calls

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Related Projects

- [Mole CLI](https://github.com/tw93/Mole) - The original command-line tool
- Install via Homebrew: `brew install mole`

## Privacy

MoleGUI runs entirely on your Mac. No data is collected or sent anywhere. All operations are performed locally with your explicit permission.

## License

MIT License - see [LICENSE](LICENSE) file for details.

Based on the original [Mole](https://github.com/tw93/Mole) project by tw93.

## Acknowledgments

- Built with SwiftUI and Swift Concurrency
- Inspired by the Mole CLI tool
- Uses only native Apple frameworks (no external dependencies)

---

Made with ❤️ using SwiftUI
