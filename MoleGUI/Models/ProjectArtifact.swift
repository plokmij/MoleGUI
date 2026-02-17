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
    case pytestCache = ".pytest_cache"
    case mypyCache = ".mypy_cache"
    case tox = ".tox"
    case nox = ".nox"
    case ruffCache = ".ruff_cache"
    case nuxt = ".nuxt"
    case dotOutput = ".output"
    case turbo = ".turbo"
    case parcelCache = ".parcel-cache"
    case zigCache = ".zig-cache"
    case angular = ".angular"
    case svelteKit = ".svelte-kit"
    case coverage = "coverage"
    case cxx = ".cxx"
    case expo = ".expo"

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
        case .pytestCache, .mypyCache, .ruffCache: return "checklist"
        case .tox, .nox: return "flask"
        case .nuxt, .angular, .svelteKit: return "globe"
        case .dotOutput, .turbo, .parcelCache: return "bolt"
        case .zigCache, .cxx: return "hammer"
        case .coverage: return "chart.bar"
        case .expo: return "iphone"
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
        case .pytestCache, .mypyCache, .ruffCache: return "indigo"
        case .tox, .nox: return "mint"
        case .nuxt, .angular, .svelteKit: return "green"
        case .dotOutput, .turbo, .parcelCache: return "orange"
        case .zigCache, .cxx: return "brown"
        case .coverage: return "purple"
        case .expo: return "blue"
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
        case .pytestCache: return "pytest cache"
        case .mypyCache: return "mypy type checker cache"
        case .tox: return "tox testing environments"
        case .nox: return "nox testing sessions"
        case .ruffCache: return "Ruff linter cache"
        case .nuxt: return "Nuxt.js build output"
        case .dotOutput: return "Build output directory"
        case .turbo: return "Turborepo cache"
        case .parcelCache: return "Parcel bundler cache"
        case .zigCache: return "Zig compiler cache"
        case .angular: return "Angular build cache"
        case .svelteKit: return "SvelteKit build output"
        case .coverage: return "Code coverage reports"
        case .cxx: return "C++ CMake build files"
        case .expo: return "Expo/React Native cache"
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
        case ".pytest_cache": return .pytestCache
        case ".mypy_cache": return .mypyCache
        case ".tox": return .tox
        case ".nox": return .nox
        case ".ruff_cache": return .ruffCache
        case ".nuxt": return .nuxt
        case ".output": return .dotOutput
        case ".turbo": return .turbo
        case ".parcel-cache": return .parcelCache
        case ".zig-cache": return .zigCache
        case ".angular": return .angular
        case ".svelte-kit": return .svelteKit
        case "coverage": return .coverage
        case ".cxx": return .cxx
        case ".expo": return .expo
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
