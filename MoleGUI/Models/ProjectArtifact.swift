import Foundation

struct ProjectArtifact: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let projectName: String
    let artifactType: ArtifactType
    let size: Int64
    let lastModified: Date?
    var isSelected: Bool = true

    var formattedSize: String {
        ByteFormatter.format(size)
    }

    var age: String {
        guard let date = lastModified else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ProjectArtifact, rhs: ProjectArtifact) -> Bool {
        lhs.id == rhs.id
    }
}

enum ArtifactType: String, CaseIterable, Identifiable {
    case nodeModules = "node_modules"
    case target = "target"
    case build = "build"
    case dist = "dist"
    case dotBuild = ".build"
    case derivedData = "DerivedData"
    case pods = "Pods"
    case vendorBundle = "vendor_bundle"
    case pythonVenv = "venv"
    case pythonEnv = ".venv"
    case gradleBuild = ".gradle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nodeModules: return "shippingbox.fill"
        case .target: return "hammer.fill"
        case .build, .dotBuild: return "wrench.and.screwdriver.fill"
        case .dist: return "archivebox.fill"
        case .derivedData: return "xcode"
        case .pods: return "leaf.fill"
        case .vendorBundle: return "shippingbox"
        case .pythonVenv, .pythonEnv: return "terminal.fill"
        case .gradleBuild: return "gear"
        }
    }

    var color: String {
        switch self {
        case .nodeModules: return "green"
        case .target: return "orange"
        case .build, .dotBuild: return "blue"
        case .dist: return "purple"
        case .derivedData: return "cyan"
        case .pods: return "red"
        case .vendorBundle: return "red"
        case .pythonVenv, .pythonEnv: return "yellow"
        case .gradleBuild: return "teal"
        }
    }

    var description: String {
        switch self {
        case .nodeModules: return "Node.js dependencies"
        case .target: return "Build output (Rust/Cargo/Maven)"
        case .build: return "Build output directory"
        case .dist: return "Distribution files"
        case .dotBuild: return "Swift Package Manager build"
        case .derivedData: return "Xcode derived data"
        case .pods: return "CocoaPods dependencies"
        case .vendorBundle: return "Ruby bundler gems"
        case .pythonVenv: return "Python virtual environment"
        case .pythonEnv: return "Python environment (.venv)"
        case .gradleBuild: return "Gradle build cache"
        }
    }

    static func detect(from directoryName: String) -> ArtifactType? {
        switch directoryName {
        case "node_modules": return .nodeModules
        case "target": return .target
        case "build": return .build
        case "dist": return .dist
        case ".build": return .dotBuild
        case "DerivedData": return .derivedData
        case "Pods": return .pods
        case "venv": return .pythonVenv
        case ".venv": return .pythonEnv
        case ".gradle": return .gradleBuild
        default: return nil
        }
    }
}

struct ProjectGroup: Identifiable {
    let id = UUID()
    let type: ArtifactType
    var artifacts: [ProjectArtifact]

    var totalSize: Int64 {
        artifacts.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        artifacts.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var formattedSize: String {
        ByteFormatter.format(totalSize)
    }
}
