import Foundation

enum AppRemnantPaths {
    static let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    static var searchPaths: [RemnantSearchPath] {
        [
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Application Support"),
                type: .applicationSupport
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Caches"),
                type: .caches
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Preferences"),
                type: .preferences
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Logs"),
                type: .logs
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/LaunchAgents"),
                type: .launchAgents
            ),
            RemnantSearchPath(
                basePath: URL(fileURLWithPath: "/Library/LaunchAgents"),
                type: .launchAgents
            ),
            RemnantSearchPath(
                basePath: URL(fileURLWithPath: "/Library/LaunchDaemons"),
                type: .launchDaemons
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Containers"),
                type: .containers
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Group Containers"),
                type: .containers
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Saved Application State"),
                type: .savedState
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/WebKit"),
                type: .other
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/HTTPStorages"),
                type: .other
            ),
            RemnantSearchPath(
                basePath: homeDirectory.appendingPathComponent("Library/Cookies"),
                type: .other
            )
        ]
    }

    static func findRemnants(for bundleIdentifier: String, appName: String) -> [URL] {
        var remnants: [URL] = []
        let fileManager = FileManager.default

        // Common patterns to search for
        let patterns = [
            bundleIdentifier,
            bundleIdentifier.lowercased(),
            appName,
            appName.lowercased(),
            appName.replacingOccurrences(of: " ", with: ""),
            appName.replacingOccurrences(of: " ", with: "-"),
            appName.replacingOccurrences(of: " ", with: "_")
        ]

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath.basePath.path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: searchPath.basePath,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                for item in contents {
                    let itemName = item.lastPathComponent
                    for pattern in patterns {
                        if itemName.localizedCaseInsensitiveContains(pattern) {
                            remnants.append(item)
                            break
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return remnants
    }
}

struct RemnantSearchPath: Identifiable {
    let id = UUID()
    let basePath: URL
    let type: RemnantType

    var exists: Bool {
        FileManager.default.fileExists(atPath: basePath.path)
    }
}
