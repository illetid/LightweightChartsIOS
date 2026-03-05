//
//  MigrationGuideTests.swift
//  LightweightCharts Tests
//
//  Tests for validating the migration guide documentation.
//

import XCTest
@testable import LightweightCharts

/// Validates that the MIGRATION_V4_TO_V5.md documentation exists and contains required sections.
class MigrationGuideTests: XCTestCase {

    func testMigrationGuideFileExists() {

        // File should exist at project root
        let projectRootFile = FileManager.default.currentDirectoryPath + "/MIGRATION_V4_TO_V5.md"
        let fileExists = FileManager.default.fileExists(atPath: projectRootFile)

        XCTAssertTrue(fileExists, "MIGRATION_V4_TO_V5.md should exist in the project root")
    }

    func testMigrationGuideContainsRequiredSections() {
        let projectRootFile = FileManager.default.currentDirectoryPath + "/MIGRATION_V4_TO_V5.md"

        guard let content = try? String(contentsOfFile: projectRootFile, encoding: .utf8) else {
            XCTFail("Could not read migration guide file")
            return
        }

        // Required sections
        let requiredSections = [
            "# Lightweight Charts iOS Migration Guide: v4 to v5",
            "## Overview of Changes",
            "## Platform Changes",
            "## Watermark Migration",
            "## New Plugin APIs",
            "## Series Markers Plugin",
            "## Up/Down Markers Plugin",
            "## Text Watermark Plugin",
            "## Image Watermark Plugin",
            "## Breaking Changes",
            "## Testing Your Migration"
        ]

        for section in requiredSections {
            XCTAssertTrue(content.contains(section), "Migration guide should contain section: \(section)")
        }
    }

    func testMigrationGuideContainsCodeExamples() {
        let projectRootFile = FileManager.default.currentDirectoryPath + "/MIGRATION_V4_TO_V5.md"

        guard let content = try? String(contentsOfFile: projectRootFile, encoding: .utf8) else {
            XCTFail("Could not read migration guide file")
            return
        }

        // Should have before/after examples
        XCTAssertTrue(content.contains("```swift"), "Migration guide should contain Swift code examples")
        XCTAssertTrue(content.contains("**Before (v4):**"), "Migration guide should show 'before' examples")
        XCTAssertTrue(content.contains("**After (v5):**"), "Migration guide should show 'after' examples")
    }

    func testMigrationGuideMentionsAllAPIs() {
        let projectRootFile = FileManager.default.currentDirectoryPath + "/MIGRATION_V4_TO_V5.md"

        guard let content = try? String(contentsOfFile: projectRootFile, encoding: .utf8) else {
            XCTFail("Could not read migration guide file")
            return
        }

        // Should mention all new plugin APIs
        let apiReferences = [
            "createMarkersPlugin",
            "createUpDownMarkersPlugin",
            "createTextWatermarkPlugin",
            "createImageWatermarkPlugin",
            "setMarkers",
            "ChartOptions.watermark",
            "TextWatermarkOptions",
            "ImageWatermarkOptions",
            "SeriesMarkersOptions",
            "UpDownMarkersOptions"
        ]

        for api in apiReferences {
            XCTAssertTrue(content.contains(api), "Migration guide should mention API: \(api)")
        }
    }
}
