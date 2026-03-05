//
//  PlatformMetadataTests.swift
//  LightweightCharts Tests
//
//  Tests for validating consistency of platform metadata across all package managers.
//

import XCTest

/// Validates that all package metadata files (podspec, Package.swift, README.md, PLATFORM_POLICY.md)
/// specify the same minimum iOS version, ensuring consistency across distribution channels.
class PlatformMetadataTests: XCTestCase {

    // MARK: - Expected Platform Version

    /// The minimum iOS version that should be consistently specified across all metadata files
    private let expectediOSVersion = "13.0"

    // MARK: - File Paths

    private var projectRoot: String {
        return FileManager.default.currentDirectoryPath
    }

    private var podspecPath: String {
        return projectRoot + "/LightweightCharts.podspec"
    }

    private var packageSwiftPath: String {
        return projectRoot + "/Package.swift"
    }

    private var readmePath: String {
        return projectRoot + "/README.md"
    }

    private var platformPolicyPath: String {
        return projectRoot + "/PLATFORM_POLICY.md"
    }

    private var xcodeProjectPath: String {
        return projectRoot + "/Example/LightweightCharts.xcodeproj/project.pbxproj"
    }

    // MARK: - Test Files Exist

    func testAllMetadataFilesExist() {
        let podspecExists = FileManager.default.fileExists(atPath: podspecPath)
        let packageSwiftExists = FileManager.default.fileExists(atPath: packageSwiftPath)
        let readmeExists = FileManager.default.fileExists(atPath: readmePath)
        let platformPolicyExists = FileManager.default.fileExists(atPath: platformPolicyPath)
        let xcodeProjectExists = FileManager.default.fileExists(atPath: xcodeProjectPath)

        XCTAssertTrue(podspecExists, "LightweightCharts.podspec should exist")
        XCTAssertTrue(packageSwiftExists, "Package.swift should exist")
        XCTAssertTrue(readmeExists, "README.md should exist")
        XCTAssertTrue(platformPolicyExists, "PLATFORM_POLICY.md should exist")
        XCTAssertTrue(xcodeProjectExists, "Example Xcode project should exist")
    }

    // MARK: - Podspec Tests

    func testPodspecSpecifiesCorrectiOSVersion() {
        guard let content = try? String(contentsOfFile: podspecPath, encoding: .utf8) else {
            XCTFail("Could not read LightweightCharts.podspec")
            return
        }

        // Check for the correct deployment target line
        let expectedLine = "s.ios.deployment_target = '\(expectediOSVersion)'"
        XCTAssertTrue(content.contains(expectedLine),
                     "LightweightCharts.podspec should specify iOS \(expectediOSVersion)")
    }

    // MARK: - Package.swift Tests

    func testPackageSwiftSpecifiesCorrectiOSVersion() {
        guard let content = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            XCTFail("Could not read Package.swift")
            return
        }

