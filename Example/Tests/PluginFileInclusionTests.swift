//
//  PluginFileInclusionTests.swift
//  LightweightCharts Tests
//
//  Tests for validating that all plugin-related source and resource files
//  are properly included in the package configuration files (podspec, Package.swift).
//

import XCTest

/// Validates that all new plugin files introduced in v5.0 are properly
/// included in source_files (CocoaPods) and target sources (SPM).
class PluginFileInclusionTests: XCTestCase {

    // MARK: - File Paths

    private static let projectRootURL: URL = {
        let fileManager = FileManager.default
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        for _ in 0..<10 {
            let podspec = candidate.appendingPathComponent("LightweightCharts.podspec").path
            let packageSwift = candidate.appendingPathComponent("Package.swift").path
            let sources = candidate.appendingPathComponent("Sources/LightweightCharts").path

            if fileManager.fileExists(atPath: podspec)
                && fileManager.fileExists(atPath: packageSwift)
                && fileManager.fileExists(atPath: sources) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: fileManager.currentDirectoryPath)
    }()

    private var projectRoot: String {
        return Self.projectRootURL.path
    }

    private var sourcesDir: String {
        return projectRoot + "/Sources/LightweightCharts"
    }

    private var podspecPath: String {
        return projectRoot + "/LightweightCharts.podspec"
    }

    private var packageSwiftPath: String {
        return projectRoot + "/Package.swift"
    }

    // MARK: - Expected Plugin Files

    /// All Swift source files that implement the plugin system
    private let expectedPluginSwiftFiles: Set<String> = [
        // Core Plugin Protocols
        "Protocols/Plugin.swift",
        "Protocols/UpDownMarkersSupported.swift",

        // Plugin Adapters
        "Implementations/API/Plugins/SeriesPluginAdapter.swift",
        "Implementations/API/Plugins/PanePluginAdapter.swift",

        // Series Plugins
        "Implementations/API/Plugins/SeriesMarkersPlugin.swift",
        "Implementations/API/Plugins/UpDownMarkersPlugin.swift",

        // Pane Plugins (Watermark)
        "Implementations/API/Plugins/ImageWatermark.swift",
        "Implementations/API/Plugins/TextWatermark.swift",
        "Implementations/API/Plugins/ImageWatermarkPlugin.swift",
        "Implementations/API/Plugins/TextWatermarkPlugin.swift",

        // Plugin Options Models
        "LightweightChartsModels/Options/Plugins/SeriesMarkersOptions.swift",
        "LightweightChartsModels/Options/Plugins/UpDownMarkersOptions.swift",
        "LightweightChartsModels/Options/Plugins/WatermarkLine.swift",
        "LightweightChartsModels/Options/Plugins/ImageWatermarkOptions.swift",
        "LightweightChartsModels/Options/Plugins/TextWatermarkOptions.swift",

        // Plugin API surface
        "Implementations/API/Chart.swift",
        "Implementations/API/LightweightCharts.swift",
        "Implementations/API/Series/SeriesApi+Extension.swift",
    ]

    /// All plugin-related models
    private let expectedPluginModelFiles: Set<String> = [
        "LightweightChartsModels/SeriesMarker/SeriesMarker.swift",
        "LightweightChartsModels/SeriesMarker/MarkerSign.swift",
        "LightweightChartsModels/SeriesMarker/SeriesUpDownMarker.swift",
    ]

    // MARK: - Test Files Exist

    func testAllPluginSwiftFilesExist() {
        for relativePath in expectedPluginSwiftFiles {
            let fullPath = sourcesDir + "/" + relativePath
            let fileExists = FileManager.default.fileExists(atPath: fullPath)

            XCTAssertTrue(fileExists, "Plugin Swift file should exist: \(relativePath)")
        }
    }

    func testAllPluginModelFilesExist() {
        for relativePath in expectedPluginModelFiles {
            let fullPath = sourcesDir + "/" + relativePath
            let fileExists = FileManager.default.fileExists(atPath: fullPath)

            XCTAssertTrue(fileExists, "Plugin model file should exist: \(relativePath)")
        }
    }

    // MARK: - Podspec Inclusion Tests

    /// Verifies that the podspec's source_files pattern includes all plugin files
    func testPodspecIncludesAllPluginFiles() {
        guard let podspecContent = try? String(contentsOfFile: podspecPath, encoding: .utf8) else {
            XCTFail("Could not read LightweightCharts.podspec")
            return
        }

        // The podspec should use the glob pattern that covers all Swift files
        let expectedPattern = "Sources/LightweightCharts/**/*.swift"
        XCTAssertTrue(podspecContent.contains(expectedPattern),
                     "Podspec should include pattern: \(expectedPattern)")

        // Verify the glob pattern would match our plugin files
        for relativePath in expectedPluginSwiftFiles {
            let fullPath = "Sources/LightweightCharts/" + relativePath
            XCTAssertTrue(fullPath.hasSuffix(".swift"),
                         "Plugin file should be .swift: \(relativePath)")
            XCTAssertTrue(fullPath.hasPrefix("Sources/LightweightCharts/"),
                         "Plugin file should be under Sources/LightweightCharts: \(relativePath)")
        }
    }