        // Check for the correct iOS platform version
        let expectedPlatform = ".iOS(.v13)"
        XCTAssertTrue(content.contains(expectedPlatform),
                     "Package.swift should specify iOS \(expectediOSVersion)")
    }

    // MARK: - README Tests

    func testREADMESpecifiesCorrectiOSVersion() {
        guard let content = try? String(contentsOfFile: readmePath, encoding: .utf8) else {
            XCTFail("Could not read README.md")
            return
        }

        // Check for the iOS version requirement
        XCTAssertTrue(content.contains("iOS 13.0"),
                     "README.md should specify iOS 13.0 as minimum requirement")
    }

    // MARK: - PLATFORM_POLICY.md Tests

    func testPlatformPolicyDocumentsCorrectiOSVersion() {
        guard let content = try? String(contentsOfFile: platformPolicyPath, encoding: .utf8) else {
            XCTFail("Could not read PLATFORM_POLICY.md")
            return
        }

        // Check that the policy documents iOS 13.0
        XCTAssertTrue(content.contains("iOS 13.0"),
                     "PLATFORM_POLICY.md should document iOS 13.0 as minimum version")

        // Check it mentions the version table
        XCTAssertTrue(content.contains("| CocoaPods       | iOS 13.0"),
                     "PLATFORM_POLICY.md should list iOS 13.0 for CocoaPods")
        XCTAssertTrue(content.contains("| SPM             | iOS 13.0"),
                     "PLATFORM_POLICY.md should list iOS 13.0 for SPM")
    }

    // MARK: - Xcode Project Tests

    func testXcodeProjectSpecifiesCorrectiOSVersion() {
        guard let content = try? String(contentsOfFile: xcodeProjectPath, encoding: .utf8) else {
            XCTFail("Could not read Xcode project file")
            return
        }

        // Check for the correct deployment target settings
        let lines = content.components(separatedBy: .newlines)
        var deploymentTargetFound = false

        for line in lines {
            if line.contains("IPHONEOS_DEPLOYMENT_TARGET") {
                let cleanedLine = line.trimmingCharacters(in: .whitespaces)
                if cleanedLine.contains("= 13.0;") {
                    deploymentTargetFound = true
                } else if cleanedLine.contains("IPHONEOS_DEPLOYMENT_TARGET") {
                    XCTFail("Xcode project has incorrect deployment target: \(cleanedLine)")
                }
            }
        }

        XCTAssertTrue(deploymentTargetFound,
                     "Xcode project should specify iOS 13.0 as IPHONEOS_DEPLOYMENT_TARGET")
    }

    // MARK: - Cross-File Consistency Tests

    func testAllFilesSpecifySameiOSVersion() throws {
        // Extract iOS version from podspec
        let podspecContent = try String(contentsOfFile: podspecPath, encoding: .utf8)
        let podspecVersion = extractiOSVersion(fromPodspec: podspecContent)
        XCTAssertEqual(podspecVersion, "13.0",
                      "Podspec should specify iOS 13.0, found: \(podspecVersion ?? "nil")")

        // Verify Package.swift matches
        let packageSwiftContent = try String(contentsOfFile: packageSwiftPath, encoding: .utf8)
        let spmVersion = extractiOSVersion(fromPackageSwift: packageSwiftContent)
        XCTAssertEqual(spmVersion, "13.0",
                      "Package.swift should specify iOS 13.0, found: \(spmVersion ?? "nil")")

        // Verify Xcode project matches
        let xcodeProjectContent = try String(contentsOfFile: xcodeProjectPath, encoding: .utf8)
        let xcodeVersion = extractiOSVersion(fromXcodeProject: xcodeProjectContent)
        XCTAssertEqual(xcodeVersion, "13.0",
                      "Xcode project should specify iOS 13.0, found: \(xcodeVersion ?? "nil")")

        // All should be the same
        XCTAssertEqual(podspecVersion, spmVersion,
                      "Podspec and Package.swift should specify the same iOS version")
        XCTAssertEqual(podspecVersion, xcodeVersion,
                      "Podspec and Xcode project should specify the same iOS version")
    }

    func testPlatformPolicyMatchesImplementation() throws {
        let policyContent = try String(contentsOfFile: platformPolicyPath, encoding: .utf8)
        let podspecContent = try String(contentsOfFile: podspecPath, encoding: .utf8)
        let packageSwiftContent = try String(contentsOfFile: packageSwiftPath, encoding: .utf8)
        let xcodeProjectContent = try String(contentsOfFile: xcodeProjectPath, encoding: .utf8)

        // Extract the documented version from the policy
        let policyVersion = extractiOSVersion(fromPolicy: policyContent)
        XCTAssertEqual(policyVersion, "13.0",
                      "PLATFORM_POLICY.md should document iOS 13.0, found: \(policyVersion ?? "nil")")

        // Extract implementation versions
        let podspecVersion = extractiOSVersion(fromPodspec: podspecContent)
        let spmVersion = extractiOSVersion(fromPackageSwift: packageSwiftContent)
        let xcodeVersion = extractiOSVersion(fromXcodeProject: xcodeProjectContent)

        // All should match
        XCTAssertEqual(policyVersion, podspecVersion,
                      "PLATFORM_POLICY.md version should match podspec")
        XCTAssertEqual(policyVersion, spmVersion,
                      "PLATFORM_POLICY.md version should match Package.swift")
        XCTAssertEqual(policyVersion, xcodeVersion,
                      "PLATFORM_POLICY.md version should match Xcode project")
    }

    // MARK: - Helper Methods

    private func extractiOSVersion(fromPodspec content: String) -> String? {
        // Match: s.ios.deployment_target = '13.0'
        let pattern = #"s\.ios\.deployment_target\s*=\s*'(\d+\.\d+)'"#
        return extractFirstMatch(pattern: pattern, from: content)
    }

    private func extractiOSVersion(fromPackageSwift content: String) -> String? {
        // Match: .iOS(.v13) -> extract 13 and convert to 13.0
        let pattern = #"\.iOS\(\.v(\d+)\)"#
        if let majorVersion = extractFirstMatch(pattern: pattern, from: content) {
            return majorVersion + ".0"
        }
        return nil
    }

    private func extractiOSVersion(fromPolicy content: String) -> String? {
        // Look for the table row like: | CocoaPods       | iOS 13.0 |
        let pattern = #"\|\s*CocoaPods.*\|\s*iOS\s*(\d+\.\d+)"#
        return extractFirstMatch(pattern: pattern, from: content)
    }

    private func extractiOSVersion(fromXcodeProject content: String) -> String? {
        // Match: IPHONEOS_DEPLOYMENT_TARGET = 13.0;
        let pattern = #"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*(\d+\.\d+);"#
        return extractFirstMatch(pattern: pattern, from: content)
    }

    private func extractFirstMatch(pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        guard let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[captureRange])
    }
}