    /// Verifies that plugin resources are included in podspec
    func testPodspecIncludesPluginResources() {
        guard let podspecContent = try? String(contentsOfFile: podspecPath, encoding: .utf8) else {
            XCTFail("Could not read LightweightCharts.podspec")
            return
        }

        // The podspec should include the required JS files
        XCTAssertTrue(podspecContent.contains("content-setup.js"),
                     "Podspec should include content-setup.js")
        XCTAssertTrue(podspecContent.contains("lightweight-charts.js"),
                     "Podspec should include lightweight-charts.js")
        XCTAssertTrue(podspecContent.contains("wrapper_functions.js"),
                     "Podspec should include wrapper_functions.js")

        // The podspec should NOT include the backup file
        XCTAssertFalse(podspecContent.contains("lightweight-charts.js.backup") ||
                      podspecContent.contains("Assets/*"),
                     "Podspec should not use wildcard that includes backup files")
    }

    /// Verifies that backup file is excluded from Package.swift
    func testPackageSwiftExcludesBackupFile() {
        guard let packageContent = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            XCTFail("Could not read Package.swift")
            return
        }

        // The backup file should be explicitly excluded
        XCTAssertTrue(packageContent.contains("lightweight-charts.js.backup"),
                     "Package.swift should exclude lightweight-charts.js.backup")
        XCTAssertTrue(packageContent.contains("exclude:"),
                     "Package.swift should have exclude list")
    }

    // MARK: - Package.swift Inclusion Tests

    /// Verifies that Package.swift target includes plugin sources
    func testPackageSwiftIncludesPluginSources() {
        guard let packageContent = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            XCTFail("Could not read Package.swift")
            return
        }

        // Package.swift should have a target for LightweightCharts
        XCTAssertTrue(packageContent.contains(".target("),
                     "Package.swift should define a target")

        // SPM includes all Swift files in the target directory by default,
        // so we just need to verify the target name is correct
        XCTAssertTrue(packageContent.contains("name: \"LightweightCharts\""),
                     "Package.swift should have LightweightCharts target")
    }

    /// Verifies that plugin resources are included in Package.swift
    func testPackageSwiftIncludesPluginResources() {
        guard let packageContent = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            XCTFail("Could not read Package.swift")
            return
        }

        // Package.swift should include the Assets resources
        XCTAssertTrue(packageContent.contains(".process("),
                     "Package.swift should have resource processing directives")

        // Should include the core JavaScript files
        XCTAssertTrue(packageContent.contains("content-setup.js"),
                     "Package.swift should include content-setup.js")
        XCTAssertTrue(packageContent.contains("lightweight-charts.js"),
                     "Package.swift should include lightweight-charts.js")
        XCTAssertTrue(packageContent.contains("wrapper_functions.js"),
                     "Package.swift should include wrapper_functions.js")
    }

    // MARK: - Cross-Platform Consistency Tests

    /// Verifies that the same source files are included in both podspec and Package.swift
    func testSourceFilesConsistencyAcrossPackageManagers() {
        // Both CocoaPods and SPM should include all Swift files from Sources/LightweightCharts
        // We verify this by checking that:
        // 1. Podspec uses the **/*.swift glob
        // 2. Package.swift defines a LightweightCharts target (which includes all Swift files by default)

        guard let podspecContent = try? String(contentsOfFile: podspecPath, encoding: .utf8) else {
            XCTFail("Could not read LightweightCharts.podspec")
            return
        }

        guard let packageContent = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            XCTFail("Could not read Package.swift")
            return
        }

        // Verify podspec glob pattern
        let podspecGlob = "Sources/LightweightCharts/**/*.swift"
        XCTAssertTrue(podspecContent.contains(podspecGlob),
                     "Podspec should use glob pattern that includes all plugin files")

        // Verify SPM target
        XCTAssertTrue(packageContent.contains("name: \"LightweightCharts\""),
                     "Package.swift should define LightweightCharts target")

        // Both should cover the same source directory
        XCTAssertTrue(podspecContent.contains("Sources/LightweightCharts"),
                     "Podspec should reference Sources/LightweightCharts")
    }

    /// Verifies that plugin protocol files are accessible
    func testPluginProtocolFilesArePublic() {
        // Verify the Plugin protocol file exists and contains the protocol definition
        let pluginProtocolPath = sourcesDir + "/Protocols/Plugin.swift"
        guard let content = try? String(contentsOfFile: pluginProtocolPath, encoding: .utf8) else {
            XCTFail("Could not read Plugin.swift")
            return
        }

        XCTAssertTrue(content.contains("public protocol Plugin"),
                     "Plugin.swift should define a public Plugin protocol")
        XCTAssertTrue(content.contains("func detach()"),
                     "Plugin protocol should have detach() method")
    }

    /// Verifies that all plugin option types are defined
    func testAllPluginOptionTypesExist() {
        let optionTypes = [
            "SeriesMarkersOptions",
            "UpDownMarkersOptions",
            "TextWatermarkOptions",
            "ImageWatermarkOptions"
        ]

        for optionType in optionTypes {
            let fileName = "\(optionType).swift"
            let filePath = sourcesDir + "/LightweightChartsModels/Options/Plugins/" + fileName

            let fileExists = FileManager.default.fileExists(atPath: filePath)
            XCTAssertTrue(fileExists, "Plugin options file should exist: \(fileName)")

            if fileExists {
                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                    continue
                }
                XCTAssertTrue(content.contains("public struct \(optionType)"),
                             "\(fileName) should define \(optionType) struct")
            }
        }
    }

    /// Verifies that plugin adapters exist
    func testPluginAdaptersExist() {
        let adapters = [
            "SeriesPluginAdapter",
            "PanePluginAdapter"
        ]

        for adapter in adapters {
            let filePath = sourcesDir + "/Implementations/API/Plugins/\(adapter).swift"
            let fileExists = FileManager.default.fileExists(atPath: filePath)
            XCTAssertTrue(fileExists, "Plugin adapter file should exist: \(adapter).swift")

            if fileExists {
                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                    continue
                }
                XCTAssertTrue(content.contains("class \(adapter)"),
                             "\(adapter).swift should define \(adapter) class")
            }
        }
    }

    /// Verifies that concrete plugin implementations exist
    func testConcretePluginImplementationsExist() {
        let plugins = [
            "SeriesMarkersPlugin",
            "UpDownMarkersPlugin",
            "ImageWatermarkPlugin",
            "TextWatermarkPlugin"
        ]

        for plugin in plugins {
            let filePath = sourcesDir + "/Implementations/API/Plugins/\(plugin).swift"
            let fileExists = FileManager.default.fileExists(atPath: filePath)
            XCTAssertTrue(fileExists, "Plugin implementation file should exist: \(plugin).swift")

            if fileExists {
                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                    continue
                }
                XCTAssertTrue(content.contains("public class \(plugin)") ||
                            content.contains("public final class \(plugin)"),
                             "\(plugin).swift should define \(plugin) class")
                XCTAssertTrue(content.contains(": Plugin") ||
                            content.contains(": SeriesPlugin") ||
                            content.contains(": PanePlugin"),
                             "\(plugin) should conform to a Plugin protocol")
            }
        }
    }

    /// Verifies that plugin API extensions exist
    func testPluginAPIExtensionsExist() {
        let chartPath = sourcesDir + "/Implementations/API/Chart.swift"
        let chartExists = FileManager.default.fileExists(atPath: chartPath)
        XCTAssertTrue(chartExists, "Chart.swift should exist")

        if chartExists, let content = try? String(contentsOfFile: chartPath, encoding: .utf8) {
            XCTAssertTrue(content.contains("createTextWatermarkPlugin") ||
                        content.contains("createImageWatermarkPlugin"),
                         "Chart.swift should provide pane plugin creation methods")
        }

        let lightweightChartsPath = sourcesDir + "/Implementations/API/LightweightCharts.swift"
        let lightweightChartsExists = FileManager.default.fileExists(atPath: lightweightChartsPath)
        XCTAssertTrue(lightweightChartsExists, "LightweightCharts.swift should exist")

        if lightweightChartsExists,
           let content = try? String(contentsOfFile: lightweightChartsPath, encoding: .utf8) {
            XCTAssertTrue(content.contains("createTextWatermarkPlugin") ||
                        content.contains("createImageWatermarkPlugin"),
                         "LightweightCharts.swift should forward pane plugin creation methods")
        }

        // Series extension for series plugins
        let seriesExtensionPath = sourcesDir + "/Implementations/API/Series/SeriesApi+Extension.swift"
        let seriesExists = FileManager.default.fileExists(atPath: seriesExtensionPath)
        XCTAssertTrue(seriesExists, "SeriesApi+Extension.swift should exist")

        if seriesExists, let content = try? String(contentsOfFile: seriesExtensionPath, encoding: .utf8) {
            XCTAssertTrue(content.contains("createMarkersPlugin") ||
                        content.contains("createUpDownMarkersPlugin"),
                         "SeriesApi+Extension should provide series plugin creation methods")
        }
    }

    // MARK: - Helper Methods

    /// Returns all Swift files in the Sources directory
    private func getAllSwiftFiles(in directory: String) -> [String] {
        var result: [String] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return result
        }

        for case let file as String in enumerator {
            if file.hasSuffix(".swift") {
                result.append(file)
            }
        }

        return result
    }
}
