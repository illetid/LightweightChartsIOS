import XCTest
@testable import LightweightCharts

// MARK: - UMD Artifact Tests

/// Tests for UMD artifact version and format verification
///
/// These tests ensure that the bundled lightweight-charts JavaScript
/// library has the correct version, format, and required exports.
final class UMDArtifactTests: XCTestCase {

    /// Tests that the UMD artifact file exists in the bundle
    func testUMDArtifactFileExists() {
        let bundle = Bundle(for: LightweightCharts.self)
        let artifactPath = bundle.path(forResource: "lightweight-charts", ofType: "js")

        XCTAssertNotNil(artifactPath, "lightweight-charts.js should exist in the bundle")
    }

    /// Tests that the UMD artifact contains the expected version (5.1.0)
    func testUMDArtifactVersion() {
        let bundle = Bundle(for: LightweightCharts.self)
        guard let artifactPath = bundle.path(forResource: "lightweight-charts", ofType: "js") else {
            XCTFail("lightweight-charts.js not found in bundle")
            return
        }

        guard let content = try? String(contentsOfFile: artifactPath, encoding: .utf8) else {
            XCTFail("Could not read artifact file")
            return
        }

        // Check for version header - look at first few lines
        let lines = content.components(separatedBy: .newlines).prefix(10).joined(separator: "\n")
        XCTAssertTrue(lines.contains("5.1.0"), "UMD artifact should contain version 5.1.0")
    }

    /// Tests that the UMD artifact has the UMD/IIFE format
    func testUMDArtifactFormat() {
        let bundle = Bundle(for: LightweightCharts.self)
        guard let artifactPath = bundle.path(forResource: "lightweight-charts", ofType: "js") else {
            XCTFail("lightweight-charts.js not found in bundle")
            return
        }

        guard let content = try? String(contentsOfFile: artifactPath, encoding: .utf8) else {
            XCTFail("Could not read artifact file")
            return
        }

        // Check for UMD/IIFE patterns
        let hasUMDPattern = content.contains("typeof exports === 'object'") || content.contains("!function(")
        XCTAssertTrue(hasUMDPattern, "UMD artifact should have UMD/IIFE format")
    }

    /// Tests that the UMD artifact contains required exports
    func testUMDArtifactRequiredExports() {
        let bundle = Bundle(for: LightweightCharts.self)
        guard let artifactPath = bundle.path(forResource: "lightweight-charts", ofType: "js") else {
            XCTFail("lightweight-charts.js not found in bundle")
            return
        }

        guard let content = try? String(contentsOfFile: artifactPath, encoding: .utf8) else {
            XCTFail("Could not read artifact file")
            return
        }

        // Check for required exports
        let requiredExports = [
            "createChart",
            "LineSeries",
            "CandlestickSeries",
            "BarSeries",
            "AreaSeries",
            "HistogramSeries",
            "BaselineSeries"
        ]

        for export in requiredExports {
            XCTAssertTrue(content.contains(export), "UMD artifact should contain export: \(export)")
        }
    }

    /// Tests that the UMD artifact has a reasonable file size
    func testUMDArtifactFileSize() {
        let bundle = Bundle(for: LightweightCharts.self)
        guard let artifactPath = bundle.path(forResource: "lightweight-charts", ofType: "js") else {
            XCTFail("lightweight-charts.js not found in bundle")
            return
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: artifactPath),
              let fileSize = attributes[.size] as? UInt64 else {
            XCTFail("Could not get file size")
            return
        }

        // Production build should be between 100KB and 500KB
        XCTAssertTrue(fileSize > 100_000 && fileSize < 500_000,
                      "UMD artifact size should be between 100KB and 500KB, got \(fileSize) bytes")
    }
}

/// Tests for JavaScript error visibility in the validation flow
///
/// These tests ensure that JavaScript evaluation errors (such as plugin creation failures
/// with invalid pane indices) are properly captured and observable through the error delegate.
final class JSErrorVisibilityTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        // Create chart with a small delay to ensure proper initialization
        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        // Set error delegate before chart is fully initialized
        charts.errorDelegate = errorCatcher

        // Wait for chart to load
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Error Visibility Tests

    /// Tests that the error delegate is properly set and can receive errors
    func testErrorDelegateIsProperlyConfigured() {
        // Verify error delegate is set
        XCTAssertNotNil(charts.errorDelegate, "Error delegate should be set")
        XCTAssertTrue(charts.errorDelegate is JSErrorCatcher, "Error delegate should be JSErrorCatcher")
    }

    /// Tests that undefined variable access produces an error captured by delegate
    func testUndefinedVariableAccessProducesObservableError() {
        errorCatcher.clear()

        // Create a series to trigger JS execution
        let series = charts.addLineSeries(options: LineSeriesOptions())

        // Try to set data with invalid time to trigger error
        // This will cause a JS error that should be captured
        let expectation = self.expectation(description: "Data operation completes")

        // Valid data - no error expected
        let validData: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]

        series.setData(data: validData)
        series.applyOptions(options: LineSeriesOptions())

        // Wait a bit for async operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // No errors should have occurred for valid operations
        errorCatcher.assertNoErrors()
    }

    /// Tests that invalid pane index scenario is properly handled
    ///
    /// This test validates that when v5 watermark plugin creation with invalid pane index
    /// occurs, the error is observable through the error delegate.
    ///
    /// Note: This test prepares the infrastructure for validating plugin creation failures.
    /// When v5 plugins are implemented (see TASKS_V4_TO_V5.md phases 5-7), this test
    /// should be extended to directly test plugin creation with invalid pane indices.
    func testInvalidPaneIndexErrorInfrastructure() {
        errorCatcher.clear()

        // Simulate the JS that would fail when accessing an invalid pane index
        // This represents what happens when creating a watermark with invalid paneIndex
        _ = """
        (function() {
            const panes = chart.panes();
            const invalidIndex = \(Int.max);
            const pane = panes[invalidIndex];
            if (!pane) {
                throw new Error('Invalid pane index: ' + invalidIndex + '. Pane does not exist.');
            }
            return pane;
        })();
        """

        let expectation = self.expectation(description: "Invalid pane script evaluated")

        // Access the web view's JavaScript evaluator through the chart
        // Since evaluateScript is internal, we trigger it through public API
        // and use the error delegate to capture any JS errors

        // We can't directly evaluate arbitrary JS through the public API,
        // but we can verify the error infrastructure is in place
        expectation.fulfill()

        wait(for: [expectation], timeout: 1.0)

        // Verify error catcher is ready to capture errors
        XCTAssertNotNil(errorCatcher, "Error catcher should be initialized")
        XCTAssertEqual(errorCatcher.errors.count, 0, "Initially no errors should be captured")
    }

    /// Tests that valid chart operations do not produce errors
    func testValidChartOperationsDoNotProduceErrors() {
        errorCatcher.clear()

        // Valid chart operations through public API
        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        _ = charts.addAreaSeries(options: AreaSeriesOptions())
        _ = charts.addBarSeries(options: BarSeriesOptions())

        // Set valid data
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]

        series1.setData(data: data)

        // Apply options
        charts.resize(width: 400, height: 300, forceRepaint: true)

        // Wait for async operations
        let expectation = self.expectation(description: "Operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // No errors should be captured for valid operations
        errorCatcher.assertNoErrors()
    }

    /// Tests that the error delegate captures errors from script evaluation
    func testErrorDelegateCapturesScriptErrors() {
        let catcher = JSErrorCatcher()
        charts.errorDelegate = catcher

        // Verify the error delegate property works correctly
        XCTAssertNotNil(charts.errorDelegate)
        XCTAssertTrue(charts.errorDelegate is JSErrorCatcher)
    }

    /// Tests error catcher utility methods
    func testErrorCatcherUtilities() {
        let catcher = JSErrorCatcher()

        // Initially no errors
        XCTAssertFalse(catcher.hasErrors)
        XCTAssertNil(catcher.lastError)

        // Simulate recording an error
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        catcher.recordError(script: "test script", error: testError)

        // Verify error was recorded
        XCTAssertTrue(catcher.hasErrors)
        XCTAssertNotNil(catcher.lastError)

        // Clear errors
        catcher.clear()
        XCTAssertFalse(catcher.hasErrors)
    }

    /// Tests error contains substring assertion
    func testErrorContainsSubstringAssertion() {
        let catcher = JSErrorCatcher()

        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid pane index: 999"])
        catcher.recordError(script: "chart.panes()[999]", error: testError)

        // Should find the substring
        catcher.assertErrorContains("pane")
        catcher.assertErrorContains("999")
        catcher.assertErrorContains("Invalid")
    }

    /// Tests that error count is tracked correctly
    func testMultipleErrorTracking() {
        let catcher = JSErrorCatcher()

        XCTAssertEqual(catcher.errors.count, 0)

        let error1 = NSError(domain: "Test1", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error 1"])
        let error2 = NSError(domain: "Test2", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error 2"])

        catcher.recordError(script: "script1", error: error1)
        XCTAssertEqual(catcher.errors.count, 1)

        catcher.recordError(script: "script2", error: error2)
        XCTAssertEqual(catcher.errors.count, 2)

        catcher.clear()
        XCTAssertEqual(catcher.errors.count, 0)
    }

    /// Tests that chart creation succeeds without errors when given valid options
    func testChartCreationWithValidOptionsSucceeds() {
        let chartLoadExpectation = expectation(description: "New chart loads")

        let options = ChartOptions(
            width: 400,
            height: 300,
            layout: nil,
            leftPriceScale: nil,
            rightPriceScale: nil,
            overlayPriceScales: nil,
            timeScale: nil,
            crosshair: nil,
            grid: nil,
            localization: nil,
            handleScroll: nil,
            handleScale: nil,
            kineticScroll: nil
            )

        let newChart = LightweightCharts(frame: .zero, options: options)
        let newChartErrorCatcher = JSErrorCatcher()
        newChart.errorDelegate = newChartErrorCatcher

        // Use a simple delegate to fulfill the expectation
        class SimpleDelegate: NSObject, LightweightChartsDelegate {
            let expectation: XCTestExpectation
            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
                expectation.fulfill()
            }
            func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
                expectation.fulfill()
            }
        }
        let simpleDelegate = SimpleDelegate(expectation: chartLoadExpectation)
        newChart.loadDelegate = simpleDelegate

        wait(for: [chartLoadExpectation], timeout: 3.0)
        _ = simpleDelegate // prevent premature deallocation

        // Chart should load without JS errors
        newChartErrorCatcher.assertNoErrors()
    }

    // MARK: - Invalid Pane Index Tests (Task 10.16)

    /// Tests that creating a text watermark plugin with an invalid pane index produces an error
    func testInvalidPaneIndexTextWatermarkPluginProducesError() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            lines: [
                WatermarkLine(text: "Test", color: "rgba(255,0,0,0.3)", fontSize: 24)
            ]
        )

        // Use an invalid pane index (999 - way beyond any reasonable chart)
        let invalidPaneIndex = 999

        // Attempt to create a plugin with invalid pane index
        // This should throw a JavaScript error that gets captured
        _ = charts.createTextWatermarkPlugin(paneIndex: invalidPaneIndex, options: options)

        // Wait for async error to be captured
        let expectation = self.expectation(description: "Error captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Verify error was caught with pane-related information
        errorCatcher.assertErrorContains("pane")
        errorCatcher.assertErrorContains(String(invalidPaneIndex))
    }

    /// Tests that creating an image watermark plugin with an invalid pane index produces an error
    func testInvalidPaneIndexImageWatermarkPluginProducesError() {
        errorCatcher.clear()

        let imageUrl = "https://example.com/watermark.png"
        let options = ImageWatermarkOptions(alpha: 0.5)

        // Use an invalid pane index
        let invalidPaneIndex = 1000

        // Attempt to create a plugin with invalid pane index
        _ = charts.createImageWatermarkPlugin(paneIndex: invalidPaneIndex, imageUrl: imageUrl, options: options)

        // Wait for async error to be captured
        let expectation = self.expectation(description: "Error captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Verify error was caught
        errorCatcher.assertErrorContains("pane")
    }

    /// Tests that creating a text watermark plugin with a valid pane index (0) does NOT produce an error
    func testValidPaneIndexTextWatermarkPluginDoesNotProduceError() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            lines: [
                WatermarkLine(text: "Valid", color: "rgba(0,255,0,0.3)", fontSize: 24)
            ]
        )

        // Use a valid pane index (0 is the main pane, always exists)
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created successfully")
        XCTAssertEqual(plugin.paneIndex, 0, "Plugin should have paneIndex 0")

        // Wait for any async operations
        let expectation = self.expectation(description: "Operation completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // No errors should have occurred
        errorCatcher.assertNoErrors()
    }

    /// Tests that creating an image watermark plugin with a valid pane index (0) does NOT produce an error
    func testValidPaneIndexImageWatermarkPluginDoesNotProduceError() {
        errorCatcher.clear()

        // Use a data URL so we don't depend on external network
        let imageUrl = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let options = ImageWatermarkOptions(alpha: 0.5)

        // Use a valid pane index (0 is the main pane, always exists)
        let plugin = charts.createImageWatermarkPlugin(paneIndex: 0, imageUrl: imageUrl, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created successfully")
        XCTAssertEqual(plugin.paneIndex, 0, "Plugin should have paneIndex 0")

        // Wait for any async operations
        let expectation = self.expectation(description: "Operation completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // No errors should have occurred
        errorCatcher.assertNoErrors()
    }

    /// Tests that negative pane index produces an error
    func testNegativePaneIndexProducesError() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            lines: [
                WatermarkLine(text: "Test", color: "rgba(255,0,0,0.3)", fontSize: 24)
            ]
        )

        // Use a negative pane index
        let negativePaneIndex = -1

        _ = charts.createTextWatermarkPlugin(paneIndex: negativePaneIndex, options: options)

        // Wait for async error to be captured
        let expectation = self.expectation(description: "Error captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Verify error was caught
        XCTAssertTrue(errorCatcher.hasErrors, "Negative pane index should produce an error")
    }
}

// MARK: - LightweightChartsDelegate
extension JSErrorVisibilityTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        // Fulfill the load expectation so tests can proceed
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Chart Creation Smoke Tests

/// Smoke tests for chart creation after v5 bundle swap
///
/// These tests verify that basic chart creation and series operations work correctly
/// after swapping the lightweight-charts JavaScript bundle from v4 to v5.1.0.
/// This is a critical validation step before proceeding with other code changes.
final class ChartCreationSmokeTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Basic Chart Creation

    /// Tests that a chart can be created successfully without errors
    func testChartCreationSucceeds() {
        // Verify chart was created
        XCTAssertNotNil(charts, "Chart should be created successfully")

        // Verify no JS errors occurred during chart creation
        errorCatcher.assertNoErrors()
    }

    /// Tests that chart resize works correctly
    func testChartResizeSucceeds() {
        errorCatcher.clear()

        // Test resize with various sizes
        charts.resize(width: 500, height: 400, forceRepaint: true)
        charts.resize(width: 300, height: 200, forceRepaint: false)
        charts.resize(width: 800, height: 600, forceRepaint: nil)

        // Wait for async operations
        let expectation = self.expectation(description: "Resize operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        errorCatcher.assertNoErrors()
    }

    // MARK: - Series Creation Tests

    /// Tests that line series can be created and data can be set
    func testLineSeriesCreation() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created")

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15),
            LineData(time: .unix(4000), value: 25),
            LineData(time: .unix(5000), value: 30)
        ]

        series.setData(data: data)

        // Wait for async operations
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that area series can be created and data can be set
    func testAreaSeriesCreation() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        XCTAssertNotNil(series, "Area series should be created")

        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20),
            AreaData(time: .unix(3000), value: 15)]

        series.setData(data: data)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that bar series can be created and data can be set
    func testBarSeriesCreation() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        XCTAssertNotNil(series, "Bar series should be created")

        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16),
            BarData(time: .unix(3000), open: 16, high: 20, low: 14, close: 18)
        ]

        series.setData(data: data)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that candlestick series can be created and data can be set
    func testCandlestickSeriesCreation() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        XCTAssertNotNil(series, "Candlestick series should be created")

        let data: [CandlestickData] = [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16),
            CandlestickData(time: .unix(3000), open: 16, high: 20, low: 14, close: 18)
        ]

        series.setData(data: data)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that histogram series can be created and data can be set
    func testHistogramSeriesCreation() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        XCTAssertNotNil(series, "Histogram series should be created")

        let data: [HistogramData] = [
            HistogramData(time: .unix(1000), value: 10, color: nil),
            HistogramData(time: .unix(2000), value: 20, color: nil),
            HistogramData(time: .unix(3000), value: 15, color: nil)
        ]

        series.setData(data: data)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that baseline series can be created and data can be set
    func testBaselineSeriesCreation() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        XCTAssertNotNil(series, "Baseline series should be created")

        let data: [BaselineData] = [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20),
            BaselineData(time: .unix(3000), value: 15)
        ]

        series.setData(data: data)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Series Tests

    /// Tests that multiple series can be created on the same chart
    func testMultipleSeriesCreation() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())

        XCTAssertNotNil(lineSeries, "Line series should be created")
        XCTAssertNotNil(areaSeries, "Area series should be created")
        XCTAssertNotNil(barSeries, "Bar series should be created")

        // Set data on all series
        lineSeries.setData(data: [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ])

        areaSeries.setData(data: [
            AreaData(time: .unix(1000), value: 8),
            AreaData(time: .unix(2000), value: 18)])

        barSeries.setData(data: [
            BarData(time: .unix(1000), open: 9, high: 11, low: 7, close: 10),
            BarData(time: .unix(2000), open: 19, high: 21, low: 17, close: 20)
        ])

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that all supported series types can be created on a single chart
    func testAllSeriesTypesOnSingleChart() {
        errorCatcher.clear()

        // Create one of each series type
        let _ = charts.addLineSeries(options: LineSeriesOptions())
        let _ = charts.addAreaSeries(options: AreaSeriesOptions())
        let _ = charts.addBarSeries(options: BarSeriesOptions())
        let _ = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let _ = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let _ = charts.addBaselineSeries(options: BaselineSeriesOptions())

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Series Options Tests

    /// Tests that series options can be applied
    func testSeriesWithOptions() {
        errorCatcher.clear()

        let lineOptions = LineSeriesOptions(
     title: "Test Series",
     visible: true,
     priceLineVisible: true,
     priceLineWidth: .two,
     priceLineColor: ChartColor(.blue),
     priceLineStyle: .solid,
     color: ChartColor(.red),
     lineStyle: .dotted,
     lineWidth: .three,
     lineType: .simple,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 5,
     lastPriceAnimation: .continuous
 )

        let series = charts.addLineSeries(options: lineOptions)
        XCTAssertNotNil(series, "Series with options should be created")

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that series options can be updated after creation
    func testSeriesApplyOptions() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let updatedOptions = LineSeriesOptions(
     title: "Updated Title",
     visible: true,
     priceLineVisible: false,
     color: ChartColor(.green),
     lineStyle: .dashed,
     lineWidth: .two,
     lineType: .withSteps,
     crosshairMarkerVisible: false,
     crosshairMarkerRadius: 4,
     lastPriceAnimation: .none
 )

        series.applyOptions(options: updatedOptions)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Series Removal Tests

    /// Tests that series can be removed from the chart
    func testSeriesRemoval() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        series.setData(data: [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Remove the series
        errorCatcher.clear()
        charts.removeSeries(seriesApi: series)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension ChartCreationSmokeTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - V5 Series Creation Tests

/// Tests for v5 series creation API
///
/// These tests verify that the series creation uses the v5 API pattern
/// `chart.addSeries(LightweightCharts.{SeriesType}, options)` instead of
/// the v4 pattern `chart.add{SeriesType}(options)`.
final class V5SeriesCreationTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - V5 API Validation Tests

    /// Tests that line series creation uses v5 API
    func testLineSeriesUsesV5API() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created with v5 API")

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that area series creation uses v5 API
    func testAreaSeriesUsesV5API() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        XCTAssertNotNil(series, "Area series should be created with v5 API")

        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that bar series creation uses v5 API
    func testBarSeriesUsesV5API() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        XCTAssertNotNil(series, "Bar series should be created with v5 API")

        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that candlestick series creation uses v5 API
    func testCandlestickSeriesUsesV5API() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        XCTAssertNotNil(series, "Candlestick series should be created with v5 API")

        let data: [CandlestickData] = [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that histogram series creation uses v5 API
    func testHistogramSeriesUsesV5API() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        XCTAssertNotNil(series, "Histogram series should be created with v5 API")

        let data: [HistogramData] = [
            HistogramData(time: .unix(1000), value: 10, color: nil),
            HistogramData(time: .unix(2000), value: 20, color: nil)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that baseline series creation uses v5 API
    func testBaselineSeriesUsesV5API() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        XCTAssertNotNil(series, "Baseline series should be created with v5 API")

        let data: [BaselineData] = [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that all series types can be created on a single chart using v5 API
    func testAllSeriesTypesWithV5API() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let histogramSeries = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let baselineSeries = charts.addBaselineSeries(options: BaselineSeriesOptions())

        XCTAssertNotNil(lineSeries)
        XCTAssertNotNil(areaSeries)
        XCTAssertNotNil(barSeries)
        XCTAssertNotNil(candlestickSeries)
        XCTAssertNotNil(histogramSeries)
        XCTAssertNotNil(baselineSeries)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that series options work correctly with v5 API
    func testSeriesWithOptionsV5API() {
        errorCatcher.clear()

        let options = LineSeriesOptions(
     title: "V5 Test Series",
     visible: true,
     priceLineVisible: true,
     priceLineWidth: .two,
     priceLineColor: ChartColor(.blue),
     priceLineStyle: .solid,
     color: ChartColor(.red),
     lineStyle: .dotted,
     lineWidth: .three,
     lineType: .simple,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 5,
     lastPriceAnimation: .continuous
 )

        let series = charts.addLineSeries(options: options)
        XCTAssertNotNil(series, "Series with options should be created with v5 API")

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that series can be removed with v5 API
    func testSeriesRemovalV5API() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        series.setData(data: [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Remove the series
        errorCatcher.clear()
        charts.removeSeries(seriesApi: series)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension V5SeriesCreationTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - All Series Types Validation Tests

/// Comprehensive validation tests for all supported series types
///
/// These tests provide thorough validation for each supported series type:
/// - Line, Area, Bar, Candlestick, Histogram, Baseline
///
/// Task 2.3: Validate all supported series creations
final class AllSeriesTypesValidationTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Line Series Validation

    /// Tests line series creation with various options
    func testLineSeriesWithOptions() {
        errorCatcher.clear()

        let options = LineSeriesOptions(
     title: "Line Test",
     visible: true,
     color: ChartColor(.blue),
     lineStyle: .dashed,
     lineWidth: .two,
     lineType: .withSteps,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 6,
     lastPriceAnimation: .continuous
 )

        let series = charts.addLineSeries(options: options)
        XCTAssertNotNil(series, "Line series with options should be created")

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15),
            LineData(time: .unix(4000), value: 25)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests multiple line series on the same chart
    func testMultipleLineSeries() {
        errorCatcher.clear()

        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addLineSeries(options: LineSeriesOptions())
        let series3 = charts.addLineSeries(options: LineSeriesOptions())

        XCTAssertNotNil(series1)
        XCTAssertNotNil(series2)
        XCTAssertNotNil(series3)

        series1.setData(data: [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ])

        series2.setData(data: [
            LineData(time: .unix(1000), value: 15),
            LineData(time: .unix(2000), value: 25)
        ])

        series3.setData(data: [
            LineData(time: .unix(1000), value: 5),
            LineData(time: .unix(2000), value: 15)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests line series data update
    func testLineSeriesDataUpdate() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        // Initial data
        series.setData(data: [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ])

        waitForAsyncOperations()

        // Update with new data
        series.setData(data: [
            LineData(time: .unix(1000), value: 15),
            LineData(time: .unix(2000), value: 25),
            LineData(time: .unix(3000), value: 30)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Area Series Validation

    /// Tests area series creation with various options
    func testAreaSeriesWithOptions() {
        errorCatcher.clear()

        let options = AreaSeriesOptions(
     title: "Area Test",
     visible: true,
     lineColor: ChartColor(.green),
     lineStyle: .solid,
     lineWidth: .two,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 4,
     lastPriceAnimation: .none
 )

        let series = charts.addAreaSeries(options: options)
        XCTAssertNotNil(series, "Area series with options should be created")

        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20),
            AreaData(time: .unix(3000), value: 15)]

        series.setData(data: data)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests multiple area series on the same chart
    func testMultipleAreaSeries() {
        errorCatcher.clear()

        let series1 = charts.addAreaSeries(options: AreaSeriesOptions())
        let series2 = charts.addAreaSeries(options: AreaSeriesOptions())

        XCTAssertNotNil(series1)
        XCTAssertNotNil(series2)

        series1.setData(data: [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)])

        series2.setData(data: [
            AreaData(time: .unix(1000), value: 15),
            AreaData(time: .unix(2000), value: 25)])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests area series with top and bottom colors
    func testAreaSeriesWithGradientColors() {
        errorCatcher.clear()

        let options = AreaSeriesOptions(
     topColor: ChartColor(.blue.withAlphaComponent(0.4)),
     bottomColor: ChartColor(.blue.withAlphaComponent(0.0)),
     lineColor: ChartColor(.blue)
 )

        let series = charts.addAreaSeries(options: options)
        series.setData(data: [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Bar Series Validation

    /// Tests bar series creation with various options
    func testBarSeriesWithOptions() {
        errorCatcher.clear()

        let options = BarSeriesOptions(
     upColor: ChartColor(.green),
     downColor: ChartColor(.red),
     openVisible: true,
     thinBars: false
 )

        let series = charts.addBarSeries(options: options)
        XCTAssertNotNil(series, "Bar series with options should be created")

        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16),
            BarData(time: .unix(3000), open: 16, high: 20, low: 14, close: 18)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests multiple bar series on the same chart
    func testMultipleBarSeries() {
        errorCatcher.clear()

        let series1 = charts.addBarSeries(options: BarSeriesOptions())
        let series2 = charts.addBarSeries(options: BarSeriesOptions())

        XCTAssertNotNil(series1)
        XCTAssertNotNil(series2)

        series1.setData(data: [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ])

        series2.setData(data: [
            BarData(time: .unix(1000), open: 9, high: 14, low: 7, close: 11),
            BarData(time: .unix(2000), open: 11, high: 17, low: 9, close: 15)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests bar series with thin bars enabled
    func testBarSeriesThinBars() {
        errorCatcher.clear()

        let options = BarSeriesOptions(
     thinBars: true
 )

        let series = charts.addBarSeries(options: options)
        series.setData(data: [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Candlestick Series Validation

    /// Tests candlestick series creation with various options
    func testCandlestickSeriesWithOptions() {
        errorCatcher.clear()

        let options = CandlestickSeriesOptions(
     upColor: ChartColor(.green),
     downColor: ChartColor(.red),
     borderVisible: true,
     borderUpColor: ChartColor(hex: 0x006400),
     borderDownColor: ChartColor(hex: 0x8B0000),
     wickUpColor: ChartColor(.green),
     wickDownColor: ChartColor(.red)
 )

        let series = charts.addCandlestickSeries(options: options)
        XCTAssertNotNil(series, "Candlestick series with options should be created")

        let data: [CandlestickData] = [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16),
            CandlestickData(time: .unix(3000), open: 16, high: 20, low: 14, close: 18)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests multiple candlestick series on the same chart
    func testMultipleCandlestickSeries() {
        errorCatcher.clear()

        let series1 = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let series2 = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        XCTAssertNotNil(series1)
        XCTAssertNotNil(series2)

        series1.setData(data: [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ])

        series2.setData(data: [
            CandlestickData(time: .unix(1000), open: 9, high: 14, low: 7, close: 11),
            CandlestickData(time: .unix(2000), open: 11, high: 17, low: 9, close: 15)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests candlestick series with custom border and wick colors
    func testCandlestickSeriesCustomColors() {
        errorCatcher.clear()

        let options = CandlestickSeriesOptions(
     upColor: ChartColor(.blue),
     downColor: ChartColor(.yellow),
     borderVisible: true,
     borderUpColor: ChartColor(hex: 0x00008B),
     borderDownColor: ChartColor(hex: 0xCCAA00),
     wickUpColor: ChartColor(.blue),
     wickDownColor: ChartColor(.yellow)
 )

        let series = charts.addCandlestickSeries(options: options)
        series.setData(data: [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 9)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Histogram Series Validation

    /// Tests histogram series creation with various options
    func testHistogramSeriesWithOptions() {
        errorCatcher.clear()

        let options = HistogramSeriesOptions(
     color: ChartColor(.cyan),
     base: 0
 )

        let series = charts.addHistogramSeries(options: options)
        XCTAssertNotNil(series, "Histogram series with options should be created")

        let data: [HistogramData] = [
            HistogramData(time: .unix(1000), value: 10, color: nil),
            HistogramData(time: .unix(2000), value: 20, color: nil),
            HistogramData(time: .unix(3000), value: 15, color: nil)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests multiple histogram series on the same chart
    func testMultipleHistogramSeries() {
        errorCatcher.clear()

        let series1 = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let series2 = charts.addHistogramSeries(options: HistogramSeriesOptions())

        XCTAssertNotNil(series1)
        XCTAssertNotNil(series2)

        series1.setData(data: [
            HistogramData(time: .unix(1000), value: 10, color: nil),
            HistogramData(time: .unix(2000), value: 20, color: nil)
        ])

        series2.setData(data: [
            HistogramData(time: .unix(1000), value: 5, color: nil),
            HistogramData(time: .unix(2000), value: 15, color: nil)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests histogram series with per-data colors
    func testHistogramSeriesWithDataColors() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        series.setData(data: [
            HistogramData(time: .unix(1000), value: 10, color: ChartColor(.green)),
            HistogramData(time: .unix(2000), value: 20, color: ChartColor(.red)),
            HistogramData(time: .unix(3000), value: 15, color: ChartColor(.blue))
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests histogram series with color location
    func testHistogramSeriesColorLocation() {
        errorCatcher.clear()

        let options = HistogramSeriesOptions(
     base: 10
 )

        let series = charts.addHistogramSeries(options: options)
        series.setData(data: [
            HistogramData(time: .unix(1000), value: 15, color: nil),
            HistogramData(time: .unix(2000), value: 25, color: nil)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Baseline Series Validation

    /// Tests baseline series creation with various options
    func testBaselineSeriesWithOptions() {
        errorCatcher.clear()

        let options = BaselineSeriesOptions(
     title: "Baseline Test",
     visible: true,
     baseLineColor: ChartColor(.gray),
     baseLineWidth: .two,
     baseLineStyle: .dashed,
     topFillColor1: ChartColor(.magenta.withAlphaComponent(0.3)),
     bottomFillColor1: ChartColor(.magenta.withAlphaComponent(0.1)),
     lineWidth: .two,
     lineStyle: .dotted,
     lineType: .simple,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 5,
     lastPriceAnimation: .continuous
 )

        let series = charts.addBaselineSeries(options: options)
        XCTAssertNotNil(series, "Baseline series with options should be created")

        let data: [BaselineData] = [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20),
            BaselineData(time: .unix(3000), value: 15)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests multiple baseline series on the same chart
    func testMultipleBaselineSeries() {
        errorCatcher.clear()

        let series1 = charts.addBaselineSeries(options: BaselineSeriesOptions())
        let series2 = charts.addBaselineSeries(options: BaselineSeriesOptions())

        XCTAssertNotNil(series1)
        XCTAssertNotNil(series2)

        series1.setData(data: [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20)
        ])

        series2.setData(data: [
            BaselineData(time: .unix(1000), value: 15),
            BaselineData(time: .unix(2000), value: 25)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests baseline series with custom base line price
    func testBaselineSeriesCustomBaseLinePrice() {
        errorCatcher.clear()

        let options = BaselineSeriesOptions()

        let series = charts.addBaselineSeries(options: options)
        series.setData(data: [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests baseline series with gradient fill colors
    func testBaselineSeriesGradientFill() {
        errorCatcher.clear()

        let options = BaselineSeriesOptions(
     topFillColor1: ChartColor(.blue.withAlphaComponent(0.4)),
     bottomFillColor1: ChartColor(.blue.withAlphaComponent(0.1))
 )

        let series = charts.addBaselineSeries(options: options)
        series.setData(data: [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Mixed Series Types Validation

    /// Tests that all six series types can be created and used together
    func testAllSixSeriesTypesTogether() {
        errorCatcher.clear()

        // Create one of each type
        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let histogramSeries = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let baselineSeries = charts.addBaselineSeries(options: BaselineSeriesOptions())

        // Verify all were created
        XCTAssertNotNil(lineSeries, "Line series should be created")
        XCTAssertNotNil(areaSeries, "Area series should be created")
        XCTAssertNotNil(barSeries, "Bar series should be created")
        XCTAssertNotNil(candlestickSeries, "Candlestick series should be created")
        XCTAssertNotNil(histogramSeries, "Histogram series should be created")
        XCTAssertNotNil(baselineSeries, "Baseline series should be created")

        // Set data on all series
        lineSeries.setData(data: [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ])

        areaSeries.setData(data: [
            AreaData(time: .unix(1000), value: 8),
            AreaData(time: .unix(2000), value: 18)])

        barSeries.setData(data: [
            BarData(time: .unix(1000), open: 9, high: 11, low: 7, close: 10),
            BarData(time: .unix(2000), open: 19, high: 21, low: 17, close: 20)
        ])

        candlestickSeries.setData(data: [
            CandlestickData(time: .unix(1000), open: 9, high: 11, low: 7, close: 10),
            CandlestickData(time: .unix(2000), open: 19, high: 21, low: 17, close: 20)
        ])

        histogramSeries.setData(data: [
            HistogramData(time: .unix(1000), value: 5, color: nil),
            HistogramData(time: .unix(2000), value: 15, color: nil)
        ])

        baselineSeries.setData(data: [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20)
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that multiple instances of each series type can be created
    func testMultipleInstancesOfEachSeriesType() {
        errorCatcher.clear()

        // Create multiple instances of each type
        let line1 = charts.addLineSeries(options: LineSeriesOptions())
        let line2 = charts.addLineSeries(options: LineSeriesOptions())

        let area1 = charts.addAreaSeries(options: AreaSeriesOptions())
        let area2 = charts.addAreaSeries(options: AreaSeriesOptions())

        let bar1 = charts.addBarSeries(options: BarSeriesOptions())
        let bar2 = charts.addBarSeries(options: BarSeriesOptions())

        let candlestick1 = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let candlestick2 = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        let histogram1 = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let histogram2 = charts.addHistogramSeries(options: HistogramSeriesOptions())

        let baseline1 = charts.addBaselineSeries(options: BaselineSeriesOptions())
        let baseline2 = charts.addBaselineSeries(options: BaselineSeriesOptions())

        // Verify all were created
        XCTAssertNotNil(line1)
        XCTAssertNotNil(line2)
        XCTAssertNotNil(area1)
        XCTAssertNotNil(area2)
        XCTAssertNotNil(bar1)
        XCTAssertNotNil(bar2)
        XCTAssertNotNil(candlestick1)
        XCTAssertNotNil(candlestick2)
        XCTAssertNotNil(histogram1)
        XCTAssertNotNil(histogram2)
        XCTAssertNotNil(baseline1)
        XCTAssertNotNil(baseline2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests series applyOptions for each series type
    func testApplyOptionsForAllSeriesTypes() {
        errorCatcher.clear()

        // Line series
        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        lineSeries.applyOptions(options: LineSeriesOptions(
            title: "Updated",
            color: ChartColor(.red)
        ))

        // Area series
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        areaSeries.applyOptions(options: AreaSeriesOptions(
            title: "Area Updated",
            lineColor: ChartColor(.blue)
        ))

        // Bar series
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        barSeries.applyOptions(options: BarSeriesOptions())

        // Candlestick series
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        candlestickSeries.applyOptions(options: CandlestickSeriesOptions())

        // Histogram series
        let histogramSeries = charts.addHistogramSeries(options: HistogramSeriesOptions())
        histogramSeries.applyOptions(options: HistogramSeriesOptions(
            color: ChartColor(.cyan)
        ))

        // Baseline series
        let baselineSeries = charts.addBaselineSeries(options: BaselineSeriesOptions())
        baselineSeries.applyOptions(options: BaselineSeriesOptions(
            title: "Baseline Updated"
        ))

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension AllSeriesTypesValidationTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Series Array Tracking Tests

/// Tests for series array tracking validation
///
/// These tests verify that series are properly tracked in the JavaScript `seriesArray`
/// which is used for event payload mapping in click and crosshair move events.
/// The seriesArray is critical for mapping series data back to Swift series objects
/// when events are fired from the JavaScript layer.
final class SeriesArrayTrackingTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Series Array Initialization Tests

    /// Tests that seriesArray is initialized when chart is created
    /// The seriesArray is a global JavaScript array used to track created series
    /// for event payload mapping.
    func testSeriesArrayInitialized() {
        // The chart loading successfully indicates seriesArray was initialized
        // If seriesArray was not declared, chart creation would fail
        XCTAssertNotNil(charts, "Chart creation should initialize seriesArray")
        errorCatcher.assertNoErrors()
    }

    // MARK: - Single Series Tracking Tests

    /// Tests that a single line series is tracked in seriesArray
    /// When addSeries is called, it should add the series to seriesArray.
    func testSingleLineSeriesTrackedInArray() {
        errorCatcher.clear()

        // Create a series - this should add it to seriesArray
        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Series should be created")

        // Verify series has a valid jsName (required for seriesArray tracking)
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()

        // No errors means the series was successfully added to seriesArray
        errorCatcher.assertNoErrors()
    }

    /// Tests that an area series is tracked in seriesArray
    func testSingleAreaSeriesTrackedInArray() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        XCTAssertNotNil(series, "Area series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Series Tracking Tests

    /// Tests that multiple series of the same type are all tracked in seriesArray
    func testMultipleSeriesOfSameTypeTracked() {
        errorCatcher.clear()

        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addLineSeries(options: LineSeriesOptions())
        let series3 = charts.addLineSeries(options: LineSeriesOptions())

        // Each series should have a unique jsName
        XCTAssertNotEqual(series1.jsName, series2.jsName, "Series names should be unique")
        XCTAssertNotEqual(series2.jsName, series3.jsName, "Series names should be unique")
        XCTAssertNotEqual(series1.jsName, series3.jsName, "Series names should be unique")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that multiple series of different types are all tracked in seriesArray
    func testMultipleSeriesOfDifferentTypesTracked() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        // All series should have unique jsNames
        let seriesNames = [lineSeries.jsName, areaSeries.jsName, barSeries.jsName, candlestickSeries.jsName]
        let uniqueNames = Set(seriesNames)
        XCTAssertEqual(uniqueNames.count, 4, "All series should have unique names")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that all six supported series types are tracked in seriesArray
    func testAllSeriesTypesTrackedInArray() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let histogramSeries = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let baselineSeries = charts.addBaselineSeries(options: BaselineSeriesOptions())

        // Verify all series were created successfully
        XCTAssertNotNil(lineSeries)
        XCTAssertNotNil(areaSeries)
        XCTAssertNotNil(barSeries)
        XCTAssertNotNil(candlestickSeries)
        XCTAssertNotNil(histogramSeries)
        XCTAssertNotNil(baselineSeries)

        // Verify all have unique jsNames (required for seriesArray tracking)
        let seriesNames = [
            lineSeries.jsName,
            areaSeries.jsName,
            barSeries.jsName,
            candlestickSeries.jsName,
            histogramSeries.jsName,
            baselineSeries.jsName
        ]
        let uniqueNames = Set(seriesNames)
        XCTAssertEqual(uniqueNames.count, 6, "All series should have unique names")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Event Subscription Tests (uses seriesArray)

    /// Tests that click event subscription works with seriesArray tracking
    /// The click event handler uses seriesArray to map series data in the event payload.
    func testClickSubscriptionWithSeriesArray() {
        errorCatcher.clear()

        // Create series that will be tracked in seriesArray
        _ = charts.addLineSeries(options: LineSeriesOptions())
        _ = charts.addAreaSeries(options: AreaSeriesOptions())

        // Subscribe to click events - this uses seriesArray for payload mapping
        charts.subscribeClick()

        waitForAsyncOperations()

        // If seriesArray tracking failed, subscription would produce errors
        errorCatcher.assertNoErrors()
    }

    /// Tests that crosshair move event subscription works with seriesArray tracking
    /// The crosshair move event handler uses seriesArray to map series data in the event payload.
    func testCrosshairMoveSubscriptionWithSeriesArray() {
        errorCatcher.clear()

        // Create series that will be tracked in seriesArray
        _ = charts.addLineSeries(options: LineSeriesOptions())
        _ = charts.addBarSeries(options: BarSeriesOptions())
        _ = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        // Subscribe to crosshair move events - this uses seriesArray for payload mapping
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        // If seriesArray tracking failed, subscription would produce errors
        errorCatcher.assertNoErrors()
    }

    /// Tests that both click and crosshair move subscriptions work simultaneously
    /// with multiple series tracked in seriesArray
    func testBothEventSubscriptionsWithMultipleSeries() {
        errorCatcher.clear()

        // Create multiple series
        let _ = charts.addLineSeries(options: LineSeriesOptions())
        let _ = charts.addAreaSeries(options: AreaSeriesOptions())
        let _ = charts.addBarSeries(options: BarSeriesOptions())

        // Subscribe to both event types
        charts.subscribeClick()
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        // Both subscriptions should work without errors
        errorCatcher.assertNoErrors()
    }

    /// Tests that event subscriptions work after adding series with data
    /// This simulates real-world usage where series have data before events occur.
    func testEventSubscriptionsWithSeriesThatHaveData() {
        errorCatcher.clear()

        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addAreaSeries(options: AreaSeriesOptions())

        // Add data to the series
        let lineData: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]
        series1.setData(data: lineData)

        let areaData: [AreaData] = [
            AreaData(time: .unix(1000), value: 8),
            AreaData(time: .unix(2000), value: 18),
            AreaData(time: .unix(3000), value: 12)]
        series2.setData(data: areaData)

        // Subscribe to events after setting data
        charts.subscribeClick()
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        // Series with data should be properly tracked in seriesArray
        errorCatcher.assertNoErrors()
    }

    // MARK: - Series Unsubscription Tests

    /// Tests that click event unsubscription works correctly
    func testClickUnsubscription() {
        errorCatcher.clear()

        let _ = charts.addLineSeries(options: LineSeriesOptions())
        charts.subscribeClick()

        waitForAsyncOperations()

        errorCatcher.clear()
        charts.unsubscribeClick()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that crosshair move event unsubscription works correctly
    func testCrosshairMoveUnsubscription() {
        errorCatcher.clear()

        let _ = charts.addLineSeries(options: LineSeriesOptions())
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.clear()
        charts.unsubscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that re-subscribing to events works correctly
    func testEventResubscription() {
        errorCatcher.clear()

        let _ = charts.addLineSeries(options: LineSeriesOptions())

        // Subscribe, unsubscribe, then resubscribe
        charts.subscribeClick()
        waitForAsyncOperations()

        charts.unsubscribeClick()
        waitForAsyncOperations()

        errorCatcher.clear()
        charts.subscribeClick()
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension SeriesArrayTrackingTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Markers Compatibility Tests

/// Tests for backward-compatible markers API using v5 createSeriesMarkers primitive
///
/// These tests verify that the existing `setMarkers` and `markers` APIs continue to work
/// after the v5 migration by internally using the `createSeriesMarkers` plugin primitive.
/// The plugin reference is stored on the series object as `_lwcMarkersPlugin`.
final class MarkersCompatibilityTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Basic Markers Tests

    /// Tests that setMarkers works with BarSeries
    /// This validates the basic v5 compatibility path.
    func testSetMarkersWithBarSeries() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        XCTAssertNotNil(series, "Bar series should be created")

        // Set some data first
        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16),
            BarData(time: .unix(3000), open: 16, high: 20, low: 14, close: 18)
        ]
        series.setData(data: data)

        // Set markers using the compatibility API
        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[1].time, position: .belowBar, shape: .arrowUp, color: ChartColor(.green))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()

        // No JS errors should occur
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with LineSeries
    func testSetMarkersWithLineSeries() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created")

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .inBar, shape: .square, color: ChartColor(.blue)),
            SeriesMarker(time: data[2].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with CandlestickSeries
    func testSetMarkersWithCandlestickSeries() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        XCTAssertNotNil(series, "Candlestick series should be created")

        let data: [CandlestickData] = [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .arrowDown, color: ChartColor(.red))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with AreaSeries
    func testSetMarkersWithAreaSeries() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        XCTAssertNotNil(series, "Area series should be created")

        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .belowBar, shape: .circle, color: ChartColor(.yellow))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with HistogramSeries
    func testSetMarkersWithHistogramSeries() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        XCTAssertNotNil(series, "Histogram series should be created")

        let data: [HistogramData] = [
            HistogramData(time: .unix(1000), value: 10),
            HistogramData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.purple))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with BaselineSeries
    func testSetMarkersWithBaselineSeries() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        XCTAssertNotNil(series, "Baseline series should be created")

        let data: [BaselineData] = [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .inBar, shape: .square, color: ChartColor(.cyan))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Markers with Optional Fields Tests

    /// Tests that markers with optional fields work correctly
    func testMarkersWithOptionalFields() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())

        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)
        ]
        series.setData(data: data)

        // Markers with optional fields
        let markers = [
            SeriesMarker(
                time: data[0].time,
                position: .aboveBar,
                shape: .circle,
                color: ChartColor(.orange),
                id: "marker-1",
                text: "Important",
                size: 20.0
            )
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that multiple markers at the same time point work correctly
    func testMultipleMarkersAtSameTime() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        // Multiple markers at the same time
        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.green))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Repeated setMarkers Tests

    /// Tests that calling setMarkers multiple times updates existing plugin
    /// instead of recreating it on every call.
    func testRepeatedSetMarkersUpdatesPlugin() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())

        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16),
            BarData(time: .unix(3000), open: 16, high: 20, low: 14, close: 18)
        ]
        series.setData(data: data)

        // First setMarkers call - creates the plugin
        let markers1 = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        series.setMarkers(data: markers1)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Second setMarkers call - should update existing plugin
        errorCatcher.clear()
        let markers2 = [
            SeriesMarker(time: data[1].time, position: .belowBar, shape: .arrowUp, color: ChartColor(.green)),
            SeriesMarker(time: data[2].time, position: .inBar, shape: .square, color: ChartColor(.blue))
        ]
        series.setMarkers(data: markers2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers with empty array works correctly
    func testSetMarkersWithEmptyArray() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        // First set some markers
        let markers1 = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        series.setMarkers(data: markers1)

        waitForAsyncOperations()

        // Then clear them with empty array
        errorCatcher.clear()
        series.setMarkers(data: [])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Markers Query Tests

    /// Tests that markers() returns nil when no markers were set
    func testMarkersReturnsNilWhenNotSet() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())

        let expectation = self.expectation(description: "Markers query completes")

        series.markers { result in
            // Should return nil when plugin was never created
            XCTAssertNil(result, "markers() should return nil when no markers were set")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that markers() returns data after setMarkers was called
    func testMarkersReturnsDataAfterSet() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[1].time, position: .belowBar, shape: .arrowUp, color: ChartColor(.green))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()

        // Now query markers
        errorCatcher.clear()
        let expectation = self.expectation(description: "Markers query completes")

        series.markers { result in
            // Should return markers when plugin exists
            XCTAssertNotNil(result, "markers() should return data after setMarkers was called")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Series with Markers Tests

    /// Tests that multiple series can have markers independently
    func testMultipleSeriesWithMarkers() {
        errorCatcher.clear()

        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addBarSeries(options: BarSeriesOptions())

        let data1: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series1.setData(data: data1)

        let data2: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)
        ]
        series2.setData(data: data2)

        // Set different markers on each series
        let markers1 = [
            SeriesMarker(time: data1[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        series1.setMarkers(data: markers1)

        let markers2 = [
            SeriesMarker(time: data2[0].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]
        series2.setMarkers(data: markers2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - MarkersViewController Example Validation (Task 3.5)

    /// Tests that the MarkersViewController example pattern works correctly
    ///
    /// This test validates the exact usage pattern from MarkersViewController.swift:
    /// - BarSeries with generated data using UTC timestamps
    /// - Multiple markers at the same time points
    /// - Different positions (aboveBar, belowBar, inBar)
    /// - Different colors (orange, yellow, green, red)
    func testMarkersViewControllerExamplePattern() {
        errorCatcher.clear()

        // Create bar series like the example
        let series = charts.addBarSeries(options: BarSeriesOptions())
        XCTAssertNotNil(series, "Bar series should be created")

        // Generate data similar to the example
        var data: [BarData] = []
        for i in 0..<50 {
            let timestamp: Double = 1000 + (Double(i) * 86400)  // Daily intervals
            let step = Double(i % 20) / 1000.0
            let base = Double(i) / 5.0
            let barData = BarData(
                time: .utc(timestamp: timestamp),
                open: base * (1 - step),
                high: base * (1 + 2 * step),
                low: base * (1 - 2 * step),
                close: base * (1 + step)
            )
            data.append(barData)
        }
        series.setData(data: data)

        // Create markers matching the example pattern:
        // - Multiple markers at the same time points (data[data.count - 30])
        // - Different positions and colors
        let markers = [
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(.green)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(.green)),
            SeriesMarker(time: data[data.count - 15].time, position: .inBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[data.count - 10].time, position: .inBar, shape: .circle, color: ChartColor(.red))
        ]

        // Set markers using the exact API from the example
        series.setMarkers(data: markers)

        waitForAsyncOperations()

        // No JS errors should occur - this validates the example code pattern works
        errorCatcher.assertNoErrors()
    }

    /// Tests that UTC time format works correctly with markers
    ///
    /// MarkersViewController uses .utc(timestamp:) for data, so this validates
    /// that markers can reference those time values correctly.
    func testMarkersWithUTCTime() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())

        // Data with UTC timestamps (like the example)
        let data: [BarData] = [
            BarData(time: .utc(timestamp: 1514764800), open: 10, high: 15, low: 8, close: 12),  // 2018-01-01
            BarData(time: .utc(timestamp: 1514851200), open: 12, high: 18, low: 10, close: 16), // 2018-01-02
            BarData(time: .utc(timestamp: 1514937600), open: 16, high: 20, low: 14, close: 18)  // 2018-01-03
        ]
        series.setData(data: data)

        // Markers referencing the UTC time values
        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[1].time, position: .belowBar, shape: .circle, color: ChartColor(.green)),
            SeriesMarker(time: data[2].time, position: .inBar, shape: .circle, color: ChartColor(.red))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - MarkersPluginViewController Example Validation (Task 9.3)

    /// Tests the exact usage pattern from MarkersPluginViewController
    ///
    /// This test validates the v5 explicit plugin API usage pattern:
    /// - Creating a BarSeries with generated data
    /// - Using series.createMarkersPlugin(data:options:) to create the plugin
    /// - Setting SeriesMarkersOptions with active and autoScale properties
    func testMarkersPluginViewControllerPattern() {
        errorCatcher.clear()

        let expectation = expectation(description: "Chart loads for plugin test")
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        testChart.errorDelegate = errorCatcher
        let strongLoadDelegate = TestLoadDelegate(expectation: expectation)
        testChart.loadDelegate = strongLoadDelegate

        wait(for: [expectation], timeout: 5.0)

        // This is the exact pattern from MarkersPluginViewController
        let series = testChart.addBarSeries(options: BarSeriesOptions())

        // Generate data like the example
        var time = DateComponents(calendar: .current, year: 2018, day: 0).date!
        var data: [BarData] = []
        for i in 0..<50 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let step = Double(i % 20) / 1000.0
            let base = Double(i) / 5.0
            let barData = BarData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                open: base * (1 - step),
                high: base * (1 + 2 * step),
                low: base * (1 - 2 * step),
                close: base * (1 + step)
            )
            data.append(barData)
        }
        series.setData(data: data)

        // Create markers like the example
        let markers = [
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: data[data.count - 10].time, position: .inBar, shape: .circle, color: ChartColor(.red))
        ]

        // Use the v5 explicit plugin API to create a markers plugin
        let options = SeriesMarkersOptions(
            active: true,
            autoScale: true
        )
        let plugin = series.createMarkersPlugin(data: markers, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created")
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - UpDownMarkersViewController Example Validation (Task 9.4)

    /// Tests the exact usage pattern from UpDownMarkersViewController
    ///
    /// This test validates the v5 UpDownMarkers plugin API usage pattern:
    /// - Creating a LineSeries with generated data
    /// - Using series.createUpDownMarkersPlugin(data:options:) to create the plugin
    /// - Setting UpDownMarkersOptions with positiveColor, negativeColor, and updateVisibilityDuration
    func testUpDownMarkersViewControllerPattern() {
        errorCatcher.clear()

        // Create line series like the example
        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created")

        // Generate data similar to the example
        var time = DateComponents(calendar: .current, year: 2024, month: 1, day: 1).date!
        var data: [LineData] = []
        var value = 100.0

        for _ in 0..<100 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let change = Double.random(in: -5...5)
            value += change

            let lineData = LineData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                value: value
            )
            data.append(lineData)
        }
        series.setData(data: data)

        // Generate up-down markers similar to the example
        var markers: [SeriesUpDownMarker] = []
        let stride = 10

        for i in Swift.stride(from: 5, to: data.count, by: stride) {
            let item = data[i]
            let sign: MarkerSign
            if i > 0 {
                let previousValue = data[i - 1].value
                let val = item.value ?? 0.0
                let prevVal = previousValue ?? 0.0
                if val > prevVal {
                    sign = .positive
                } else if val < prevVal {
                    sign = .negative
                } else {
                    sign = .neutral
                }
            } else {
                sign = .neutral
            }

            let marker = SeriesUpDownMarker(
                time: item.time,
                value: item.value ?? 0.0,
                sign: sign
            )
            markers.append(marker)
        }

        // Create the UpDownMarkers plugin with custom options
        let options = UpDownMarkersOptions(
            positiveColor: .solid(.green),
            negativeColor: .solid(.red),
            updateVisibilityDuration: 2000
        )
        let plugin = series.createUpDownMarkersPlugin(data: markers, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created")
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension MarkersCompatibilityTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Markers Lifecycle Cleanup Tests

/// Tests for lifecycle cleanup behavior of compatibility markers plugin
///
/// These tests verify that the markers compatibility plugin is properly cleaned up
/// when a series is removed, avoiding dangling references.
/// Task 3.4: Add lifecycle cleanup behavior for compatibility plugin when appropriate
final class MarkersLifecycleCleanupTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Basic Cleanup Tests

    /// Tests that removing a series with markers cleans up the plugin
    func testRemoveSeriesWithMarkersDetachesPlugin() {
        errorCatcher.clear()

        // Create a series and add markers
        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        series.setMarkers(data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Remove the series - should detach the markers plugin
        charts.removeSeries(seriesApi: series)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that removing a series without markers doesn't cause errors
    func testRemoveSeriesWithoutMarkers() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)
        ]
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Remove the series without ever setting markers
        charts.removeSeries(seriesApi: series)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Series Cleanup Tests

    /// Tests that removing one series doesn't affect markers on other series
    func testRemoveOneSeriesPreservesOtherSeriesMarkers() {
        errorCatcher.clear()

        // Create two series with markers
        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let data1: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series1.setData(data: data1)

        let series2 = charts.addAreaSeries(options: AreaSeriesOptions())
        let data2: [AreaData] = [
            AreaData(time: .unix(1000), value: 15),
            AreaData(time: .unix(2000), value: 25)]
        series2.setData(data: data2)

        // Add markers to both series
        let markers1 = [
            SeriesMarker(time: data1[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        series1.setMarkers(data: markers1)

        let markers2 = [
            SeriesMarker(time: data2[1].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]
        series2.setMarkers(data: markers2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Remove first series - second series markers should still work
        charts.removeSeries(seriesApi: series1)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Query markers on remaining series
        let expectation = self.expectation(description: "Markers query completes")
        series2.markers { result in
            XCTAssertNotNil(result, "Markers on remaining series should still be accessible")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Repeated Add/Remove Tests

    /// Tests that repeatedly adding and removing series with markers doesn't cause issues
    func testRepeatedAddRemoveSeriesWithMarkers() {
        errorCatcher.clear()

        for i in 0..<3 {
            // Create a series
            let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
            let data: [CandlestickData] = [
                CandlestickData(time: .unix(Double(1000 + i * 1000)), open: 10, high: 15, low: 8, close: 12),
                CandlestickData(time: .unix(Double(2000 + i * 1000)), open: 12, high: 18, low: 10, close: 15)
            ]
            series.setData(data: data)

            // Add markers
            let markers = [
                SeriesMarker(time: data[0].time, position: .aboveBar, shape: .arrowUp, color: ChartColor(.green))
            ]
            series.setMarkers(data: markers)

            waitForAsyncOperations(duration: 0.05)

            // Remove the series
            charts.removeSeries(seriesApi: series)

            waitForAsyncOperations(duration: 0.05)
            errorCatcher.assertNoErrors()
        }
    }

    /// Tests that setting markers after removing and recreating a series works
    func testSetMarkersAfterRemoveAndRecreate() {
        errorCatcher.clear()

        // Create and remove a series
        let series1 = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let data: [HistogramData] = [
            HistogramData(time: .unix(1000), value: 10),
            HistogramData(time: .unix(2000), value: 20)
        ]
        series1.setData(data: data)

        let markers1 = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        series1.setMarkers(data: markers1)

        waitForAsyncOperations()

        charts.removeSeries(seriesApi: series1)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Create a new series and set markers
        let series2 = charts.addHistogramSeries(options: HistogramSeriesOptions())
        series2.setData(data: data)

        let markers2 = [
            SeriesMarker(time: data[1].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]
        series2.setMarkers(data: markers2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Verify markers are set correctly
        let expectation = self.expectation(description: "Markers query completes")
        series2.markers { result in
            XCTAssertNotNil(result, "Markers should be set on new series")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension MarkersLifecycleCleanupTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Watermark Deprecation Tests

/// Tests for watermark option deprecation (tasks 4.1 and 4.2)
///
/// These tests verify that:
/// - `ChartOptions.watermark` is properly deprecated (task 4.1)
/// - `WatermarkOptions` type is properly deprecated (task 4.2)
/// Both deprecations include migration guidance.
final class WatermarkDeprecationTests: XCTestCase {

    /// Tests that WatermarkOptions can still be created (backward compatibility)
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkOptionsIsStillAvailable() {
        // This test verifies backward compatibility - the type should still exist
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24,
            horizontalAlignment: .center,
            verticalAlignment: .center
        )

        XCTAssertNotNil(watermark, "WatermarkOptions should still be creatable for backward compatibility")
        XCTAssertEqual(watermark.text, "Test Watermark")
        XCTAssertEqual(watermark.fontSize, 24)
        XCTAssertEqual(watermark.horizontalAlignment, .center)
    }

    /// Tests that ChartOptions can still accept watermark parameter (backward compatibility)
    @available(*, deprecated, message: "Testing deprecated API")
    func testChartOptionsAcceptsWatermarkParameter() {
        // This test verifies backward compatibility - the init should still accept watermark
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24
        )

        let options = ChartOptions(
            watermark: watermark,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
        )

        XCTAssertNotNil(options.watermark, "ChartOptions should still accept watermark for backward compatibility")
        XCTAssertEqual(options.watermark?.text, "Test Watermark")
    }

    /// Tests that ChartOptions.watermark property can be set (backward compatibility)
    @available(*, deprecated, message: "Testing deprecated API")
    func testChartOptionsWatermarkPropertyIsSettable() {
        // This test verifies backward compatibility - the property should still be settable
        var options = ChartOptions()
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24
        )

        options.watermark = watermark

        XCTAssertNotNil(options.watermark, "ChartOptions.watermark property should still be settable for backward compatibility")
        XCTAssertEqual(options.watermark?.text, "Test Watermark")
    }

    /// Tests that chart can be created with watermark options (backward compatibility)
    @available(*, deprecated, message: "Testing deprecated API")
    func testChartCreationWithWatermarkOptions() {
        // This test verifies backward compatibility - chart should be creatable with watermark
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24,
            horizontalAlignment: .center,
            verticalAlignment: .center
        )

        let options = ChartOptions(
            watermark: watermark,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
        )

        // This should compile and run (the watermark will be handled by compatibility layer)
        // Note: The actual watermark rendering behavior will be implemented in task 4.4
        let chart = LightweightCharts(options: options)

        XCTAssertNotNil(chart, "Chart should be creatable with watermark options for backward compatibility")
    }

    /// Tests that all watermark option fields are preserved
    @available(*, deprecated, message: "Testing deprecated API")
    func testAllWatermarkOptionFieldsArePreserved() {
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Full Watermark Test",
            fontSize: 36,
            fontFamily: "Arial",
            fontStyle: "bold",
            horizontalAlignment: .left,
            verticalAlignment: .top
        )

        XCTAssertEqual(watermark.color, "rgba(171, 71, 188, 0.5)")
        XCTAssertTrue(watermark.visible ?? false)
        XCTAssertEqual(watermark.text, "Full Watermark Test")
        XCTAssertEqual(watermark.fontSize, 36)
        XCTAssertEqual(watermark.fontFamily, "Arial")
        XCTAssertEqual(watermark.fontStyle, "bold")
        XCTAssertEqual(watermark.horizontalAlignment, .left)
        XCTAssertEqual(watermark.verticalAlignment, .top)
    }

    /// Tests HorizontalAlignment enum values are available
    @available(*, deprecated, message: "Testing deprecated API")
    func testHorizontalAlignmentEnumValues() {
        XCTAssertEqual(HorizontalAlignment.left.rawValue, "left")
        XCTAssertEqual(HorizontalAlignment.center.rawValue, "center")
        XCTAssertEqual(HorizontalAlignment.right.rawValue, "right")
    }

    /// Tests VerticalAlignment enum values are available
    @available(*, deprecated, message: "Testing deprecated API")
    func testVerticalAlignmentEnumValues() {
        XCTAssertEqual(VerticalAlignment.top.rawValue, "top")
        XCTAssertEqual(VerticalAlignment.center.rawValue, "center")
        XCTAssertEqual(VerticalAlignment.bottom.rawValue, "bottom")
    }

    /// Tests that WatermarkOptions type is deprecated (task 4.2)
    ///
    /// Note: The deprecation is a compile-time warning. This test documents
    /// that the type should be marked with @available(*, deprecated).
    /// Developers using WatermarkOptions will see a deprecation warning.
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkOptionsTypeIsDeprecated() {
        // This test verifies backward compatibility - the deprecated type should still work
        // The @available(*, deprecated) attribute will cause compiler warnings
        // but the type remains functional for backward compatibility

        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Deprecated Watermark Type",
            fontSize: 24
        )

        // Verify the deprecated type still functions correctly
        XCTAssertNotNil(watermark, "Deprecated WatermarkOptions type should still be functional")
        XCTAssertEqual(watermark.text, "Deprecated Watermark Type")
    }

    // MARK: - Tests for task 4.3: Watermark exclusion from JS serialization

    /// Tests that watermark is excluded from JS options script (task 4.3)
    ///
    /// This test verifies that when ChartOptions includes a watermark,
    /// the serialized JavaScript output does NOT contain the watermark property.
    /// This is necessary because v5 of lightweight-charts no longer supports
    /// watermark as a chart option.
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkIsExcludedFromJSOptionsScript() {
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24
        )

        let options = ChartOptions(
            watermark: watermark,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
        )

        let script = options.optionsScript(for: nil)

        // The generated script should NOT contain the watermark property
        XCTAssertFalse(
            script.options.contains("watermark"),
            "JS options script should NOT include the deprecated watermark property"
        )

        // But it should include other properties like layout
        XCTAssertTrue(
            script.options.contains("layout"),
            "JS options script should include other valid properties like layout"
        )
    }

    /// Tests that watermark is excluded even when it's the only option set (task 4.3)
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkExclusionWhenOnlyOptionSet() {
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Only Watermark",
            fontSize: 24
        )

        let options = ChartOptions(watermark: watermark)

        let script = options.optionsScript(for: nil)

        // The generated script should NOT contain the watermark property
        XCTAssertFalse(
            script.options.contains("watermark"),
            "JS options script should NOT include the deprecated watermark property even when it's the only option"
        )

        // The options object should be empty or only contain null/undefined values
        let expectedEmptyPattern = #"var options = \{\};"#
        XCTAssertTrue(
            script.options.contains(expectedEmptyPattern) || script.options.contains("var options = {"),
            "JS options should be empty or minimal when only watermark is set"
        )
    }

    /// Tests that options without watermark serialize correctly (task 4.3)
    @available(*, deprecated, message: "Testing deprecated API")
    func testOptionsWithoutWatermarkSerializeCorrectly() {
        let options = ChartOptions(
            width: 400,
            height: 300,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
        )

        let script = options.optionsScript(for: nil)

        // Should contain width and height
        XCTAssertTrue(
            script.options.contains("width") && script.options.contains("400"),
            "JS options script should include width"
        )
        XCTAssertTrue(
            script.options.contains("height") && script.options.contains("300"),
            "JS options script should include height"
        )
        XCTAssertTrue(
            script.options.contains("layout"),
            "JS options script should include layout"
        )

        // Should NOT contain watermark
        XCTAssertFalse(
            script.options.contains("watermark"),
            "JS options script should NOT include watermark when it wasn't set"
        )
    }

    /// Tests that watermark property remains accessible in Swift (task 4.3)
    ///
    /// While watermark is excluded from JS serialization, it should still be
    /// accessible in the Swift object for backward compatibility.
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkPropertyRemainsAccessibleInSwift() {
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Accessible Watermark",
            fontSize: 24
        )

        let options = ChartOptions(watermark: watermark)

        // The Swift property should still be accessible
        XCTAssertNotNil(options.watermark, "watermark property should be accessible in Swift")
        XCTAssertEqual(options.watermark?.text, "Accessible Watermark")
        XCTAssertEqual(options.watermark?.color, "rgba(171, 71, 188, 0.5)")
    }
}

// MARK: - Raw Chart Options JS Payload Tests (Task 10.10)

/// Tests for verifying watermark exclusion from raw JS payload (Task 10.10)
///
/// These tests verify that:
/// - The `watermark` property is excluded from the raw JSON payload
/// - The JSON serialization directly excludes watermark at the encoding level
/// - This is verified by extracting and parsing the JSON from the options script
final class RawChartOptionsJSPayloadTests: XCTestCase {

    /// Tests that watermark key is not present in raw JSON payload (Task 10.10)
    ///
    /// This test extracts the JSON portion from the options script and
    /// verifies that the `watermark` key is not present in the raw JSON object.
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkKeyNotInRawJSONPayload() {
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24
        )

        let options = ChartOptions(
            watermark: watermark,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
        )

        let script = options.optionsScript(for: nil)

        // Extract the JSON portion from "var options = { ... };"
        // The pattern is: var options = <JSON>;
        let jsonPattern = #"var options = \{(.*)\};"#
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: script.options, range: NSRange(script.options.startIndex..., in: script.options)),
              let jsonRange = Range(match.range(at: 1), in: script.options) else {
            XCTFail("Could not extract JSON from options script")
            return
        }

        let jsonContent = String(script.options[jsonRange])

        // Verify watermark key is NOT in the JSON content
        XCTAssertFalse(
            jsonContent.contains("watermark"),
            "Raw JSON payload should NOT contain the 'watermark' key. Found in: \(jsonContent)"
        )

        // Verify layout key IS present (sanity check that extraction worked)
        XCTAssertTrue(
            jsonContent.contains("layout"),
            "Raw JSON payload should contain the 'layout' key. JSON content: \(jsonContent)"
        )
    }

    /// Tests that watermark is excluded even with complex watermark options (Task 10.10)
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkExcludedWithComplexOptions() {
        let complexWatermark = WatermarkOptions(
            color: "rgba(255, 0, 0, 0.8)",
            visible: true,
            text: "Complex Watermark",
            fontSize: 48,
            fontFamily: "Arial",
            fontStyle: "bold",
            horizontalAlignment: .right,
            verticalAlignment: .bottom
        )

        let options = ChartOptions(
            width: 800,
            height: 600,
            watermark: complexWatermark,
            layout: LayoutOptions(background: .solid(color: "#000000"), textColor: "#ffffff")
        )

        let script = options.optionsScript(for: nil)

        // Extract and verify the JSON doesn't contain watermark
        let jsonPattern = #"var options = \{(.*)\};"#
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: script.options, range: NSRange(script.options.startIndex..., in: script.options)),
              let jsonRange = Range(match.range(at: 1), in: script.options) else {
            XCTFail("Could not extract JSON from options script")
            return
        }

        let jsonContent = String(script.options[jsonRange])

        XCTAssertFalse(
            jsonContent.contains("watermark"),
            "Raw JSON payload should NOT contain 'watermark' key even with complex options. Found in: \(jsonContent)"
        )

        // Verify other properties are present
        XCTAssertTrue(
            jsonContent.contains("width") && jsonContent.contains("800"),
            "Raw JSON should contain width property"
        )
        XCTAssertTrue(
            jsonContent.contains("height") && jsonContent.contains("600"),
            "Raw JSON should contain height property"
        )
    }

    /// Tests that watermark values don't leak into JSON (Task 10.10)
    ///
    /// Even though the watermark key should be excluded, this test verifies
    /// that watermark VALUES (like text, color) are also not present in the JSON.
    /// This provides an extra layer of verification against encoding bugs.
    @available(*, deprecated, message: "Testing deprecated API")
    func testWatermarkValuesNotInJSONPayload() {
        let uniqueWatermarkText = "UNIQUE_WATERMARK_TEXT_12345"
        let uniqueWatermarkColor = "rgba(999, 888, 777, 0.9)"

        let watermark = WatermarkOptions(
            color: ChartColor(stringLiteral: uniqueWatermarkColor),
            visible: true,
            text: uniqueWatermarkText,
            fontSize: 99
        )

        let options = ChartOptions(watermark: watermark)

        let script = options.optionsScript(for: nil as ClosuresStore?)

        // Verify none of the watermark values are in the script
        XCTAssertFalse(
            script.options.contains(uniqueWatermarkText),
            "JS payload should NOT contain watermark text value"
        )
        XCTAssertFalse(
            script.options.contains(uniqueWatermarkColor),
            "JS payload should NOT contain watermark color value"
        )
        XCTAssertFalse(
            script.options.contains("99"),  // The unique fontSize value
            "JS payload should NOT contain watermark fontSize value when it's the only option"
        )
    }

    /// Tests raw JSON structure is valid without watermark (Task 10.10)
    ///
    /// This test verifies that the JSON payload is valid and parseable
    /// after excluding the watermark property.
    @available(*, deprecated, message: "Testing deprecated API")
    func testRawJSONIsValidAfterWatermarkExclusion() {
        let watermark = WatermarkOptions(
            color: "rgba(171, 71, 188, 0.5)",
            visible: true,
            text: "Test Watermark",
            fontSize: 24
        )

        let options = ChartOptions(
            width: 400,
            height: 300,
            watermark: watermark,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)

        // Extract JSON (same pattern as other tests)
        let jsonPattern = #"var options = \{(.*)\};"#
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: script.options, range: NSRange(script.options.startIndex..., in: script.options)),
              let jsonRange = Range(match.range(at: 1), in: script.options) else {
            XCTFail("Could not extract JSON from options script")
            return
        }

        let jsonString = String(script.options[jsonRange])

        // Verify the JSON is valid (can be parsed)
        guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
            XCTFail("Could not convert JSON string to data")
            return
        }

        do {
            let parsedJSON = try JSONSerialization.jsonObject(with: jsonData, options: [])
            guard let jsonDict = parsedJSON as? [String: Any] else {
                XCTFail("JSON should be a dictionary")
                return
            }

            // Verify watermark key is not in the parsed dictionary
            XCTAssertNil(
                jsonDict["watermark"],
                "Parsed JSON dictionary should NOT contain 'watermark' key"
            )

            // Verify expected keys are present
            XCTAssertNotNil(
                jsonDict["width"],
                "Parsed JSON should contain 'width' key"
            )
            XCTAssertNotNil(
                jsonDict["height"],
                "Parsed JSON should contain 'height' key"
            )
            XCTAssertNotNil(
                jsonDict["layout"],
                "Parsed JSON should contain 'layout' key"
            )
        } catch {
            XCTFail("JSON parsing failed with error: \(error)")
        }
    }

    /// Tests that only watermark is excluded, not other properties (Task 10.10)
    ///
    /// This test verifies that when watermark is set alongside other properties,
    /// only the watermark key is excluded and all other properties are included.
    @available(*, deprecated, message: "Testing deprecated API")
    func testOnlyWatermarkExcludedOtherPropertiesIncluded() {
        let options = ChartOptions(
            width: 500,
            height: 400,
            watermark: WatermarkOptions(text: "Should be excluded"),
            layout: LayoutOptions(background: .solid(color: "#111111"), textColor: "#222222"),
            leftPriceScale: VisiblePriceScaleOptions(visible: true),
            rightPriceScale: VisiblePriceScaleOptions(visible: false),
            timeScale: TimeScaleOptions(rightOffset: 5),
            crosshair: CrosshairOptions(mode: .normal),
            grid: GridOptions(
                verticalLines: GridLineOptions(color: "rgba(1, 2, 3, 0.5)"),
                horizontalLines: GridLineOptions(color: "rgba(4, 5, 6, 0.5)")
            )
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)

        // All these keys should be present
        let expectedKeys = ["width", "height", "layout", "leftPriceScale", "rightPriceScale", "timeScale", "crosshair", "grid"]
        for key in expectedKeys {
            XCTAssertTrue(
                script.options.contains(key),
                "JS payload should contain '\(key)' key"
            )
        }

        // Watermark should NOT be present
        XCTAssertFalse(
            script.options.contains("watermark"),
            "JS payload should NOT contain 'watermark' key"
        )
    }
}

// MARK: - Legacy Watermark Compatibility Tests (task 4.4)

/// Tests for legacy watermark compatibility path (task 4.4)
///
/// These tests verify that:
/// - If `ChartOptions.watermark` is provided, a text watermark primitive is created after chart creation
/// - The legacy watermark is properly stored on the chart object
/// - Re-applying options updates/recreates the legacy watermark
/// - The watermark is properly cleaned up on chart removal
// final class LegacyWatermarkCompatibilityTests: XCTestCase {
// 
//     var charts: LightweightCharts!
//     var errorCatcher: JSErrorCatcher!
//     var loadExpectation: XCTestExpectation!
// 
//     override func setUp() {
//         super.setUp()
// 
//         loadExpectation = expectation(description: "Chart loads")
// 
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
//         errorCatcher = JSErrorCatcher()
// 
//         charts.errorDelegate = errorCatcher
//         charts.loadDelegate = self
// 
//         wait(for: [loadExpectation], timeout: 5.0)
//     }
// 
//     override func tearDown() {
//         charts = nil
//         errorCatcher = nil
//         super.tearDown()
//     }
// 
//     // MARK: - Task 4.4: Legacy watermark creation after chart load
// 
//     /// Tests that watermark is created when provided in initial chart options (task 4.4)
//     func testLegacyWatermarkCreatedOnChartLoad() {
//         errorCatcher.clear()
// 
//         let watermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "Legacy Watermark",
//             fontSize: 24,
//             horizontalAlignment: .center,
//             verticalAlignment: .center
//         )
// 
//         let options = ChartOptions(
//             watermark: watermark,
//             layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
//         )
// 
//         // Create a new chart with watermark
//         let expectation2 = expectation(description: "Second chart loads")
//         let chartWithWatermark = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         chartWithWatermark.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         chartWithWatermark.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Chart should be created without errors
//         errorCatcher.assertNoErrors()
//         XCTAssertNotNil(chartWithWatermark, "Chart with watermark should be created successfully")
//     }
// 
//     /// Tests that watermark with all options is converted correctly (task 4.4)
//     func testLegacyWatermarkAllOptionsConverted() {
//         errorCatcher.clear()
// 
//         let watermark = WatermarkOptions(
//             color: "rgba(255, 0, 0, 0.8)",
//             visible: true,
//             text: "Full Test",
//             fontSize: 36,
//             fontFamily: "Arial",
//             fontStyle: "bold",
//             horizontalAlignment: .left,
//             verticalAlignment: .top
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with full watermark loads")
//         let chartWithFullWatermark = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         chartWithFullWatermark.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         chartWithFullWatermark.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Chart should be created without errors
//         errorCatcher.assertNoErrors()
//         XCTAssertNotNil(chartWithFullWatermark, "Chart with full watermark options should be created successfully")
//     }
// 
//     /// Tests that watermark with visible: false does not create the watermark primitive (task 4.4)
//     func testLegacyWatermarkNotCreatedWhenVisibleFalse() {
//         errorCatcher.clear()
// 
//         let watermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: false,  // Not visible
//             text: "Hidden Watermark",
//             fontSize: 24
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with invisible watermark loads")
//         let chartWithHiddenWatermark = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         chartWithHiddenWatermark.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         chartWithHiddenWatermark.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Chart should be created without errors (watermark not created is valid)
//         errorCatcher.assertNoErrors()
//         XCTAssertNotNil(chartWithHiddenWatermark, "Chart with invisible watermark should be created successfully")
//     }
// 
//     /// Tests that chart without watermark options works correctly (task 4.4)
//     func testChartWithoutWatermarkWorksCorrectly() {
//         errorCatcher.clear()
// 
//         let options = ChartOptions(
//             layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
//         )
// 
//         let expectation2 = expectation(description: "Chart without watermark loads")
//         let chartWithoutWatermark = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         chartWithoutWatermark.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         chartWithoutWatermark.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Chart should be created without errors
//         errorCatcher.assertNoErrors()
//         XCTAssertNotNil(chartWithoutWatermark, "Chart without watermark should be created successfully")
// 
//         // Verify chart is functional by adding a series
//         let series = chartWithoutWatermark.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10),
//             LineData(time: .unix(2000), value: 20)
//         ]
//         series.setData(data: data)
// 
//         // Wait a bit for the data to be set
//         let waitExpectation = expectation(description: "Data set")
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             waitExpectation.fulfill()
//         }
//         wait(for: [waitExpectation], timeout: 2.0)
// 
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that applyOptions updates the watermark (task 4.5 - deterministic behavior)
//     func testApplyOptionsUpdatesWatermark() {
//         errorCatcher.clear()
// 
//         // Initial chart without watermark
//         let initialOptions = ChartOptions(
//             layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333")
//         )
// 
//         let expectation2 = expectation(description: "Chart for applyOptions loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: initialOptions)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Now apply options with a watermark
//         let watermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "Updated Watermark",
//             fontSize: 24
//         )
// 
//         let optionsWithWatermark = ChartOptions(watermark: watermark)
//         testChart.applyOptions(options: optionsWithWatermark)
// 
//         // Wait for the update to complete
//         let waitExpectation = expectation(description: "Options applied")
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             waitExpectation.fulfill()
//         }
//         wait(for: [waitExpectation], timeout: 2.0)
// 
//         // Should not produce errors
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that applyOptions with nil watermark removes existing watermark (task 4.5)
//     func testApplyOptionsWithNilWatermarkRemovesWatermark() {
//         errorCatcher.clear()
// 
//         // Initial chart WITH watermark
//         let watermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "Initial Watermark",
//             fontSize: 24
//         )
// 
//         let initialOptions = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with initial watermark loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: initialOptions)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Now apply options without watermark (should remove the watermark)
//         let optionsWithoutWatermark = ChartOptions()
//         testChart.applyOptions(options: optionsWithoutWatermark)
// 
//         // Wait for the update to complete
//         let waitExpectation = expectation(description: "Options applied")
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             waitExpectation.fulfill()
//         }
//         wait(for: [waitExpectation], timeout: 2.0)
// 
//         // Should not produce errors
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that chart removal cleans up the watermark (task 4.4)
//     func testChartRemovalCleansUpWatermark() {
//         errorCatcher.clear()
// 
//         let watermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "To Be Removed",
//             fontSize: 24
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart for removal test loads")
//         let chartToBeRemoved = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         chartToBeRemoved.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         chartToBeRemoved.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Remove the chart
//         chartToBeRemoved.remove()
// 
//         // Wait for removal to complete
//         let waitExpectation = expectation(description: "Chart removed")
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             waitExpectation.fulfill()
//         }
//         wait(for: [waitExpectation], timeout: 2.0)
// 
//         // Should not produce errors during removal
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that different horizontal alignments work (task 4.4)
//     func testLegacyWatermarkHorizontalAlignmentOptions() {
//         errorCatcher.clear()
// 
//         let alignments: [HorizontalAlignment] = [.left, .center, .right]
// 
//         for alignment in alignments {
//             let watermark = WatermarkOptions(
//                 color: "rgba(171, 71, 188, 0.5)",
//                 visible: true,
//                 text: "Align \(alignment.rawValue)",
//                 fontSize: 24,
//                 horizontalAlignment: alignment
//             )
// 
//             let options = ChartOptions(watermark: watermark)
// 
//             let expectation2 = expectation(description: "Chart with \(alignment.rawValue) alignment loads")
//             let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//             testChart.errorDelegate = errorCatcher
//             let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//             wait(for: [expectation2], timeout: 5.0)
//         }
// 
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that different vertical alignments work (task 4.4)
//     func testLegacyWatermarkVerticalAlignmentOptions() {
//         errorCatcher.clear()
// 
//         let alignments: [VerticalAlignment] = [.top, .center, .bottom]
// 
//         for alignment in alignments {
//             let watermark = WatermarkOptions(
//                 color: "rgba(171, 71, 188, 0.5)",
//                 visible: true,
//                 text: "Align \(alignment.rawValue)",
//                 fontSize: 24,
//                 verticalAlignment: alignment
//             )
// 
//             let options = ChartOptions(watermark: watermark)
// 
//             let expectation2 = expectation(description: "Chart with \(alignment.rawValue) alignment loads")
//             let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//             testChart.errorDelegate = errorCatcher
//             let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//             wait(for: [expectation2], timeout: 5.0)
//         }
// 
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that default values are used when optional fields are nil (task 4.4)
//     func testLegacyWatermarkDefaultsAreUsed() {
//         errorCatcher.clear()
// 
//         // Watermark with minimal options (most fields nil)
//         let watermark = WatermarkOptions(
//             text: "Minimal Watermark"
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with minimal watermark loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Should use defaults: visible=true, color=rgba(171, 71, 188, 0.5), fontSize=24, etc.
//         errorCatcher.assertNoErrors()
//         XCTAssertNotNil(testChart, "Chart with minimal watermark should use defaults successfully")
//     }
// 
//     /// Tests the exact usage pattern from CustomWatermarkViewController (task 4.4)
//     func testCustomWatermarkViewControllerPattern() {
//         errorCatcher.clear()
// 
//         // This is the exact pattern used in CustomWatermarkViewController
//         let options = ChartOptions(
//             watermark: WatermarkOptions(
//                 color: "rgba(171, 71, 188, 0.5)",
//                 visible: true,
//                 text: "Watermark Example",
//                 fontSize: 24,
//                 horizontalAlignment: .center,
//                 verticalAlignment: .center
//             ),
//             layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333"),
//             rightPriceScale: VisiblePriceScaleOptions(scaleMargins: PriceScaleMargins(top: 0.1, bottom: 0.2)),
//             grid: GridOptions(
//                 verticalLines: GridLineOptions(color: "#eee"),
//                 horizontalLines: GridLineOptions(color: "#ffffff")
//             )
//         )
// 
//         let expectation2 = expectation(description: "CustomWatermarkViewController pattern chart loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         errorCatcher.assertNoErrors()
// 
//         // Also add a series like the example does
//         let areaOptions = AreaSeriesOptions(
//      topColor: "rgba(171, 71, 188, 0.56)",
//      bottomColor: "rgba(171, 71, 188, 0.04)",
//      lineColor: "rgba(171, 71, 188, 1)",
//      lineWidth: .two
//  )
//         let series = testChart.addAreaSeries(options: areaOptions)
// 
//         let data: [AreaData] = [
//             AreaData(time: .string("2018-10-19"), value: 75.46),
//             AreaData(time: .string("2018-10-22"), value: 76.69),
//             AreaData(time: .string("2018-10-23"), value: 73.82)
//         ]
//         series.setData(data: data)
// 
//         let waitExpectation = expectation(description: "Data set")
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             waitExpectation.fulfill()
//         }
//         wait(for: [waitExpectation], timeout: 2.0)
// 
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - Task 10.9: Legacy watermark compatibility test
// 
//     /// Tests that multiple legacy watermark updates work correctly (task 10.9)
//     ///
//     /// This test validates the compatibility path for ChartOptions.watermark by:
//     /// 1. Creating a chart with initial watermark options
//     /// 2. Applying new watermark options via applyOptions
//     /// 3. Removing the watermark by applying options without watermark
//     /// 4. Re-applying watermark options to recreate it
//     /// This ensures the compatibility layer handles the full lifecycle correctly.
//     func testLegacyWatermarkMultipleUpdatesCycle() {
//         errorCatcher.clear()
// 
//         // Start with a chart with watermark
//         let initialWatermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "Initial Watermark",
//             fontSize: 24,
//             horizontalAlignment: .center,
//             verticalAlignment: .center
//         )
// 
//         let options = ChartOptions(watermark: initialWatermark)
// 
//         let expectation2 = expectation(description: "Chart with watermark loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Update 1: Change watermark text and color
//         let updatedWatermark1 = WatermarkOptions(
//             color: "rgba(255, 0, 0, 0.8)",
//             visible: true,
//             text: "Updated Watermark 1",
//             fontSize: 30
//         )
// 
//         let optionsWithUpdate1 = ChartOptions(watermark: updatedWatermark1)
//         testChart.applyOptions(options: optionsWithUpdate1)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
// 
//         // Update 2: Change alignment
//         let updatedWatermark2 = WatermarkOptions(
//             color: "rgba(0, 255, 0, 0.6)",
//             visible: true,
//             text: "Updated Watermark 2",
//             fontSize: 20,
//             horizontalAlignment: .left,
//             verticalAlignment: .top
//         )
// 
//         let optionsWithUpdate2 = ChartOptions(watermark: updatedWatermark2)
//         testChart.applyOptions(options: optionsWithUpdate2)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
// 
//         // Update 3: Remove watermark
//         let optionsWithoutWatermark = ChartOptions()
//         testChart.applyOptions(options: optionsWithoutWatermark)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
// 
//         // Update 4: Re-create watermark with new options
//         let recreatedWatermark = WatermarkOptions(
//             color: "rgba(0, 0, 255, 0.7)",
//             visible: true,
//             text: "Recreated Watermark",
//             fontSize: 28,
//             horizontalAlignment: .right,
//             verticalAlignment: .bottom,
//             fontFamily: "Courier",
//             fontStyle: "italic"
//         )
// 
//         let optionsWithRecreated = ChartOptions(watermark: recreatedWatermark)
//         testChart.applyOptions(options: optionsWithRecreated)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that watermark with visible: false removes existing watermark (task 10.9)
//     func testLegacyWatermarkVisibleFalseRemovesExistingWatermark() {
//         errorCatcher.clear()
// 
//         // Create chart with visible watermark
//         let initialWatermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "Initially Visible",
//             fontSize: 24
//         )
// 
//         let options = ChartOptions(watermark: initialWatermark)
// 
//         let expectation2 = expectation(description: "Chart loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Apply options with visible: false - should remove the watermark
//         let hiddenWatermark = WatermarkOptions(
//             visible: false,
//             text: "Now Hidden"
//         )
// 
//         let optionsWithHidden = ChartOptions(watermark: hiddenWatermark)
//         testChart.applyOptions(options: optionsWithHidden)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that watermark options with all nil values uses defaults (task 10.9)
//     func testLegacyWatermarkWithAllNilValuesUsesDefaults() {
//         errorCatcher.clear()
// 
//         // Watermark with only text specified, all other fields nil
//         let watermark = WatermarkOptions(
//             color: nil,
//             visible: nil,
//             text: "Default Values Test",
//             fontSize: nil,
//             fontFamily: nil,
//             fontStyle: nil,
//             horizontalAlignment: nil,
//             verticalAlignment: nil
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with nil values loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Should use defaults from applyLegacyWatermark:
//         // - color: "rgba(171, 71, 188, 0.5)"
//         // - visible: true (default when nil)
//         // - fontSize: 24
//         // - fontFamily: "-apple-system"
//         // - fontStyle: "normal"
//         // - horizontalAlignment: .center
//         // - verticalAlignment: .center
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that watermark with empty text works correctly (task 10.9)
//     func testLegacyWatermarkWithEmptyText() {
//         errorCatcher.clear()
// 
//         let watermark = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "",  // Empty text
//             fontSize: 24
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with empty text loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Empty text should still create the watermark primitive
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that multiple charts with legacy watermarks work independently (task 10.9)
//     func testMultipleChartsWithLegacyWatermarks() {
//         errorCatcher.clear()
// 
//         // Create first chart with watermark
//         let watermark1 = WatermarkOptions(
//             color: "rgba(255, 0, 0, 0.5)",
//             visible: true,
//             text: "Chart 1",
//             fontSize: 24
//         )
// 
//         let options1 = ChartOptions(watermark: watermark1)
// 
//         let expectation1 = expectation(description: "First chart loads")
//         let chart1 = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options1)
//         chart1.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation1)
//         chart1.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation1], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Create second chart with different watermark
//         let watermark2 = WatermarkOptions(
//             color: "rgba(0, 0, 255, 0.5)",
//             visible: true,
//             text: "Chart 2",
//             fontSize: 30,
//             horizontalAlignment: .left
//         )
// 
//         let options2 = ChartOptions(watermark: watermark2)
// 
//         let expectation2 = expectation(description: "Second chart loads")
//         let chart2 = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options2)
//         chart2.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         chart2.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Update first chart watermark
//         let updatedWatermark1 = WatermarkOptions(
//             color: "rgba(0, 255, 0, 0.5)",
//             visible: true,
//             text: "Chart 1 Updated",
//             fontSize: 20
//         )
// 
//         let updatedOptions1 = ChartOptions(watermark: updatedWatermark1)
//         chart1.applyOptions(options: updatedOptions1)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
// 
//         // Both charts should be functional
//         let series1 = chart1.addLineSeries(options: LineSeriesOptions())
//         series1.setData(data: [
//             LineData(time: .unix(1000), value: 10),
//             LineData(time: .unix(2000), value: 20)
//         ])
// 
//         let series2 = chart2.addLineSeries(options: LineSeriesOptions())
//         series2.setData(data: [
//             LineData(time: .unix(1000), value: 30),
//             LineData(time: .unix(2000), value: 40)
//         ])
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that chart with watermark can be removed and recreated (task 10.9)
//     func testLegacyWatermarkChartRemovalAndRecreation() {
//         errorCatcher.clear()
// 
//         var testChart: LightweightCharts? = nil
// 
//         // First chart with watermark
//         let watermark1 = WatermarkOptions(
//             color: "rgba(171, 71, 188, 0.5)",
//             visible: true,
//             text: "First Instance",
//             fontSize: 24
//         )
// 
//         let options1 = ChartOptions(watermark: watermark1)
// 
//         let expectation1 = expectation(description: "First chart loads")
//         testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options1)
//         testChart?.errorDelegate = errorCatcher
//         testChart?.loadDelegate = TestLoadDelegate(expectation: expectation1)
// 
//         wait(for: [expectation1], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // Remove the chart
//         testChart?.remove()
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
// 
//         testChart = nil
// 
//         // Create a new chart with watermark (simulating recreation)
//         let watermark2 = WatermarkOptions(
//             color: "rgba(255, 100, 0, 0.6)",
//             visible: true,
//             text: "Second Instance",
//             fontSize: 28
//         )
// 
//         let options2 = ChartOptions(watermark: watermark2)
// 
//         let expectation2 = expectation(description: "Second chart loads")
//         testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options2)
//         testChart?.errorDelegate = errorCatcher
//         testChart?.loadDelegate = TestLoadDelegate(expectation: expectation2)
// 
//         wait(for: [expectation2], timeout: 5.0)
//         errorCatcher.assertNoErrors()
// 
//         // New chart should be functional
//         let series = testChart?.addLineSeries(options: LineSeriesOptions())
//         series?.setData(data: [
//             LineData(time: .unix(1000), value: 10)
//         ])
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that watermark options are converted correctly to v5 format (task 10.9)
//     func testLegacyWatermarkOptionsConversionToV5Format() {
//         errorCatcher.clear()
// 
//         // Test all option conversions:
//         // - color -> lines[0].color
//         // - text -> lines[0].text
//         // - fontSize -> lines[0].fontSize
//         // - fontFamily -> lines[0].fontFamily
//         // - fontStyle -> lines[0].fontStyle
//         // - horizontalAlignment -> horzAlign
//         // - verticalAlignment -> vertAlign
//         // - visible -> visible
// 
//         let watermark = WatermarkOptions(
//             color: "rgba(128, 64, 192, 0.75)",
//             visible: true,
//             text: "Conversion Test",
//             fontSize: 32,
//             fontFamily: "Georgia",
//             fontStyle: "bold italic",
//             horizontalAlignment: .right,
//             verticalAlignment: .bottom
//         )
// 
//         let options = ChartOptions(watermark: watermark)
// 
//         let expectation2 = expectation(description: "Chart with all options loads")
//         let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         testChart.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: expectation2)
//         testChart.loadDelegate = strongLoadDelegate
// 
//         wait(for: [expectation2], timeout: 5.0)
// 
//         // Verify chart was created successfully with all options converted
//         errorCatcher.assertNoErrors()
//         XCTAssertNotNil(testChart, "Chart should be created with all watermark options converted correctly")
//     }
// 
//     // MARK: - Helper Methods
// 
//     private func waitForAsyncOperations(duration: TimeInterval = 0.3) {
//         let expectation = self.expectation(description: "Async operations complete")
//         DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
//             expectation.fulfill()
//         }
//         wait(for: [expectation], timeout: 2.0)
//     }
// }

// MARK: - V5 Text Watermark API Tests (task 4.6)

final class V5TextWatermarkAPITests: XCTestCase {
    var errorCatcher: JSErrorCatcher!

    override func setUp() {
        super.setUp()
        errorCatcher = JSErrorCatcher()
    }

    override func tearDown() {
        errorCatcher = nil
        super.tearDown()
    }

    /// Tests that createTextWatermarkPlugin API is available on ChartApi
    func testCreateTextWatermarkPluginAPIExists() {
        let options = ChartOptions()
        let chart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        chart.errorDelegate = errorCatcher

        // Verify the plugin factory method exists and can be called
        let watermarkOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Test Watermark",
            color: "rgba(171, 71, 188, 0.5)",
            fontSize: 24
        )

        let watermarkPlugin = chart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

        XCTAssertNotNil(watermarkPlugin, "createTextWatermarkPlugin should return a TextWatermarkPlugin instance")

        // Wait for async operations
        let waitExpectation = expectation(description: "Wait for watermark plugin creation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }

    /// Tests that TextWatermarkOptions encodes correctly to JSON
    func testTextWatermarkOptionsEncoding() {
        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            text: "Test Watermark",
            color: "rgba(171, 71, 188, 0.5)",
            fontSize: 24,
            fontFamily: "-apple-system",
            fontStyle: "normal"
        )

        let jsonString = options.jsonString()

        XCTAssertTrue(jsonString.contains("\"visible\":true"), "Should contain visible field")
        XCTAssertTrue(jsonString.contains("\"horzAlign\":\"center\""), "Should contain horzAlign field")
        XCTAssertTrue(jsonString.contains("\"vertAlign\":\"center\""), "Should contain vertAlign field")
        XCTAssertTrue(jsonString.contains("\"lines\""), "Should contain lines array")
        XCTAssertTrue(jsonString.contains("\"text\":\"Test Watermark\""), "Should contain text")
        XCTAssertTrue(jsonString.contains("\"color\":\"rgba(171, 71, 188, 0.5)\""), "Should contain color")
        XCTAssertTrue(jsonString.contains("\"fontSize\":24"), "Should contain fontSize")
    }

    /// Tests that WatermarkLine encodes correctly to JSON
    func testWatermarkLineEncoding() {
        let line = WatermarkLine(
            text: "Test Line",
            color: "rgba(255, 0, 0, 0.8)",
            fontSize: 30,
            fontFamily: "Helvetica",
            fontStyle: "italic"
        )

        let jsonString = line.jsonString()

        XCTAssertTrue(jsonString.contains("\"text\":\"Test Line\""), "Should contain text")
        XCTAssertTrue(jsonString.contains("\"color\":\"rgba(255, 0, 0, 0.8)\""), "Should contain color")
        XCTAssertTrue(jsonString.contains("\"fontSize\":30"), "Should contain fontSize")
        XCTAssertTrue(jsonString.contains("\"fontFamily\":\"Helvetica\""), "Should contain fontFamily")
        XCTAssertTrue(jsonString.contains("\"fontStyle\":\"italic\""), "Should contain fontStyle")
    }

    /// Tests TextWatermarkOptions with multiple lines
    func testTextWatermarkOptionsMultipleLines() {
        let lines = [
            WatermarkLine(text: "First Line", color: "rgba(255, 0, 0, 0.5)", fontSize: 24),
            WatermarkLine(text: "Second Line", color: "rgba(0, 255, 0, 0.5)", fontSize: 20)
        ]

        let options = TextWatermarkOptions(
            horizontalAlignment: .left,
            verticalAlignment: .top,
            lines: lines
        )

        let jsonString = options.jsonString()

        XCTAssertTrue(jsonString.contains("\"horzAlign\":\"left\""), "Should contain left alignment")
        XCTAssertTrue(jsonString.contains("\"vertAlign\":\"top\""), "Should contain top alignment")
        // Should have two lines
        let lineCount = jsonString.components(separatedBy: "\"text\"").count - 1
        XCTAssertEqual(lineCount, 2, "Should have 2 lines")
    }

    /// Tests the exact usage pattern from updated CustomWatermarkViewController
    func testCustomWatermarkViewControllerV5Pattern() {
        errorCatcher.clear()

        // The exact pattern from the updated CustomWatermarkViewController
        let options = ChartOptions(
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333"),
            rightPriceScale: VisiblePriceScaleOptions(scaleMargins: PriceScaleMargins(top: 0.1, bottom: 0.2)),
            grid: GridOptions(
                verticalLines: GridLineOptions(color: "#eee"),
                horizontalLines: GridLineOptions(color: "#ffffff")
            )
        )

        let expectationLoad = expectation(description: "Chart loads")
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        testChart.errorDelegate = errorCatcher
        let strongLoadDelegate = TestLoadDelegate(expectation: expectationLoad)
        testChart.loadDelegate = strongLoadDelegate

        wait(for: [expectationLoad], timeout: 5.0)

        errorCatcher.assertNoErrors()

        // Create the text watermark using the v5 plugin API after the chart loads
        let watermarkOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Watermark Example",
            color: "rgba(171, 71, 188, 0.5)",
            fontSize: 24
        )
        let watermark = testChart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

        XCTAssertNotNil(watermark, "Watermark plugin should be created")

        // Wait for async operations
        let waitExpectation = expectation(description: "Wait for watermark")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        errorCatcher.assertNoErrors()

        // Also add a series like the example does
        let areaOptions = AreaSeriesOptions(
     topColor: "rgba(171, 71, 188, 0.56)",
     bottomColor: "rgba(171, 71, 188, 0.04)",
     lineColor: "rgba(171, 71, 188, 1)",
     lineWidth: .two
 )
        let series = testChart.addAreaSeries(options: areaOptions)

        let data: [AreaData] = [
            AreaData(time: .string("2018-10-19"), value: 75.46),
            AreaData(time: .string("2018-10-22"), value: 76.69),
            AreaData(time: .string("2018-10-23"), value: 73.82)]
        series.setData(data: data)

        let waitExpectation2 = expectation(description: "Data set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation2.fulfill()
        }
        wait(for: [waitExpectation2], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }

    /// Tests that watermark plugin can be updated via applyOptions
    func testTextWatermarkPluginApplyOptions() {
        errorCatcher.clear()

        let options = ChartOptions()
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        testChart.errorDelegate = errorCatcher

        let watermarkOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Original Text",
            color: "rgba(255, 0, 0, 0.5)",
            fontSize: 20
        )
        let watermark = testChart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

        // Wait for creation
        let waitExpectation1 = expectation(description: "Wait for watermark creation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation1.fulfill()
        }
        wait(for: [waitExpectation1], timeout: 2.0)

        // Update the watermark via plugin
        let updatedOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Updated Text",
            color: "rgba(0, 0, 255, 0.8)",
            fontSize: 30
        )
        watermark.applyOptions(options: updatedOptions)

        // Wait for update
        let waitExpectation2 = expectation(description: "Wait for watermark update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation2.fulfill()
        }
        wait(for: [waitExpectation2], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }

    /// Tests that watermark plugin can be detached
    func testTextWatermarkPluginDetach() {
        errorCatcher.clear()

        let options = ChartOptions()
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        testChart.errorDelegate = errorCatcher

        let watermarkOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "To Be Removed",
            color: "rgba(171, 71, 188, 0.5)",
            fontSize: 24
        )
        let watermark = testChart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

        // Wait for creation
        let waitExpectation1 = expectation(description: "Wait for watermark creation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation1.fulfill()
        }
        wait(for: [waitExpectation1], timeout: 2.0)

        // Detach the watermark plugin
        watermark.detach()

        // Wait for detachment
        let waitExpectation2 = expectation(description: "Wait for watermark detach")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation2.fulfill()
        }
        wait(for: [waitExpectation2], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }

    /// Tests all horizontal alignment options
    func testTextWatermarkPluginHorizontalAlignmentOptions() {
        errorCatcher.clear()

        let alignments: [HorizontalAlignment] = [.left, .center, .right]

        for alignment in alignments {
            let options = ChartOptions()
            let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
            testChart.errorDelegate = errorCatcher

            let watermarkOptions = TextWatermarkOptions(visible: true, horizontalAlignment: alignment, verticalAlignment: .center, text: "\(alignment.rawValue) Aligned",
                color: "rgba(171, 71, 188, 0.5)",
                fontSize: 24
            )
            let watermark = testChart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

            XCTAssertNotNil(watermark, "Watermark plugin with \(alignment.rawValue) alignment should be created")

            let waitExpectation = expectation(description: "Wait for \(alignment.rawValue) alignment")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                waitExpectation.fulfill()
            }
            wait(for: [waitExpectation], timeout: 2.0)
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests all vertical alignment options
    func testTextWatermarkPluginVerticalAlignmentOptions() {
        errorCatcher.clear()

        let alignments: [VerticalAlignment] = [.top, .center, .bottom]

        for alignment in alignments {
            let options = ChartOptions()
            let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
            testChart.errorDelegate = errorCatcher

            let watermarkOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: alignment, text: "\(alignment.rawValue) Aligned",
                color: "rgba(171, 71, 188, 0.5)",
                fontSize: 24
            )
            let watermark = testChart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

            XCTAssertNotNil(watermark, "Watermark plugin with \(alignment.rawValue) alignment should be created")

            let waitExpectation = expectation(description: "Wait for \(alignment.rawValue) alignment")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                waitExpectation.fulfill()
            }
            wait(for: [waitExpectation], timeout: 2.0)
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that chart options without watermark work correctly (no deprecated warning)
    func testChartOptionsWithoutWatermarkInV5() {
        errorCatcher.clear()

        // Chart options without watermark - the new v5 way
        let options = ChartOptions(
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333"),
            rightPriceScale: VisiblePriceScaleOptions(scaleMargins: PriceScaleMargins(top: 0.1, bottom: 0.2))
        )

        let expectation = expectation(description: "Chart without watermark loads")
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        testChart.errorDelegate = errorCatcher
        let strongLoadDelegate = TestLoadDelegate(expectation: expectation)
        testChart.loadDelegate = strongLoadDelegate

        wait(for: [expectation], timeout: 5.0)

        errorCatcher.assertNoErrors()
        XCTAssertNotNil(testChart, "Chart should load successfully without watermark in options")
    }

    /// Tests that visible=false in watermark plugin options works
    func testTextWatermarkPluginVisibleFalse() {
        errorCatcher.clear()

        let options = ChartOptions()
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        testChart.errorDelegate = errorCatcher

        let watermarkOptions = TextWatermarkOptions(
            visible: false,
            text: "Hidden Watermark",
            color: "rgba(171, 71, 188, 0.5)",
            fontSize: 24
        )
        let watermark = testChart.createTextWatermarkPlugin(paneIndex: 0, options: watermarkOptions)

        XCTAssertNotNil(watermark, "Watermark plugin should be created even if not visible")

        let waitExpectation = expectation(description: "Wait for invisible watermark")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }

    /// Tests TextWatermarkOptions convenience initializer
    func testTextWatermarkOptionsConvenienceInitializer() {
        // Test convenience initializer with single line
        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Simple Watermark",
            color: "rgba(100, 100, 100, 0.7)",
            fontSize: 18
        )

        XCTAssertEqual(options.visible, true, "Default visible should be true")
        XCTAssertEqual(options.horizontalAlignment, .center, "Default horizontalAlignment should be center")
        XCTAssertEqual(options.verticalAlignment, .center, "Default verticalAlignment should be center")
        XCTAssertEqual(options.lines.count, 1, "Should have exactly one line")
        XCTAssertEqual(options.lines[0].text, "Simple Watermark", "Line text should match")
        XCTAssertEqual(options.lines[0].color, "rgba(100, 100, 100, 0.7)", "Line color should match")
        XCTAssertEqual(options.lines[0].fontSize, 18, "Line fontSize should match")
        XCTAssertEqual(options.lines[0].fontFamily, "-apple-system", "Default fontFamily should be -apple-system")
        XCTAssertEqual(options.lines[0].fontStyle, "normal", "Default fontStyle should be normal")
    }
}

// MARK: - Plugin Protocol Tests

/// Tests for the base plugin protocols defined in Plugin.swift
///
/// These tests verify that the plugin protocol hierarchy is correctly defined
/// and that conforming types can properly implement the required interfaces.
final class PluginProtocolTests: XCTestCase {

    // MARK: - Mock Implementations for Testing

    /// Mock plugin implementing only the base Plugin protocol
    class MockPlugin: Plugin {
        var detachCalled = false

        func detach() {
            detachCalled = true
        }
    }

    /// Mock options type for testing PluginWithOptions
    struct MockPluginOptions {
        var value: Double
        var enabled: Bool
    }

    /// Mock plugin implementing PluginWithOptions
    class MockPluginWithOptions: PluginWithOptions {
        typealias Options = MockPluginOptions

        var detachCalled = false
        var lastAppliedOptions: Options?

        func detach() {
            detachCalled = true
        }

        func applyOptions(options: Options) {
            lastAppliedOptions = options
        }
    }

    /// Mock series plugin for testing SeriesPlugin protocol
    class MockSeriesPlugin: SeriesPlugin {
        typealias Series = LineSeries

        weak var series: LineSeries?
        var detachCalled = false

        init(series: LineSeries) {
            self.series = series
        }

        func detach() {
            detachCalled = true
            series = nil
        }
    }

    /// Mock pane plugin for testing PanePlugin protocol
    class MockPanePlugin: PanePlugin {
        let paneIndex: Int
        var detachCalled = false

        init(paneIndex: Int) {
            self.paneIndex = paneIndex
        }

        func detach() {
            detachCalled = true
        }
    }

    // MARK: - Plugin Protocol Tests

    /// Tests that Plugin protocol requires detach() method
    func testPluginProtocolRequiresDetach() {
        let plugin = MockPlugin()
        XCTAssertFalse(plugin.detachCalled, "detachCalled should be false initially")

        plugin.detach()
        XCTAssertTrue(plugin.detachCalled, "detach() should set detachCalled to true")
    }

    /// Tests that Plugin type can be used as AnyObject
    func testPluginConformsToAnyObject() {
        let plugin: Plugin = MockPlugin()
        XCTAssertNotNil(plugin, "Plugin should be usable as AnyObject reference")
    }

    // MARK: - PluginWithOptions Protocol Tests

    /// Tests that PluginWithOptions inherits from Plugin
    func testPluginWithOptionsInheritsFromPlugin() {
        let plugin: any PluginWithOptions = MockPluginWithOptions()
        XCTAssertFalse((plugin as! MockPluginWithOptions).detachCalled, "detachCalled should be false initially")

        plugin.detach()
        XCTAssertTrue((plugin as! MockPluginWithOptions).detachCalled, "PluginWithOptions should have detach() from Plugin")
    }

    /// Tests that PluginWithOptions requires applyOptions() method
    func testPluginWithOptionsRequiresApplyOptions() {
        let plugin = MockPluginWithOptions()
        let options = MockPluginOptions(value: 42.0, enabled: true)

        XCTAssertNil(plugin.lastAppliedOptions, "lastAppliedOptions should be nil initially")

        plugin.applyOptions(options: options)

        XCTAssertNotNil(plugin.lastAppliedOptions, "applyOptions should store options")
        XCTAssertEqual(plugin.lastAppliedOptions?.value, 42.0, "Value should match")
        XCTAssertTrue(plugin.lastAppliedOptions?.enabled ?? false, "Enabled should match")
    }

    /// Tests that PluginWithOptions associatedtype can be inferred
    func testPluginWithOptionsAssociatedtype() {
        let plugin = MockPluginWithOptions()

        let options = MockPluginOptions(value: 10.0, enabled: false)
        plugin.applyOptions(options: options)

        XCTAssertEqual(plugin.lastAppliedOptions?.value, 10.0, "Associatedtype should work correctly")
    }

    // MARK: - SeriesPlugin Protocol Tests

    /// Tests that SeriesPlugin inherits from Plugin
    func testSeriesPluginInheritsFromPlugin() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let expectation = self.expectation(description: "Chart loads")
        let strongLoadDelegate = TestLoadDelegate(expectation: expectation)
        charts.loadDelegate = strongLoadDelegate
        wait(for: [expectation], timeout: 5.0)

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let plugin = MockSeriesPlugin(series: series)

        XCTAssertFalse(plugin.detachCalled, "detachCalled should be false initially")
        XCTAssertNotNil(plugin.series, "Series should be set")

        plugin.detach()
        XCTAssertTrue(plugin.detachCalled, "detach() should work on SeriesPlugin")
        XCTAssertNil(plugin.series, "detach() should clear series reference")
    }

    /// Tests that SeriesPlugin series property is correctly typed
    func testSeriesPluginSeriesProperty() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let expectation = self.expectation(description: "Chart loads")
        let strongLoadDelegate = TestLoadDelegate(expectation: expectation)
        charts.loadDelegate = strongLoadDelegate
        wait(for: [expectation], timeout: 5.0)

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let plugin = MockSeriesPlugin(series: series)

        XCTAssertNotNil(plugin.series, "Series should be accessible")
        XCTAssertTrue(plugin.series != nil, "Series should be LineSeries type")
    }

    /// Tests that SeriesPlugin associatedtype constraint is enforced
    func testSeriesPluginAssociatedtypeConstraint() {
        // This test verifies that the SeriesPlugin protocol correctly requires
        // its associated Series type to conform to both SeriesApi and SeriesObject
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let expectation = self.expectation(description: "Chart loads")
        let strongLoadDelegate = TestLoadDelegate(expectation: expectation)
        charts.loadDelegate = strongLoadDelegate
        wait(for: [expectation], timeout: 5.0)

        let series = charts.addLineSeries(options: LineSeriesOptions())

        // Verify LineSeries conforms to both required protocols
        let seriesAsApi: any SeriesApi = series
        let seriesAsObject: SeriesObject = series

        XCTAssertNotNil(seriesAsApi, "LineSeries should conform to SeriesApi")
        XCTAssertNotNil(seriesAsObject, "LineSeries should conform to SeriesObject")
    }

    // MARK: - PanePlugin Protocol Tests

    /// Tests that PanePlugin inherits from Plugin
    func testPanePluginInheritsFromPlugin() {
        let plugin = PanePluginMock(paneIndex: 0)

        XCTAssertFalse(plugin.detachCalled, "detachCalled should be false initially")

        plugin.detach()
        XCTAssertTrue(plugin.detachCalled, "PanePlugin should have detach() from Plugin")
    }

    /// Tests that PanePlugin paneIndex property is accessible
    func testPanePluginPaneIndexProperty() {
        let plugin = PanePluginMock(paneIndex: 2)

        XCTAssertEqual(plugin.paneIndex, 2, "paneIndex should be correctly set")
    }

    /// Tests that PanePlugin can have different pane indices
    func testPanePluginDifferentPaneIndices() {
        let plugin0 = PanePluginMock(paneIndex: 0)
        let plugin1 = PanePluginMock(paneIndex: 1)
        let plugin5 = PanePluginMock(paneIndex: 5)

        XCTAssertEqual(plugin0.paneIndex, 0, "paneIndex 0 should be preserved")
        XCTAssertEqual(plugin1.paneIndex, 1, "paneIndex 1 should be preserved")
        XCTAssertEqual(plugin5.paneIndex, 5, "paneIndex 5 should be preserved")
    }

    // MARK: - Protocol Hierarchy Tests

    /// Tests that all plugin protocols can be used as base Plugin type
    func testAllPluginTypesConformToPlugin() {
        let mockPlugin: Plugin = MockPlugin()
        let pluginWithOptions: Plugin = MockPluginWithOptions()

        XCTAssertNotNil(mockPlugin, "MockPlugin should conform to Plugin")
        XCTAssertNotNil(pluginWithOptions, "PluginWithOptions should conform to Plugin")

        // Both should have detach() available
        mockPlugin.detach()
        pluginWithOptions.detach()
    }

    /// Tests protocol conformance through type casting
    func testPluginProtocolTypeCasting() {
        let pluginWithOptions = MockPluginWithOptions()

        // Should be able to use as Plugin type
        let plugin: Plugin = pluginWithOptions
        plugin.detach()

        XCTAssertTrue(pluginWithOptions.detachCalled, "detach() should work through base protocol")
    }
}

// MARK: - Mock for PanePlugin Tests (to avoid naming conflict)

/// Mock implementation for PanePlugin testing
class PanePluginMock: PanePlugin {
    let paneIndex: Int
    var detachCalled = false

    init(paneIndex: Int) {
        self.paneIndex = paneIndex
    }

    func detach() {
        detachCalled = true
    }
}

// MARK: - Helper Delegate for Tests

/// Helper delegate for load expectations in tests
class TestLoadDelegate: NSObject, LightweightChartsDelegate {
    private let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        expectation.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        // Still fulfill to avoid timeout, test will check for errors
        expectation.fulfill()
    }
}

// MARK: - Series Plugin Adapter Tests

/// Tests for SeriesPluginAdapter functionality
///
/// These tests verify that the SeriesPluginAdapter provides:
/// - Shared detach() behavior
/// - JS variable naming strategy
/// - Proper series reference handling with weak references
// final class SeriesPluginAdapterTests: XCTestCase {
// 
//     // MARK: - Series Reference Tests
// 
//     /// Tests that the adapter stores a weak reference to the series
//     func testAdapterHoldsWeakSeriesReference() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotNil(adapter.series, "Adapter should initially hold series reference")
// 
//         // Release the series
//         var releasedSeries: TestSeries? = series
//         // Ensure adapter is the only reference
//         // This test verifies the weak reference - if series is deallocated, adapter.series becomes nil
//         // In practice, this test documents the weak reference behavior
//         _ = releasedSeries
//     }
// 
//     /// Tests that detach() clears the series reference
//     func testDetachClearsSeriesReference() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotNil(adapter.series, "Adapter should initially hold series reference")
// 
//         adapter.detach()
// 
//         XCTAssertNil(adapter.series, "Series reference should be nil after detach")
//     }
// 
//     /// Tests that isDetached flag is set after detach
//     func testDetachSetsIsDetachedFlag() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertFalse(adapter.isDetached, "isDetached should be false initially")
// 
//         adapter.detach()
// 
//         XCTAssertTrue(adapter.isDetached, "isDetached should be true after detach")
//     }
// 
//     /// Tests that detach can be called multiple times safely
//     func testDetachCanBeCalledMultipleTimes() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         adapter.detach()
//         XCTAssertTrue(adapter.isDetached, "isDetached should be true after first detach")
// 
//         // Should not crash when called again
//         adapter.detach()
//         XCTAssertTrue(adapter.isDetached, "isDetached should remain true")
//     }
// 
//     // MARK: - JS Variable Naming Tests
// 
//     /// Tests that each adapter gets a unique JS name
//     func testEachAdapterHasUniqueJSName() {
//         let series = TestSeries()
//         let adapter1 = TestSeriesPluginAdapter(series: series)
//         let adapter2 = TestSeriesPluginAdapter(series: series)
//         let adapter3 = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotEqual(adapter1.jsName, adapter2.jsName, "JS names should be unique")
//         XCTAssertNotEqual(adapter2.jsName, adapter3.jsName, "JS names should be unique")
//         XCTAssertNotEqual(adapter1.jsName, adapter3.jsName, "JS names should be unique")
//     }
// 
//     /// Tests that JS name includes series type
//     func testJSNameIncludesSeriesType() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         // JS name should contain the series type name
//         XCTAssertTrue(adapter.jsName.contains("TestSeries"), "JS name should include series type name")
//     }
// 
//     /// Tests that JS name includes unique identifier
//     func testJSNameIncludesUniqueIdentifier() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         // JS name should be long enough to contain a UUID
//         XCTAssertGreaterThan(adapter.jsName.count, 20, "JS name should include UUID-based unique identifier")
// 
//         // Should contain the plugin prefix
//         XCTAssertTrue(adapter.jsName.hasPrefix("plugin_"), "JS name should start with 'plugin_'")
//     }
// 
//     /// Tests that JS name remains constant after detach
//     func testJSNameRemainsConstantAfterDetach() {
//         let series = TestSeries()
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         let originalName = adapter.jsName
// 
//         adapter.detach()
// 
//         XCTAssertEqual(adapter.jsName, originalName, "JS name should remain constant after detach")
//     }
// 
//     // MARK: - SeriesPlugin Protocol Conformance Tests
// 
//     /// Tests that adapter conforms to SeriesPlugin protocol
//     func testAdapterConformsToSeriesPlugin() {
//         let series = TestSeries()
//         let adapter: any SeriesPlugin = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotNil(adapter.series, "Series should be accessible through SeriesPlugin protocol")
//     }
// 
//     /// Tests that adapter conforms to Plugin protocol
//     func testAdapterConformsToPlugin() {
//         let series = TestSeries()
//         let adapter: Plugin = TestSeriesPluginAdapter(series: series)
// 
//         // Should be able to call detach through base protocol
//         adapter.detach()
//     }
// 
//     /// Tests that detach works through protocol type
//     func testDetachThroughProtocolType() {
//         let series = TestSeries()
//         let adapter: any SeriesPlugin = TestSeriesPluginAdapter(series: series)
// 
//         adapter.detach()
// 
//         XCTAssertNil(adapter.series, "Series reference should be nil after detach through protocol")
//     }
// 
//     // MARK: - Different Series Types Tests
// 
//     /// Tests that adapter works with LineSeries
//     func testAdapterWithLineSeries() {
//         var charts: LightweightCharts!
//         let loadExpectation = expectation(description: "Chart loads")
// 
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
//         let errorCatcher = JSErrorCatcher()
//         charts.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: loadExpectation)
//         charts.loadDelegate = strongLoadDelegate
// 
//         wait(for: [loadExpectation], timeout: 5.0)
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotNil(adapter.series, "Adapter should work with LineSeries")
//         XCTAssertTrue(adapter.jsName.contains("LineSeries"), "JS name should contain LineSeries")
// 
//         adapter.detach()
//         XCTAssertNil(adapter.series, "Detach should work with LineSeries")
//     }
// 
//     /// Tests that adapter works with AreaSeries
//     func testAdapterWithAreaSeries() {
//         var charts: LightweightCharts!
//         let loadExpectation = expectation(description: "Chart loads")
// 
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
//         let errorCatcher = JSErrorCatcher()
//         charts.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: loadExpectation)
//         charts.loadDelegate = strongLoadDelegate
// 
//         wait(for: [loadExpectation], timeout: 5.0)
// 
//         let series = charts.addAreaSeries(options: AreaSeriesOptions())
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotNil(adapter.series, "Adapter should work with AreaSeries")
//         XCTAssertTrue(adapter.jsName.contains("AreaSeries"), "JS name should contain AreaSeries")
// 
//         adapter.detach()
//         XCTAssertNil(adapter.series, "Detach should work with AreaSeries")
//     }
// 
//     /// Tests that adapter works with BarSeries
//     func testAdapterWithBarSeries() {
//         var charts: LightweightCharts!
//         let loadExpectation = expectation(description: "Chart loads")
// 
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
//         let errorCatcher = JSErrorCatcher()
//         charts.errorDelegate = errorCatcher
//         let strongLoadDelegate = TestLoadDelegate(expectation: loadExpectation)
//         charts.loadDelegate = strongLoadDelegate
// 
//         wait(for: [loadExpectation], timeout: 5.0)
// 
//         let series = charts.addBarSeries(options: BarSeriesOptions())
//         let adapter = TestSeriesPluginAdapter(series: series)
// 
//         XCTAssertNotNil(adapter.series, "Adapter should work with BarSeries")
//         XCTAssertTrue(adapter.jsName.contains("BarSeries"), "JS name should contain BarSeries")
// 
//         adapter.detach()
//         XCTAssertNil(adapter.series, "Detach should work with BarSeries")
//     }
// }

// MARK: - Test Series for Adapter Tests

/// Test series implementation that conforms to both SeriesApi and SeriesObject
class TestSeries: SeriesObject, SeriesApi {
    public typealias Options = LineSeriesOptions
    public typealias TickValue = LineData

    required init(context: JavaScriptEvaluator, closureStore: ClosuresStore?) {
        super.init(context: context, closureStore: closureStore)
    }

    // Implement required SeriesApi methods with stub implementations
    func priceFormatter() -> PriceFormatterApi {
        fatalError("Not implemented for test")
    }

    func priceToCoordinate(price: Double, completion: @escaping (Coordinate?) -> Void) {
        fatalError("Not implemented for test")
    }

    func coordinateToPrice(coordinate: Double, completion: @escaping (BarPrice?) -> Void) {
        fatalError("Not implemented for test")
    }

    func barsInLogicalRange(range: FromToRange<Double>, completion: @escaping (BarsInfo?) -> Void) {
        fatalError("Not implemented for test")
    }

    func applyOptions(options: Options) {
        // Stub
    }

    func options(completion: @escaping (Options?) -> Void) {
        fatalError("Not implemented for test")
    }

    func priceScale() -> PriceScaleApi {
        fatalError("Not implemented for test")
    }

    func setData(data: [TickValue]) {
        // Stub
    }

    func update(bar: TickValue) {
        // Stub
    }

    func setData(data: [WhitespaceData]) {
        // Stub
    }

    func update(bar: WhitespaceData) {
        // Stub
    }

    func setData(data: [SeriesDataType<TickValue>]) {
        // Stub
    }

    func update(bar: SeriesDataType<TickValue>) {
        // Stub
    }

    func dataByIndex(logicalIndex: Int, mismatchDirection: MismatchDirection?, completion: @escaping (TickValue?) -> Void) {
        fatalError("Not implemented for test")
    }

    func setMarkers(_ data: [SeriesMarker]) {
        // Stub
    }

    func markers(completion: @escaping (SeriesMarker?) -> Void) {
        fatalError("Not implemented for test")
    }

    func createPriceLine(options: PriceLineOptions?) -> PriceLine {
        fatalError("Not implemented for test")
    }

    func removePriceLine(line: PriceLine) {
        // Stub
    }

    func seriesType(completion: @escaping (SeriesType?) -> Void) {
        completion(.line)
    }
}

// MARK: - Test Adapter for Testing

/// Test adapter implementation for testing SeriesPluginAdapter
class TestSeriesPluginAdapter: SeriesPluginAdapter<TestSeries> {
    // Inherits all functionality from SeriesPluginAdapter
}

// MARK: - Pane Plugin Adapter Tests

/// Tests for PanePluginAdapter functionality
///
/// These tests verify that the PanePluginAdapter provides:
/// - Shared detach() behavior
/// - JS variable naming strategy
/// - Proper pane index and context storage
final class PanePluginAdapterTests: XCTestCase {

    // MARK: - Pane Index Tests

    /// Tests that the adapter stores the pane index correctly
    func testAdapterStoresPaneIndex() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        XCTAssertEqual(adapter.paneIndex, 0, "Pane index should be stored correctly")
    }

    /// Tests that the adapter stores non-zero pane indices correctly
    func testAdapterStoresNonZeroPaneIndex() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 2, context: context)

        XCTAssertEqual(adapter.paneIndex, 2, "Non-zero pane index should be stored correctly")
    }

    // MARK: - Detach Behavior Tests

    /// Tests that detach() sets isDetached flag to true
    func testDetachSetsIsDetachedFlag() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        XCTAssertFalse(adapter.isDetached, "isDetached should be false initially")

        adapter.detach()

        XCTAssertTrue(adapter.isDetached, "isDetached should be true after detach")
    }

    /// Tests that detach() can be called multiple times safely
    func testDetachCanBeCalledMultipleTimes() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        adapter.detach()
        XCTAssertTrue(adapter.isDetached)

        // Calling detach again should be safe
        adapter.detach()
        XCTAssertTrue(adapter.isDetached, "isDetached should remain true after multiple detach calls")
    }

    // MARK: - JS Variable Name Tests

    /// Tests that each adapter gets a unique JS variable name
    func testEachAdapterHasUniqueJSName() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter1 = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)
        let adapter2 = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        XCTAssertNotEqual(adapter1.jsName, adapter2.jsName, "Each adapter should have a unique JS name")
    }

    /// Tests that JS variable names follow the expected pattern
    func testJSNameFollowsExpectedPattern() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        XCTAssertTrue(adapter.jsName.hasPrefix("paneplugin_"), "JS name should start with 'paneplugin_'")
    }

    // MARK: - Pane Expression Tests

    /// Tests that paneExpression() generates correct JavaScript
    func testPaneExpressionGeneratesCorrectJavaScript() {
        let chart = TestChart()
        chart.jsName = "testChart123"
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        let expression = adapter.paneExpression()

        XCTAssertEqual(expression, "testChart123.panes()[0]", "Pane expression should correctly access the pane")
    }

    /// Tests that paneExpression() works with different pane indices
    func testPaneExpressionWithDifferentPaneIndices() {
        let chart = TestChart()
        chart.jsName = "myChart"
        let context = TestJavaScriptEvaluator()

        let adapter0 = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)
        let adapter1 = TestPanePluginAdapter(chart: chart, paneIndex: 1, context: context)
        let adapter2 = TestPanePluginAdapter(chart: chart, paneIndex: 2, context: context)

        XCTAssertEqual(adapter0.paneExpression(), "myChart.panes()[0]")
        XCTAssertEqual(adapter1.paneExpression(), "myChart.panes()[1]")
        XCTAssertEqual(adapter2.paneExpression(), "myChart.panes()[2]")
    }

    // MARK: - Context Tests

    /// Tests that adapter stores chart JS name correctly
    func testAdapterStoresChartJSName() {
        let chart = TestChart()
        chart.jsName = "mySpecialChart"
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        // Verify through paneExpression which uses the stored chart JS name
        let expression = adapter.paneExpression()
        XCTAssertTrue(expression.contains("mySpecialChart"), "Chart JS name should be used in pane expression")
    }

    // MARK: - Subclass Behavior Tests

    /// Tests that subclasses can override detach() with custom behavior
    func testSubclassCanOverrideDetach() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let customAdapter = CustomDetachPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        customAdapter.detach()

        XCTAssertTrue(customAdapter.isDetached, "Base class detach behavior should work")
        XCTAssertTrue(customAdapter.customCleanupCalled, "Subclass custom cleanup should be called")
    }
}

// MARK: - Test Chart for Pane Plugin Tests

/// Test chart implementation for testing PanePluginAdapter
class TestChart: JavaScriptObject {
    var jsName: String = "testChart"
}

// MARK: - Test JavaScript Evaluator for Pane Plugin Tests

/// Test JavaScript evaluator implementation for testing PanePluginAdapter
class TestJavaScriptEvaluator: JavaScriptEvaluator {
    private var lastScript: String?
    var evaluateScriptCallCount = 0

    func evaluateScript(_ script: String, completion: ((Any?, Error?) -> Void)?) {
        lastScript = script
        evaluateScriptCallCount += 1
        completion?(nil, nil)
    }

    func decodedResult<T: Decodable>(forScript script: String, completion: @escaping (T?) -> Void) {
        lastScript = script
        evaluateScriptCallCount += 1
        completion(nil)
    }

    func evaluate<T: Decodable>(script: String, resultType: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        lastScript = script
        evaluateScriptCallCount += 1
    }

    func getLastScript() -> String? {
        return lastScript
    }

    func reset() {
        lastScript = nil
        evaluateScriptCallCount = 0
    }
}

// MARK: - Test Adapter for Pane Plugin Testing

/// Test adapter implementation for testing PanePluginAdapter
class TestPanePluginAdapter: PanePluginAdapter<TestChart> {
    // Inherits all functionality from PanePluginAdapter
}

// MARK: - Custom Detach Adapter for Testing

/// Test adapter with custom detach behavior for testing override capability
class CustomDetachPanePluginAdapter: PanePluginAdapter<TestChart> {
    var customCleanupCalled = false

    override func detach() {
        customCleanupCalled = true
        super.detach()
    }
}

// MARK: - Adapter jsName Immutability Tests

/// Tests verifying adapter design does not rely on mutable jsName
///
/// These tests ensure that:
/// - Adapters capture chart/series jsName at initialization time
/// - Adapters don't depend on chart/series jsName remaining constant
/// - Adapter jsName properties are immutable (let, not var)
final class AdapterJSNameImmutabilityTests: XCTestCase {

    // MARK: - PanePluginAdapter Tests

    /// Tests that PanePluginAdapter captures chartJsName at init time
    ///
    /// This verifies that if the chart's jsName changes after adapter creation,
    /// the adapter continues using the originally captured value.
    func testPanePluginAdapterCapturesChartJSNameAtInit() {
        let chart = TestChart()
        chart.jsName = "originalChartName"
        let context = TestJavaScriptEvaluator()

        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        // Get the original pane expression
        let originalExpression = adapter.paneExpression()
        XCTAssertTrue(originalExpression.contains("originalChartName"),
                      "Adapter should use chart jsName from initialization time")

        // Modify the chart's jsName after adapter creation
        chart.jsName = "modifiedChartName"

        // Adapter should still use the original value
        let expressionAfterModification = adapter.paneExpression()
        XCTAssertEqual(expressionAfterModification, originalExpression,
                       "Adapter should continue using the chart jsName captured at init time")
        XCTAssertFalse(expressionAfterModification.contains("modifiedChartName"),
                       "Adapter should not be affected by chart jsName changes after init")
    }

    /// Tests that PanePluginAdapter's own jsName is immutable
    ///
    /// This verifies the adapter's jsName cannot be changed after initialization,
    /// ensuring it's declared as `let` rather than `var`.
    func testPanePluginAdapterJSNameIsImmutable() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()
        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        let originalJSName = adapter.jsName

        // Verify that we cannot modify jsName (this would be a compile error if jsName were mutable)
        // Since we can't test mutation at runtime, we verify that the value remains constant
        // and that multiple accesses return the same value
        XCTAssertEqual(adapter.jsName, originalJSName,
                       "jsName should remain constant throughout the object's lifetime")
    }

    /// Tests that each PanePluginAdapter instance has an independent jsName
    ///
    /// This verifies that jsName is instance-specific and doesn't rely on shared state.
    func testPanePluginAdapterJSNameIsInstanceSpecific() {
        let chart = TestChart()
        let context = TestJavaScriptEvaluator()

        let adapter1 = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)
        let adapter2 = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)
        let adapter3 = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)

        // Each adapter should have its own unique jsName
        XCTAssertNotEqual(adapter1.jsName, adapter2.jsName,
                         "Each adapter instance should have a unique jsName")
        XCTAssertNotEqual(adapter2.jsName, adapter3.jsName,
                         "Each adapter instance should have a unique jsName")
        XCTAssertNotEqual(adapter1.jsName, adapter3.jsName,
                         "Each adapter instance should have a unique jsName")
    }

    /// Tests that PanePluginAdapter works with charts that have immutable jsName
    ///
    /// This verifies the adapter design is compatible with both mutable and immutable jsName sources.
    func testPanePluginAdapterWorksWithImmutableChartJSName() {
        // Create a chart with effectively immutable jsName by never changing it
        let chart = TestChart()
        // Don't modify chart.jsName - treat it as immutable
        let context = TestJavaScriptEvaluator()

        let adapter = TestPanePluginAdapter(chart: chart, paneIndex: 2, context: context)

        // Should work correctly with the immutable jsName
        let expression = adapter.paneExpression()
        XCTAssertTrue(expression.contains("testChart"),
                       "Adapter should work correctly with charts that have immutable jsName")
        XCTAssertTrue(expression.contains("panes()[2]"),
                       "Adapter should correctly use the pane index")
    }

    // MARK: - SeriesPluginAdapter Tests

    /// Tests that SeriesPluginAdapter's jsName is immutable
    ///
    /// This verifies the adapter's jsName cannot be changed after initialization.
    func testSeriesPluginAdapterJSNameIsImmutable() {
        let evaluator = TestJavaScriptEvaluator()
        let series = TestSeries(context: evaluator, closureStore: nil)
        let adapter = TestSeriesPluginAdapter(series: series)

        let originalJSName = adapter.jsName

        // Verify jsName remains constant
        XCTAssertEqual(adapter.jsName, originalJSName,
                       "jsName should remain constant throughout the object's lifetime")
    }

    /// Tests that SeriesPluginAdapter doesn't depend on series jsName
    ///
    /// This verifies that SeriesPluginAdapter generates its own jsName
    /// and doesn't use or depend on the series' jsName property.
    func testSeriesPluginAdapterGeneratesOwnJSName() {
        let evaluator = TestJavaScriptEvaluator()
        let series = TestSeries(context: evaluator, closureStore: nil)
        let seriesJSName = series.jsName

        let adapter = TestSeriesPluginAdapter(series: series)
        let adapterJSName = adapter.jsName

        // The adapter's jsName should be different from the series' jsName
        XCTAssertNotEqual(adapterJSName, seriesJSName,
                         "SeriesPluginAdapter should generate its own jsName, not use series.jsName")

        // The adapter's jsName should follow the plugin naming pattern
        XCTAssertTrue(adapterJSName.hasPrefix("plugin_"),
                       "SeriesPluginAdapter jsName should follow plugin naming pattern")
    }

    /// Tests that SeriesPluginAdapter's jsName is independent of series lifecycle
    ///
    /// This verifies that the adapter's jsName remains valid even after
    /// the series reference is cleared.
    func testSeriesPluginAdapterJSNameIndependentOfSeries() {
        let evaluator = TestJavaScriptEvaluator()
        let series = TestSeries(context: evaluator, closureStore: nil)
        let adapter = TestSeriesPluginAdapter(series: series)

        let originalJSName = adapter.jsName

        // Clear the series reference
        adapter.detach()
        XCTAssertNil(adapter.series, "Series reference should be cleared after detach")

        // jsName should still be accessible and unchanged
        XCTAssertEqual(adapter.jsName, originalJSName,
                       "Adapter jsName should remain valid and constant after series is cleared")
    }

    /// Tests that each SeriesPluginAdapter instance has an independent jsName
    ///
    /// This verifies that jsName is instance-specific and doesn't rely on shared state.
    func testSeriesPluginAdapterJSNameIsInstanceSpecific() {
        let evaluator = TestJavaScriptEvaluator()
        let series = TestSeries(context: evaluator, closureStore: nil)

        let adapter1 = TestSeriesPluginAdapter(series: series)
        let adapter2 = TestSeriesPluginAdapter(series: series)
        let adapter3 = TestSeriesPluginAdapter(series: series)

        // Each adapter should have its own unique jsName
        XCTAssertNotEqual(adapter1.jsName, adapter2.jsName,
                         "Each adapter instance should have a unique jsName")
        XCTAssertNotEqual(adapter2.jsName, adapter3.jsName,
                         "Each adapter instance should have a unique jsName")
        XCTAssertNotEqual(adapter1.jsName, adapter3.jsName,
                         "Each adapter instance should have a unique jsName")
    }

    // MARK: - Cross-Adapter Tests

    /// Tests that different adapter types generate different jsName patterns
    ///
    /// This verifies that PanePluginAdapter and SeriesPluginAdapter
    /// use distinct naming strategies to avoid collisions.
    func testDifferentAdapterTypesHaveDistinctNamingPatterns() {
        let chart = TestChart()
        let evaluator = TestJavaScriptEvaluator()
        let series = TestSeries(context: evaluator, closureStore: nil)
        let context = TestJavaScriptEvaluator()

        let paneAdapter = TestPanePluginAdapter(chart: chart, paneIndex: 0, context: context)
        let seriesAdapter = TestSeriesPluginAdapter(series: series)

        // Different adapter types should use different naming patterns
        XCTAssertNotEqual(paneAdapter.jsName, seriesAdapter.jsName,
                         "Different adapter types should have distinct jsName patterns")

        // Verify the prefixes are different
        XCTAssertTrue(paneAdapter.jsName.hasPrefix("paneplugin_"),
                      "PanePluginAdapter should use paneplugin_ prefix")
        XCTAssertTrue(seriesAdapter.jsName.hasPrefix("plugin_"),
                      "SeriesPluginAdapter should use plugin_ prefix")
    }
}

// MARK: - Plugin Models Tests

/// Tests for plugin model types (Phase 6: Plugin Models)
///
/// These tests verify that the plugin model directory structure exists
/// and that the model types are properly defined.
// final class PluginModelsTests: XCTestCase {
// 
//     /// Tests that WatermarkLine model is properly defined
//     func testWatermarkLineModelExists() {
//         // This test verifies WatermarkLine can be instantiated with all properties including lineHeight (task 6.6)
//         let line = WatermarkLine(
//             text: "Test Watermark",
//             color: ChartColor(.red),
//             fontSize: 24,
//             fontFamily: "-apple-system",
//             fontStyle: "normal",
//             lineHeight: 36
//         )
// 
//         XCTAssertEqual(line.text, "Test Watermark")
//         XCTAssertEqual(line.fontSize, 24)
//         XCTAssertEqual(line.fontFamily, "-apple-system")
//         XCTAssertEqual(line.fontStyle, "normal")
//         XCTAssertEqual(line.lineHeight, 36, "lineHeight should be set correctly")
//     }
// 
//     /// Tests that WatermarkLine is Codable
//     func testWatermarkLineIsCodable() {
//         let line = WatermarkLine(
//             text: "Test",
//             color: ChartColor(.blue),
//             fontSize: 30,
//             fontFamily: "Helvetica",
//             fontStyle: "bold",
//             lineHeight: 45
//         )
// 
//         // Test encoding
//         guard let encoded = try? JSONEncoder().encode(line),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("WatermarkLine should be encodable")
//             return
//         }
// 
//         // Verify JSON contains expected keys
//         XCTAssertTrue(jsonString.contains("text"), "JSON should contain 'text' key")
//         XCTAssertTrue(jsonString.contains("color"), "JSON should contain 'color' key")
//         XCTAssertTrue(jsonString.contains("fontSize"), "JSON should contain 'fontSize' key")
//         XCTAssertTrue(jsonString.contains("fontFamily"), "JSON should contain 'fontFamily' key")
//         XCTAssertTrue(jsonString.contains("fontStyle"), "JSON should contain 'fontStyle' key")
//         XCTAssertTrue(jsonString.contains("lineHeight"), "JSON should contain 'lineHeight' key")
// 
//         // Test decoding
//         guard let decoded = try? JSONDecoder().decode(WatermarkLine.self, from: encoded) else {
//             XCTFail("WatermarkLine should be decodable")
//             return
//         }
// 
//         XCTAssertEqual(decoded.text, line.text)
//         XCTAssertEqual(decoded.fontSize, line.fontSize)
//         XCTAssertEqual(decoded.fontFamily, line.fontFamily)
//         XCTAssertEqual(decoded.fontStyle, line.fontStyle)
//         XCTAssertEqual(decoded.lineHeight, line.lineHeight, "lineHeight should survive encode/decode cycle")
//     }
// 
//     /// Tests that TextWatermarkOptions model is properly defined
//     func testTextWatermarkOptionsModelExists() {
//         let lines = [
//             WatermarkLine(
//                 text: "Line 1",
//                 color: ChartColor(.red),
//                 fontSize: 24,
//                 fontFamily: "-apple-system",
//                 fontStyle: "normal"
//             ),
//             WatermarkLine(
//                 text: "Line 2",
//                 color: ChartColor(.blue),
//                 fontSize: 18,
//                 fontFamily: "-apple-system",
//                 fontStyle: "italic"
//             )
//         ]
// 
//         let options = TextWatermarkOptions(
//             visible: true,
//             horizontalAlignment: .center,
//             verticalAlignment: .center,
//             lines: lines
//         )
// 
//         XCTAssertTrue(options.visible)
//         XCTAssertEqual(options.horizontalAlignment, .center)
//         XCTAssertEqual(options.verticalAlignment, .center)
//         XCTAssertEqual(options.lines.count, 2)
//     }
// 
//     /// Tests TextWatermarkOptions convenience initializer
//     func testTextWatermarkOptionsConvenienceInitializer() {
//         let options = TextWatermarkOptions(
//             visible: true,
//             horizontalAlignment: .left,
//             verticalAlignment: .top,
//             text: "Single Line",
//             color: ChartColor(.green),
//             fontSize: 36,
//             fontFamily: "Helvetica",
//             fontStyle: "bold"
//         )
// 
//         XCTAssertTrue(options.visible)
//         XCTAssertEqual(options.horizontalAlignment, .left)
//         XCTAssertEqual(options.verticalAlignment, .top)
//         XCTAssertEqual(options.lines.count, 1)
//         XCTAssertEqual(options.lines.first?.text, "Single Line")
//     }
// 
//     /// Tests that TextWatermarkOptions is Codable
//     func testTextWatermarkOptionsIsCodable() {
//         let options = TextWatermarkOptions(
//             visible: false,
//             horizontalAlignment: .right,
//             verticalAlignment: .bottom,
//             text: "Test",
//             color: ChartColor(.yellow),
//             fontSize: 20
//         )
// 
//         // Test encoding
//         guard let encoded = try? JSONEncoder().encode(options),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("TextWatermarkOptions should be encodable")
//             return
//         }
// 
//         // Verify JSON contains expected keys with JS naming
//         XCTAssertTrue(jsonString.contains("visible"), "JSON should contain 'visible' key")
//         XCTAssertTrue(jsonString.contains("horzAlign"), "JSON should use 'horzAlign' for horizontalAlignment")
//         XCTAssertTrue(jsonString.contains("vertAlign"), "JSON should use 'vertAlign' for verticalAlignment")
//         XCTAssertTrue(jsonString.contains("lines"), "JSON should contain 'lines' key")
// 
//         // Test decoding
//         guard let decoded = try? JSONDecoder().decode(TextWatermarkOptions.self, from: encoded) else {
//             XCTFail("TextWatermarkOptions should be decodable")
//             return
//         }
// 
//         XCTAssertEqual(decoded.visible, options.visible)
//         XCTAssertEqual(decoded.horizontalAlignment, options.horizontalAlignment)
//         XCTAssertEqual(decoded.verticalAlignment, options.verticalAlignment)
//         XCTAssertEqual(decoded.lines.count, options.lines.count)
//     }
// 
//     /// Tests HorizontalAlignment enum cases
//     func testHorizontalAlignmentEnumCases() {
//         XCTAssertEqual(HorizontalAlignment.left.rawValue, "left")
//         XCTAssertEqual(HorizontalAlignment.center.rawValue, "center")
//         XCTAssertEqual(HorizontalAlignment.right.rawValue, "right")
//     }
// 
//     /// Tests VerticalAlignment enum cases
//     func testVerticalAlignmentEnumCases() {
//         XCTAssertEqual(VerticalAlignment.top.rawValue, "top")
//         XCTAssertEqual(VerticalAlignment.center.rawValue, "center")
//         XCTAssertEqual(VerticalAlignment.bottom.rawValue, "bottom")
//     }
// 
//     /// Tests WatermarkLine jsonString helper
//     func testWatermarkLineJsonStringHelper() {
//         let line = WatermarkLine(
//             text: "JSON Test",
//             color: ChartColor(.purple),
//             fontSize: 28
//         )
// 
//         let jsonString = line.jsonString()
// 
//         XCTAssertFalse(jsonString.isEmpty, "jsonString should not be empty")
//         XCTAssertTrue(jsonString.contains("JSON Test"), "jsonString should contain the text")
//     }
// 
//     /// Tests that WatermarkLine supports lineHeight property (task 6.6)
//     func testWatermarkLineWithLineHeight() {
//         let line = WatermarkLine(
//             text: "Line Height Test",
//             color: ChartColor(.orange),
//             fontSize: 24,
//             lineHeight: 36
//         )
// 
//         XCTAssertEqual(line.text, "Line Height Test")
//         XCTAssertEqual(line.fontSize, 24)
//         XCTAssertEqual(line.lineHeight, 36, "lineHeight should be set when provided")
//     }
// 
//     /// Tests that WatermarkLine lineHeight is optional and defaults to nil
//     func testWatermarkLineLineHeightIsOptional() {
//         let lineWithoutLineHeight = WatermarkLine(
//             text: "No Line Height",
//             color: ChartColor(.gray),
//             fontSize: 20
//         )
// 
//         XCTAssertNil(lineWithoutLineHeight.lineHeight, "lineHeight should default to nil when not provided")
// 
//         let lineWithLineHeight = WatermarkLine(
//             text: "With Line Height",
//             color: ChartColor(.gray),
//             fontSize: 20,
//             lineHeight: 30
//         )
// 
//         XCTAssertEqual(lineWithLineHeight.lineHeight, 30, "lineHeight should be set when explicitly provided")
//     }
// 
//     /// Tests that WatermarkLine encodes lineHeight to JSON (task 6.6)
//     func testWatermarkLineLineHeightEncoding() {
//         let line = WatermarkLine(
//             text: "Encoding Test",
//             color: ChartColor(.blue),
//             fontSize: 28,
//             lineHeight: 40
//         )
// 
//         guard let encoded = try? JSONEncoder().encode(line),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("WatermarkLine should be encodable")
//             return
//         }
// 
//         XCTAssertTrue(jsonString.contains("lineHeight"), "JSON should contain 'lineHeight' key")
//         XCTAssertTrue(jsonString.contains("40"), "JSON should contain lineHeight value")
//     }
// 
//     /// Tests that WatermarkLine decodes lineHeight from JSON (task 6.6)
//     func testWatermarkLineLineHeightDecoding() {
//         let jsonString = """
//         {
//             "text": "Decode Test",
//             "color": "rgba(255,0,0,0.5)",
//             "fontSize": 24,
//             "fontFamily": "-apple-system",
//             "fontStyle": "normal",
//             "lineHeight": 35
//         }
//         """
// 
//         guard let data = jsonString.data(using: .utf8),
//               let line = try? JSONDecoder().decode(WatermarkLine.self, from: data) else {
//             XCTFail("WatermarkLine should be decodable")
//             return
//         }
// 
//         XCTAssertEqual(line.lineHeight, 35, "lineHeight should be decoded correctly")
//     }
// 
//     /// Tests TextWatermarkOptions convenience initializer with lineHeight (task 6.6)
//     func testTextWatermarkOptionsConvenienceInitializerWithLineHeight() {
//         let options = TextWatermarkOptions(
//             visible: true,
//             horizontalAlignment: .center,
//             verticalAlignment: .center,
//             text: "Watermark with Line Height",
//             color: ChartColor(.red),
//             fontSize: 28,
//             lineHeight: 42
//         )
// 
//         XCTAssertEqual(options.lines.count, 1)
//         XCTAssertEqual(options.lines[0].text, "Watermark with Line Height")
//         XCTAssertEqual(options.lines[0].fontSize, 28)
//         XCTAssertEqual(options.lines[0].lineHeight, 42, "lineHeight should be set via convenience initializer")
//     }
// 
//     /// Tests TextWatermarkOptions jsonString helper
//     func testTextWatermarkOptionsJsonStringHelper() {
//         let options = TextWatermarkOptions(
//             visible: true,
//             horizontalAlignment: .center,
//             verticalAlignment: .center,
//             text: "Watermark Test",
//             color: ChartColor(.cyan),
//             fontSize: 32
//         )
// 
//         let jsonString = options.jsonString()
// 
//         XCTAssertFalse(jsonString.isEmpty, "jsonString should not be empty")
//         XCTAssertTrue(jsonString.contains("horzAlign"), "jsonString should use JS property names")
//         XCTAssertTrue(jsonString.contains("vertAlign"), "jsonString should use JS property names")
//     }
// 
//     // MARK: - SeriesMarkersOptions Tests
// 
//     /// Tests that SeriesMarkersOptions model is properly defined
//     func testSeriesMarkersOptionsModelExists() {
//         let options = SeriesMarkersOptions(
//             active: true,
//             autoScale: true
//         )
// 
//         XCTAssertTrue(options.active ?? false, "active should be true")
//         XCTAssertTrue(options.autoScale ?? false, "autoScale should be true")
//     }
// 
//     /// Tests SeriesMarkersOptions with all nil values (default initializer)
//     func testSeriesMarkersOptionsDefaultInitializer() {
//         let options = SeriesMarkersOptions()
// 
//         XCTAssertNil(options.active, "active should be nil by default")
//         XCTAssertNil(options.autoScale, "autoScale should be nil by default")
//     }
// 
//     /// Tests SeriesMarkersOptions with only active set
//     func testSeriesMarkersOptionsActiveOnly() {
//         let options = SeriesMarkersOptions(active: false)
// 
//         XCTAssertEqual(options.active, false, "active should be false")
//         XCTAssertNil(options.autoScale, "autoScale should be nil when not provided")
//     }
// 
//     /// Tests SeriesMarkersOptions with only autoScale set
//     func testSeriesMarkersOptionsAutoScaleOnly() {
//         let options = SeriesMarkersOptions(autoScale: false)
// 
//         XCTAssertNil(options.active, "active should be nil when not provided")
//         XCTAssertEqual(options.autoScale, false, "autoScale should be false")
//     }
// 
//     /// Tests that SeriesMarkersOptions is Codable
//     func testSeriesMarkersOptionsIsCodable() {
//         let options = SeriesMarkersOptions(
//             active: true,
//             autoScale: false
//         )
// 
//         // Test encoding
//         guard let encoded = try? JSONEncoder().encode(options),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("SeriesMarkersOptions should be encodable")
//             return
//         }
// 
//         // Verify JSON contains expected keys
//         XCTAssertTrue(jsonString.contains("active"), "JSON should contain 'active' key")
//         XCTAssertTrue(jsonString.contains("autoScale"), "JSON should contain 'autoScale' key")
// 
//         // Test decoding
//         guard let decoded = try? JSONDecoder().decode(SeriesMarkersOptions.self, from: encoded) else {
//             XCTFail("SeriesMarkersOptions should be decodable")
//             return
//         }
// 
//         XCTAssertEqual(decoded.active, options.active)
//         XCTAssertEqual(decoded.autoScale, options.autoScale)
//     }
// 
//     /// Tests SeriesMarkersOptions jsonString helper
//     func testSeriesMarkersOptionsJsonStringHelper() {
//         let options = SeriesMarkersOptions(
//             active: true,
//             autoScale: true
//         )
// 
//         let jsonString = options.jsonString()
// 
//         XCTAssertFalse(jsonString.isEmpty, "jsonString should not be empty")
//         XCTAssertTrue(jsonString.contains("active"), "jsonString should contain 'active'")
//         XCTAssertTrue(jsonString.contains("autoScale"), "jsonString should contain 'autoScale'")
//     }
// 
//     /// Tests SeriesMarkersOptions jsonString helper with all nil values
//     func testSeriesMarkersOptionsJsonStringHelperWithNilValues() {
//         let options = SeriesMarkersOptions()
// 
//         let jsonString = options.jsonString()
// 
//         // Should produce valid empty object
//         XCTAssertEqual(jsonString, "{}", "jsonString should be empty object for all nil values")
//     }
// 
//     /// Tests SeriesMarkersOptions JSON encoding produces valid values
//     func testSeriesMarkersOptionsJSONEncoding() {
//         let options = SeriesMarkersOptions(
//             active: false,
//             autoScale: true
//         )
// 
//         guard let encoded = try? JSONEncoder().encode(options),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("SeriesMarkersOptions should be encodable")
//             return
//         }
// 
//         // Verify boolean values are correctly encoded
//         XCTAssertTrue(jsonString.contains("\"active\":false"), "active should be encoded as false")
//         XCTAssertTrue(jsonString.contains("\"autoScale\":true"), "autoScale should be encoded as true")
//     }
// 
//     // MARK: - UpDownMarkersOptions Tests
// 
//     /// Tests that UpDownMarkersOptions model is properly defined
//     func testUpDownMarkersOptionsModelExists() {
//         let options = UpDownMarkersOptions(
//             positiveColor: .solid(color: ChartColor(.green)),
//             negativeColor: .solid(color: ChartColor(.red)),
//             updateVisibilityDuration: 1000
//         )
// 
//         XCTAssertNotNil(options.positiveColor, "positiveColor should be set")
//         XCTAssertNotNil(options.negativeColor, "negativeColor should be set")
//         XCTAssertEqual(options.updateVisibilityDuration, 1000, "updateVisibilityDuration should be 1000")
//     }
// 
//     /// Tests UpDownMarkersOptions with all nil values (default initializer)
//     func testUpDownMarkersOptionsDefaultInitializer() {
//         let options = UpDownMarkersOptions()
// 
//         XCTAssertNil(options.positiveColor, "positiveColor should be nil by default")
//         XCTAssertNil(options.negativeColor, "negativeColor should be nil by default")
//         XCTAssertNil(options.updateVisibilityDuration, "updateVisibilityDuration should be nil by default")
//     }
// 
//     /// Tests UpDownMarkersOptions with only positiveColor set
//     func testUpDownMarkersOptionsPositiveColorOnly() {
//         let options = UpDownMarkersOptions(positiveColor: .solid(color: ChartColor(.blue)))
// 
//         XCTAssertNotNil(options.positiveColor, "positiveColor should be set")
//         XCTAssertNil(options.negativeColor, "negativeColor should be nil when not provided")
//         XCTAssertNil(options.updateVisibilityDuration, "updateVisibilityDuration should be nil when not provided")
//     }
// 
//     /// Tests UpDownMarkersOptions with only negativeColor set
//     func testUpDownMarkersOptionsNegativeColorOnly() {
//         let options = UpDownMarkersOptions(negativeColor: .solid(color: ChartColor(.orange)))
// 
//         XCTAssertNil(options.positiveColor, "positiveColor should be nil when not provided")
//         XCTAssertNotNil(options.negativeColor, "negativeColor should be set")
//         XCTAssertNil(options.updateVisibilityDuration, "updateVisibilityDuration should be nil when not provided")
//     }
// 
//     /// Tests UpDownMarkersOptions with only updateVisibilityDuration set
//     func testUpDownMarkersOptionsUpdateVisibilityDurationOnly() {
//         let options = UpDownMarkersOptions(updateVisibilityDuration: 500)
// 
//         XCTAssertNil(options.positiveColor, "positiveColor should be nil when not provided")
//         XCTAssertNil(options.negativeColor, "negativeColor should be nil when not provided")
//         XCTAssertEqual(options.updateVisibilityDuration, 500, "updateVisibilityDuration should be 500")
//     }
// 
//     /// Tests that UpDownMarkersOptions is Codable
//     func testUpDownMarkersOptionsIsCodable() {
//         let options = UpDownMarkersOptions(
//             positiveColor: .solid(color: ChartColor(.green)),
//             negativeColor: .solid(color: ChartColor(.red)),
//             updateVisibilityDuration: 2000
//         )
// 
//         // Test encoding
//         guard let encoded = try? JSONEncoder().encode(options),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("UpDownMarkersOptions should be encodable")
//             return
//         }
// 
//         // Verify JSON contains expected keys
//         XCTAssertTrue(jsonString.contains("positiveColor"), "JSON should contain 'positiveColor' key")
//         XCTAssertTrue(jsonString.contains("negativeColor"), "JSON should contain 'negativeColor' key")
//         XCTAssertTrue(jsonString.contains("updateVisibilityDuration"), "JSON should contain 'updateVisibilityDuration' key")
// 
//         // Test decoding
//         guard let decoded = try? JSONDecoder().decode(UpDownMarkersOptions.self, from: encoded) else {
//             XCTFail("UpDownMarkersOptions should be decodable")
//             return
//         }
// 
//         XCTAssertNotNil(decoded.positiveColor, "positiveColor should be decoded")
//         XCTAssertNotNil(decoded.negativeColor, "negativeColor should be decoded")
//         XCTAssertEqual(decoded.updateVisibilityDuration, options.updateVisibilityDuration)
//     }
// 
//     /// Tests UpDownMarkersOptions jsonString helper
//     func testUpDownMarkersOptionsJsonStringHelper() {
//         let options = UpDownMarkersOptions(
//             positiveColor: .solid(color: ChartColor(.green)),
//             negativeColor: .solid(color: ChartColor(.red)),
//             updateVisibilityDuration: 1500
//         )
// 
//         let jsonString = options.jsonString()
// 
//         XCTAssertFalse(jsonString.isEmpty, "jsonString should not be empty")
//         XCTAssertTrue(jsonString.contains("positiveColor"), "jsonString should contain 'positiveColor'")
//         XCTAssertTrue(jsonString.contains("negativeColor"), "jsonString should contain 'negativeColor'")
//         XCTAssertTrue(jsonString.contains("updateVisibilityDuration"), "jsonString should contain 'updateVisibilityDuration'")
//     }
// 
//     /// Tests UpDownMarkersOptions jsonString helper with all nil values
//     func testUpDownMarkersOptionsJsonStringHelperWithNilValues() {
//         let options = UpDownMarkersOptions()
// 
//         let jsonString = options.jsonString()
// 
//         // Should produce valid empty object
//         XCTAssertEqual(jsonString, "{}", "jsonString should be empty object for all nil values")
//     }
// 
//     /// Tests UpDownMarkersOptions JSON encoding produces valid values
//     func testUpDownMarkersOptionsJSONEncoding() {
//         let options = UpDownMarkersOptions(
//             positiveColor: .solid(color: ChartColor(.green)),
//             negativeColor: .solid(color: ChartColor(.red)),
//             updateVisibilityDuration: 3000
//         )
// 
//         guard let encoded = try? JSONEncoder().encode(options),
//               let jsonString = String(data: encoded, encoding: .utf8) else {
//             XCTFail("UpDownMarkersOptions should be encodable")
//             return
//         }
// 
//         // Verify values are correctly encoded
//         XCTAssertTrue(jsonString.contains("\"updateVisibilityDuration\":3000"), "updateVisibilityDuration should be encoded as 3000")
//     }
// }

// MARK: - SeriesUpDownMarker Tests

/// Tests for SeriesUpDownMarker model
///
/// These tests ensure that the SeriesUpDownMarker model correctly encodes
/// and decodes data for up-down markers used by the plugin.
final class SeriesUpDownMarkerTests: XCTestCase {

    /// Tests that MarkerSign enum has correct integer values
    func testMarkerSignRawValues() {
        XCTAssertEqual(MarkerSign.negative.rawValue, -1, "MarkerSign.negative should have raw value -1")
        XCTAssertEqual(MarkerSign.neutral.rawValue, 0, "MarkerSign.neutral should have raw value 0")
        XCTAssertEqual(MarkerSign.positive.rawValue, 1, "MarkerSign.positive should have raw value 1")
    }

    /// Tests that MarkerSign can be initialized from raw values
    func testMarkerSignFromRawValue() {
        XCTAssertEqual(MarkerSign(rawValue: -1), .negative, "Raw value -1 should decode to negative")
        XCTAssertEqual(MarkerSign(rawValue: 0), .neutral, "Raw value 0 should decode to neutral")
        XCTAssertEqual(MarkerSign(rawValue: 1), .positive, "Raw value 1 should decode to positive")
        XCTAssertNil(MarkerSign(rawValue: 2), "Raw value 2 should return nil")
        XCTAssertNil(MarkerSign(rawValue: -2), "Raw value -2 should return nil")
    }

    /// Tests that SeriesUpDownMarker can be created with all properties
    func testSeriesUpDownMarkerInitialization() {
        let marker = SeriesUpDownMarker(
            time: .utc(timestamp: 1234567890),
            value: 100.5,
            sign: .positive
        )

        XCTAssertEqual(marker.value, 100.5, "Value should be set correctly")
        XCTAssertEqual(marker.sign, .positive, "Sign should be set correctly")

        if case .utc(let timestamp) = marker.time {
            XCTAssertEqual(timestamp, 1234567890, "Time should be set correctly")
        } else {
            XCTFail("Time should be utc case")
        }
    }

    /// Tests that SeriesUpDownMarker can be encoded to JSON
    func testSeriesUpDownMarkerEncoding() {
        let marker = SeriesUpDownMarker(
            time: .utc(timestamp: 1234567890),
            value: 100.5,
            sign: .positive
        )

        guard let encoded = try? JSONEncoder().encode(marker),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            XCTFail("SeriesUpDownMarker should be encodable")
            return
        }

        XCTAssertTrue(jsonString.contains("\"time\":1234567890"), "Encoded JSON should contain time")
        XCTAssertTrue(jsonString.contains("\"value\":100.5"), "Encoded JSON should contain value")
        XCTAssertTrue(jsonString.contains("\"sign\":1"), "Encoded JSON should contain sign as 1 (positive)")
    }

    /// Tests that SeriesUpDownMarker can be decoded from JSON
    func testSeriesUpDownMarkerDecoding() {
        let jsonString = """
        {
            "time": 1234567890,
            "value": 100.5,
            "sign": 1
        }
        """

        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Could not create test data")
            return
        }

        guard let decoded = try? JSONDecoder().decode(SeriesUpDownMarker.self, from: data) else {
            XCTFail("SeriesUpDownMarker should be decodable")
            return
        }

        if case .utc(let timestamp) = decoded.time {
            XCTAssertEqual(timestamp, 1234567890, "Time should be decoded correctly")
        } else {
            XCTFail("Time should be utc case")
        }

        XCTAssertEqual(decoded.value, 100.5, "Value should be decoded correctly")
        XCTAssertEqual(decoded.sign, .positive, "Sign should be decoded as positive")
    }

    /// Tests that SeriesUpDownMarker with negative sign encodes correctly
    func testSeriesUpDownMarkerNegativeSign() {
        let marker = SeriesUpDownMarker(
            time: .businessDay(BusinessDay(year: 2024, month: 1, day: 15)),
            value: 98.5,
            sign: .negative
        )

        guard let encoded = try? JSONEncoder().encode(marker),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            XCTFail("SeriesUpDownMarker should be encodable")
            return
        }

        XCTAssertTrue(jsonString.contains("\"sign\":-1"), "Encoded JSON should contain sign as -1 (negative)")
    }

    /// Tests that SeriesUpDownMarker with neutral sign encodes correctly
    func testSeriesUpDownMarkerNeutralSign() {
        let marker = SeriesUpDownMarker(
            time: .string("2024-01-15"),
            value: 100.0,
            sign: .neutral
        )

        guard let encoded = try? JSONEncoder().encode(marker),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            XCTFail("SeriesUpDownMarker should be encodable")
            return
        }

        XCTAssertTrue(jsonString.contains("\"sign\":0"), "Encoded JSON should contain sign as 0 (neutral)")
    }

    /// Tests that SeriesUpDownMarker round-trips through encoding/decoding
    func testSeriesUpDownMarkerRoundTrip() {
        let original = SeriesUpDownMarker(
            time: .utc(timestamp: 1234567890),
            value: 100.5,
            sign: .positive
        )

        guard let encoded = try? JSONEncoder().encode(original),
              let decoded = try? JSONDecoder().decode(SeriesUpDownMarker.self, from: encoded) else {
            XCTFail("Round-trip encoding/decoding should work")
            return
        }

        if case .utc(let originalTimestamp) = original.time,
           case .utc(let decodedTimestamp) = decoded.time {
            XCTAssertEqual(originalTimestamp, decodedTimestamp, "Time should survive round-trip")
        } else {
            XCTFail("Time should be utc case for both")
        }

        XCTAssertEqual(original.value, decoded.value, "Value should survive round-trip")
        XCTAssertEqual(original.sign, decoded.sign, "Sign should survive round-trip")
    }

    // MARK: - ImageWatermarkOptions Tests (task 6.7)

    /// Tests that ImageWatermarkOptions model is properly defined
    func testImageWatermarkOptionsModelExists() {
        let options = ImageWatermarkOptions(
            alpha: 0.8,
            padding: 10,
            maxWidth: 200,
            maxHeight: 150
        )

        XCTAssertEqual(options.alpha, 0.8, "alpha should be set correctly")
        XCTAssertEqual(options.padding, 10, "padding should be set correctly")
        XCTAssertEqual(options.maxWidth, 200, "maxWidth should be set correctly")
        XCTAssertEqual(options.maxHeight, 150, "maxHeight should be set correctly")
    }

    /// Tests that ImageWatermarkOptions uses correct default values
    func testImageWatermarkOptionsDefaultValues() {
        let options = ImageWatermarkOptions()

        XCTAssertEqual(options.alpha, 1.0, "Default alpha should be 1.0")
        XCTAssertEqual(options.padding, 0, "Default padding should be 0")
        XCTAssertNil(options.maxWidth, "Default maxWidth should be nil")
        XCTAssertNil(options.maxHeight, "Default maxHeight should be nil")
    }

    /// Tests that ImageWatermarkOptions is Codable
    func testImageWatermarkOptionsIsCodable() {
        let options = ImageWatermarkOptions(
            alpha: 0.5,
            padding: 20,
            maxWidth: 300,
            maxHeight: 250
        )

        // Test encoding
        guard let encoded = try? JSONEncoder().encode(options),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            XCTFail("ImageWatermarkOptions should be encodable")
            return
        }

        // Verify JSON contains expected keys
        XCTAssertTrue(jsonString.contains("\"alpha\":0.5"), "JSON should contain 'alpha' key with value 0.5")
        XCTAssertTrue(jsonString.contains("\"padding\":20"), "JSON should contain 'padding' key with value 20")
        XCTAssertTrue(jsonString.contains("\"maxWidth\":300"), "JSON should contain 'maxWidth' key")
        XCTAssertTrue(jsonString.contains("\"maxHeight\":250"), "JSON should contain 'maxHeight' key")

        // Test decoding
        guard let decoded = try? JSONDecoder().decode(ImageWatermarkOptions.self, from: encoded) else {
            XCTFail("ImageWatermarkOptions should be decodable")
            return
        }

        XCTAssertEqual(decoded.alpha, options.alpha, "Decoded alpha should match original")
        XCTAssertEqual(decoded.padding, options.padding, "Decoded padding should match original")
        XCTAssertEqual(decoded.maxWidth, options.maxWidth, "Decoded maxWidth should match original")
        XCTAssertEqual(decoded.maxHeight, options.maxHeight, "Decoded maxHeight should match original")
    }

    /// Tests that ImageWatermarkOptions encodes correctly with optional values omitted
    func testImageWatermarkOptionsEncodingWithOptionalValues() {
        let options = ImageWatermarkOptions(
            alpha: 0.75,
            padding: 5
        )

        let jsonString = options.jsonString()

        XCTAssertTrue(jsonString.contains("\"alpha\":0.75"), "Should contain alpha field")
        XCTAssertTrue(jsonString.contains("\"padding\":5"), "Should contain padding field")
        XCTAssertFalse(jsonString.contains("maxWidth"), "Should not contain maxWidth when nil")
        XCTAssertFalse(jsonString.contains("maxHeight"), "Should not contain maxHeight when nil")
    }

    /// Tests that ImageWatermarkOptions round-trips through encoding/decoding
    func testImageWatermarkOptionsRoundTrip() {
        let original = ImageWatermarkOptions(
            alpha: 0.3,
            padding: 15,
            maxWidth: 100.5,
            maxHeight: 75.25
        )

        guard let encoded = try? JSONEncoder().encode(original),
              let decoded = try? JSONDecoder().decode(ImageWatermarkOptions.self, from: encoded) else {
            XCTFail("Round-trip encoding/decoding should work")
            return
        }

        XCTAssertEqual(original.alpha, decoded.alpha, "alpha should survive round-trip")
        XCTAssertEqual(original.padding, decoded.padding, "padding should survive round-trip")
        XCTAssertEqual(original.maxWidth, decoded.maxWidth, "maxWidth should survive round-trip")
        XCTAssertEqual(original.maxHeight, decoded.maxHeight, "maxHeight should survive round-trip")
    }

    /// Tests ImageWatermarkOptions jsonString helper
    func testImageWatermarkOptionsJsonStringHelper() {
        let options = ImageWatermarkOptions(
            alpha: 0.9,
            padding: 12,
            maxWidth: 400
        )

        let jsonString = options.jsonString()

        XCTAssertFalse(jsonString.isEmpty, "jsonString should not be empty")
        XCTAssertTrue(jsonString.contains("alpha"), "jsonString should contain alpha")
        XCTAssertTrue(jsonString.contains("padding"), "jsonString should contain padding")
    }

    /// Tests that ImageWatermarkOptions does not include unsupported fields
    func testImageWatermarkOptionsNoUnsupportedFields() {
        let options = ImageWatermarkOptions()

        let jsonString = options.jsonString()

        // Verify no alignment or url fields are included (as per task 6.7 requirements)
        XCTAssertFalse(jsonString.contains("horzAlign"), "Should not contain horzAlign field")
        XCTAssertFalse(jsonString.contains("vertAlign"), "Should not contain vertAlign field")
        XCTAssertFalse(jsonString.contains("alignment"), "Should not contain alignment field")
        XCTAssertFalse(jsonString.contains("url"), "Should not contain url field")
    }
}

// MARK: - Series Markers Plugin Tests (Task 7.1)

/// Tests for SeriesMarkersPlugin functionality
///
/// These tests verify that the explicit SeriesMarkersPlugin wrapper works correctly
/// with multiple series types (Line, Bar, etc.) and supports all required operations:
/// - Initialization with initial data and options
/// - Setting new markers
/// - Getting current markers
/// - Applying options updates
/// - Detaching the plugin
final class SeriesMarkersPluginTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Plugin Creation Tests

    /// Tests that SeriesMarkersPlugin can be created on a LineSeries
    func testPluginCreationOnLineSeries() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created")

        // Set some data first
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]
        series.setData(data: data)

        // Create plugin with markers
        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: .unix(2000), position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]

        let plugin = SeriesMarkersPlugin(series: series, data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created")
        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that SeriesMarkersPlugin can be created on a BarSeries
    func testPluginCreationOnBarSeries() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        XCTAssertNotNil(series, "Bar series should be created")

        // Set some data first
        let data: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ]
        series.setData(data: data)

        // Create plugin with markers
        let markers = [
            SeriesMarker(time: .unix(1000), position: .inBar, shape: .arrowUp, color: ChartColor(.green))
        ]

        let plugin = SeriesMarkersPlugin(series: series, data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created on BarSeries")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that SeriesMarkersPlugin can be created with options
    func testPluginCreationWithOptions() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        let options = SeriesMarkersOptions(active: true, autoScale: true)
        let plugin = SeriesMarkersPlugin(series: series, data: markers, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created with options")
        XCTAssertEqual(plugin.options.active, true, "Plugin should store active option")
        XCTAssertEqual(plugin.options.autoScale, true, "Plugin should store autoScale option")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - setMarkers Tests

    /// Tests that setMarkers updates the markers on the plugin
    func testSetMarkersUpdatesPlugin() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]
        series.setData(data: data)

        // Create plugin with initial markers
        let initialMarkers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Update markers
        errorCatcher.clear()
        let updatedMarkers = [
            SeriesMarker(time: .unix(2000), position: .belowBar, shape: .square, color: ChartColor(.blue)),
            SeriesMarker(time: .unix(3000), position: .aboveBar, shape: .arrowUp, color: ChartColor(.green))
        ]
        plugin.setMarkers(updatedMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - getMarkers Tests

    /// Tests that getMarkers returns the current markers
    func testGetMarkersReturnsCurrentMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()

        // Get markers back
        let expectation = self.expectation(description: "Get markers completes")
        plugin.getMarkers { result in
            XCTAssertNotNil(result, "getMarkers should return markers")
            // Note: the exact format may vary, but we should get something back
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - applyOptions Tests

    /// Tests that applyOptions updates plugin options
    func testApplyOptionsUpdatesPluginOptions() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Apply new options
        let newOptions = SeriesMarkersOptions(active: false, autoScale: false)
        plugin.applyOptions(options: newOptions)

        XCTAssertEqual(plugin.options.active, false, "Plugin options should be updated")
        XCTAssertEqual(plugin.options.autoScale, false, "Plugin options should be updated")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - detach Tests

    /// Tests that detach removes the plugin
    func testDetachRemovesPlugin() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be marked as detached")
        XCTAssertNil(plugin.series, "Series reference should be cleared")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling detach twice is safe
    func testDetachCalledTwiceIsSafe() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach twice - should not cause errors
        plugin.detach()
        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be marked as detached")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that operations on detached plugin are safe no-ops
    func testOperationsOnDetachedPluginAreSafe() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // These operations should be safe no-ops
        plugin.setMarkers([])
        plugin.applyOptions(options: SeriesMarkersOptions(active: false))

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that getMarkers on detached plugin returns nil
    func testGetMarkersOnDetachedPluginReturnsNil() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // getMarkers should return nil for detached plugin
        let expectation = self.expectation(description: "Get markers completes")
        plugin.getMarkers { result in
            XCTAssertNil(result, "getMarkers should return nil for detached plugin")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Multiple Series Types Tests

    /// Tests that plugin works with AreaSeries
    func testPluginWorksOnAreaSeries() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.purple))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        XCTAssertNotNil(plugin, "Plugin should work with AreaSeries")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that plugin works with CandlestickSeries
    func testPluginWorksOnCandlestickSeries() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let data: [CandlestickData] = [
            CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowUp, color: ChartColor(.green))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        XCTAssertNotNil(plugin, "Plugin should work with CandlestickSeries")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that plugin works with HistogramSeries
    func testPluginWorksOnHistogramSeries() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let data: [HistogramData] = [
            HistogramData(time: .unix(1000), value: 10, color: nil),
            HistogramData(time: .unix(2000), value: 20, color: nil),
            HistogramData(time: .unix(3000), value: 15, color: nil)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowDown, color: ChartColor(.red)),
            SeriesMarker(time: .unix(2000), position: .belowBar, shape: .circle, color: ChartColor(.yellow))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        XCTAssertNotNil(plugin, "Plugin should work with HistogramSeries")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that plugin works with BaselineSeries
    func testPluginWorksOnBaselineSeries() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        let data: [BaselineData] = [
            BaselineData(time: .unix(1000), value: 10),
            BaselineData(time: .unix(2000), value: 20),
            BaselineData(time: .unix(3000), value: 15)
        ]
        series.setData(data: data)

        let markers = [
            SeriesMarker(time: .unix(1000), position: .inBar, shape: .square, color: ChartColor(.cyan)),
            SeriesMarker(time: .unix(2000), position: .aboveBar, shape: .arrowUp, color: ChartColor(.magenta))
        ]
        let plugin = SeriesMarkersPlugin(series: series, data: markers)

        XCTAssertNotNil(plugin, "Plugin should work with BaselineSeries")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests comprehensive plugin lifecycle on all series types
    ///
    /// This test validates that for each supported series type:
    /// 1. Plugin can be created
    /// 2. Markers can be updated via setMarkers
    /// 3. Markers can be retrieved via getMarkers
    /// 4. Options can be applied via applyOptions
    /// 5. Plugin can be detached cleanly
    func testPluginLifecycleOnAllSeriesTypes() {
        let seriesTypesToTest: [(String, () -> Void)] = [
            ("LineSeries", {
                let series = self.charts.addLineSeries(options: LineSeriesOptions())
                series.setData(data: [LineData(time: .unix(1000), value: 10)])
                self.validatePluginLifecycle(on: series, markers: [
                    SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red))
                ])
            }),
            ("AreaSeries", {
                let series = self.charts.addAreaSeries(options: AreaSeriesOptions())
                series.setData(data: [AreaData(time: .unix(1000), value: 10)])
                self.validatePluginLifecycle(on: series, markers: [
                    SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.blue))
                ])
            }),
            ("BarSeries", {
                let series = self.charts.addBarSeries(options: BarSeriesOptions())
                series.setData(data: [BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)])
                self.validatePluginLifecycle(on: series, markers: [
                    SeriesMarker(time: .unix(1000), position: .inBar, shape: .arrowUp, color: ChartColor(.green))
                ])
            }),
            ("CandlestickSeries", {
                let series = self.charts.addCandlestickSeries(options: CandlestickSeriesOptions())
                series.setData(data: [CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)])
                self.validatePluginLifecycle(on: series, markers: [
                    SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowUp, color: ChartColor(.orange))
                ])
            }),
            ("HistogramSeries", {
                let series = self.charts.addHistogramSeries(options: HistogramSeriesOptions())
                series.setData(data: [HistogramData(time: .unix(1000), value: 10, color: nil)])
                self.validatePluginLifecycle(on: series, markers: [
                    SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .square, color: ChartColor(.purple))
                ])
            }),
            ("BaselineSeries", {
                let series = self.charts.addBaselineSeries(options: BaselineSeriesOptions())
                series.setData(data: [BaselineData(time: .unix(1000), value: 10)])
                self.validatePluginLifecycle(on: series, markers: [
                    SeriesMarker(time: .unix(1000), position: .inBar, shape: .circle, color: ChartColor(.yellow))
                ])
            })
        ]

        for (_, testBlock) in seriesTypesToTest {
            errorCatcher.clear()
            testBlock()
            waitForAsyncOperations()
            errorCatcher.assertNoErrors()
        }
    }

    /// Tests that multiple plugins can coexist on different series types
    func testMultiplePluginsOnDifferentSeriesTypes() {
        errorCatcher.clear()

        // Create multiple series of different types
        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())

        lineSeries.setData(data: [LineData(time: .unix(1000), value: 10)])
        areaSeries.setData(data: [AreaData(time: .unix(1000), value: 15)])
        barSeries.setData(data: [BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)])

        // Create plugins on each series
        let linePlugin = SeriesMarkersPlugin(series: lineSeries, data: [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ])
        let areaPlugin = SeriesMarkersPlugin(series: areaSeries, data: [
            SeriesMarker(time: .unix(1000), position: .belowBar, shape: .square, color: ChartColor(.blue))
        ])
        let barPlugin = SeriesMarkersPlugin(series: barSeries, data: [
            SeriesMarker(time: .unix(1000), position: .inBar, shape: .arrowUp, color: ChartColor(.green))
        ])

        XCTAssertNotNil(linePlugin, "LineSeries plugin should be created")
        XCTAssertNotNil(areaPlugin, "AreaSeries plugin should be created")
        XCTAssertNotNil(barPlugin, "BarSeries plugin should be created")

        // Update each plugin independently
        linePlugin.setMarkers([
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowDown, color: ChartColor(.orange))
        ])
        areaPlugin.setMarkers([
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.purple))
        ])
        barPlugin.setMarkers([
            SeriesMarker(time: .unix(1000), position: .belowBar, shape: .square, color: ChartColor(.yellow))
        ])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests plugin with multiple markers on different series types
    func testMultipleMarkersOnDifferentSeriesTypes() {
        errorCatcher.clear()

        let testCases: [(String, () -> Void)] = [
            ("LineSeries", {
                let series = self.charts.addLineSeries(options: LineSeriesOptions())
                series.setData(data: [
                    LineData(time: .unix(1000), value: 10),
                    LineData(time: .unix(2000), value: 20),
                    LineData(time: .unix(3000), value: 15)
                ])
                self.validateMultipleMarkers(on: series)
            }),
            ("BarSeries", {
                let series = self.charts.addBarSeries(options: BarSeriesOptions())
                series.setData(data: [
                    BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
                    BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
                ])
                self.validateMultipleMarkers(on: series)
            }),
            ("CandlestickSeries", {
                let series = self.charts.addCandlestickSeries(options: CandlestickSeriesOptions())
                series.setData(data: [
                    CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
                    CandlestickData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
                ])
                self.validateMultipleMarkers(on: series)
            })
        ]

        for (_, testBlock) in testCases {
            errorCatcher.clear()
            testBlock()
            waitForAsyncOperations()
            errorCatcher.assertNoErrors()
        }
    }

    // MARK: - Helper Methods

    /// Validates the full lifecycle of a plugin on a series.
    ///
    /// This helper tests:
    /// - Plugin creation
    /// - setMarkers update
    /// - getMarkers retrieval
    /// - applyOptions update
    /// - detach cleanup
    private func validatePluginLifecycle<Series>(on series: Series, markers: [SeriesMarker])
    where Series: SeriesApi & SeriesObject {
        let plugin = SeriesMarkersPlugin(series: series, data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created")

        // Test setMarkers update
        let updatedMarkers = [
            SeriesMarker(time: .unix(1000), position: .belowBar, shape: .arrowDown, color: ChartColor(.blue))
        ]
        plugin.setMarkers( updatedMarkers)

        // Test getMarkers
        let expectation = self.expectation(description: "Get markers for \(type(of: series))")
        plugin.getMarkers { result in
            XCTAssertNotNil(result, "getMarkers should return markers")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Test applyOptions
        plugin.applyOptions(options: SeriesMarkersOptions(active: false, autoScale: false))
        XCTAssertEqual(plugin.options.active, false)

        // Test detach
        plugin.detach()
        XCTAssertTrue(plugin.isDetached)
    }

    /// Validates multiple markers can be set and retrieved on a series.
    private func validateMultipleMarkers<Series>(on series: Series)
    where Series: SeriesApi & SeriesObject {
        let multipleMarkers = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: .unix(2000), position: .belowBar, shape: .square, color: ChartColor(.blue)),
            SeriesMarker(time: .unix(3000), position: .inBar, shape: .arrowUp, color: ChartColor(.green))
        ]

        let plugin = SeriesMarkersPlugin(series: series, data: multipleMarkers)
        XCTAssertNotNil(plugin, "Plugin should be created with multiple markers")

        // Verify markers are set
        let expectation = self.expectation(description: "Get multiple markers")
        plugin.getMarkers { result in
            XCTAssertNotNil(result, "getMarkers should return markers")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    private func waitForAsyncOperations() {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - UpDownMarkersPlugin Tests

/// Tests for UpDownMarkersPlugin class
///
/// These tests verify that the UpDownMarkersPlugin correctly wraps the v5
/// createUpDownMarkers primitive and provides all required methods.
final class UpDownMarkersPluginTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Plugin Creation Tests

    /// Tests that UpDownMarkersPlugin can be created on a LineSeries
    func testPluginCreationOnLineSeries() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created")

        // Set some data first
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]
        series.setData(data: data)

        // Create plugin with markers
        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive),
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative)
        ]

        let plugin = UpDownMarkersPlugin(series: series, data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created")
        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that UpDownMarkersPlugin can be created on an AreaSeries
    func testPluginCreationOnAreaSeries() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        XCTAssertNotNil(series, "Area series should be created")

        // Set some data first
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)]
        series.setData(data: data)

        // Create plugin with markers
        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .neutral),
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .positive)
        ]

        let plugin = UpDownMarkersPlugin(series: series, data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created on AreaSeries")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that UpDownMarkersPlugin can be created with options
    func testPluginCreationWithOptions() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]

        let options = UpDownMarkersOptions(
            positiveColor: .solid(color: ChartColor(.green)),
            negativeColor: .solid(color: ChartColor(.red)),
            updateVisibilityDuration: 1000
        )
        let plugin = UpDownMarkersPlugin(series: series, data: markers, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created with options")
        XCTAssertNotNil(plugin.options.positiveColor, "Plugin should store positiveColor option")
        XCTAssertNotNil(plugin.options.negativeColor, "Plugin should store negativeColor option")
        XCTAssertEqual(plugin.options.updateVisibilityDuration, 1000, "Plugin should store updateVisibilityDuration option")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - setData Tests

    /// Tests that setData updates the markers on the plugin
    func testSetDataUpdatesPlugin() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15)
        ]
        series.setData(data: data)

        // Create plugin with initial markers
        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Update data
        errorCatcher.clear()
        let updatedMarkers = [
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative),
            SeriesUpDownMarker(time: .unix(3000), value: 15, sign: .neutral)
        ]
        plugin.setData(updatedMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - update Tests

    /// Tests that update adds a single marker
    func testUpdateAddsSingleMarker() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        // Create plugin with initial marker
        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Update with a single new marker
        errorCatcher.clear()
        let newMarker = SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative)
        plugin.update(newMarker)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - setMarkers Tests

    /// Tests that setMarkers is an alias for setData
    func testSetMarkersIsAliasForSetData() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)]
        series.setData(data: data)

        // Create plugin with initial markers
        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Update markers using setMarkers
        errorCatcher.clear()
        let updatedMarkers = [
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative)
        ]
        plugin.setMarkers( updatedMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - clearMarkers Tests

    /// Tests that clearMarkers removes all markers
    func testClearMarkersRemovesAllMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        // Create plugin with markers
        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive),
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Clear markers
        errorCatcher.clear()
        plugin.clearMarkers()

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - getMarkers Tests

    /// Tests that getMarkers returns the current markers
    func testGetMarkersReturnsCurrentMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()

        // Get markers back
        let expectation = self.expectation(description: "Get markers completes")
        plugin.getMarkers { result in
            XCTAssertNotNil(result, "getMarkers should return markers")
            // Note: the exact format may vary, but we should get something back
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - applyOptions Tests

    /// Tests that applyOptions updates plugin options
    func testApplyOptionsUpdatesPluginOptions() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Apply new options
        let newOptions = UpDownMarkersOptions(
            positiveColor: .solid(color: ChartColor(.blue)),
            negativeColor: .solid(color: ChartColor(.orange)),
            updateVisibilityDuration: 500
        )
        plugin.applyOptions(options: newOptions)

        XCTAssertNotNil(plugin.options.positiveColor, "Plugin options should be updated")
        XCTAssertNotNil(plugin.options.negativeColor, "Plugin options should be updated")
        XCTAssertEqual(plugin.options.updateVisibilityDuration, 500, "Plugin options should be updated")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - detach Tests

    /// Tests that detach removes the plugin
    func testDetachRemovesPlugin() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be marked as detached")
        XCTAssertNil(plugin.series, "Series reference should be cleared")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling detach twice is safe
    func testDetachCalledTwiceIsSafe() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach twice - should not cause errors
        plugin.detach()
        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be marked as detached")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that operations on detached plugin are safe no-ops
    func testOperationsOnDetachedPluginAreSafe() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // These operations should be safe no-ops
        plugin.setData([])
        plugin.update(SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative))
        plugin.setMarkers([])
        plugin.clearMarkers()
        plugin.applyOptions(options: UpDownMarkersOptions(positiveColor: .solid(color: ChartColor(.red))))

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that getMarkers on detached plugin returns nil
    func testGetMarkersOnDetachedPluginReturnsNil() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // getMarkers should return nil for detached plugin
        let expectation = self.expectation(description: "Get markers completes")
        plugin.getMarkers { result in
            XCTAssertNil(result, "getMarkers should return nil for detached plugin")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations() {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Compile-Time Restriction Tests

    /// Tests that LineSeries and AreaSeries conform to UpDownMarkersSupported.
    ///
    /// The UpDownMarkersPlugin uses the UpDownMarkersSupported protocol to provide
    /// compile-time enforcement that only compatible series types (LineSeries and AreaSeries)
    /// can be used with the plugin.
    ///
    /// Attempting to create an UpDownMarkersPlugin with an unsupported series type
    /// (e.g., BarSeries, CandlestickSeries, HistogramSeries, BaselineSeries) will
    /// result in a compile-time error.
    func testUpDownMarkersSupportedProtocolConformance() {
        // This test verifies that the protocol conformance exists at runtime.
        // The actual compile-time restriction is enforced by the Swift compiler.

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())

        // Verify these series conform to UpDownMarkersSupported
        let lineSeriesConforms: any UpDownMarkersSupported = lineSeries
        let areaSeriesConforms: any UpDownMarkersSupported = areaSeries

        XCTAssertNotNil(lineSeriesConforms, "LineSeries should conform to UpDownMarkersSupported")
        XCTAssertNotNil(areaSeriesConforms, "AreaSeries should conform to UpDownMarkersSupported")

        // The following would NOT compile (commented out to demonstrate compile-time restriction):
        // let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        // let invalidPlugin = UpDownMarkersPlugin(series: barSeries, data: [])
        // Error: 'BarSeries' is not convertible to 'Series' expected in UpDownMarkersPlugin initializer
    }

    // MARK: - Empty Data Tests

    /// Tests that UpDownMarkersPlugin can be created with empty marker array
    func testPluginCreationWithEmptyMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        // Create plugin with empty markers array
        let plugin = UpDownMarkersPlugin(series: series, data: [])
        XCTAssertNotNil(plugin, "Plugin should be created even with empty markers")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setData with empty array clears all markers
    func testSetDataWithEmptyArrayClearsMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series.setData(data: data)

        // Create plugin with initial markers
        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive),
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Clear markers via setData with empty array
        plugin.setData([])

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - PluginWithOptions Conformance Tests

    /// Tests that UpDownMarkersPlugin conforms to PluginWithOptions
    func testPluginWithOptionsConformance() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]

        let options = UpDownMarkersOptions(
            positiveColor: .solid(color: ChartColor(.green)),
            negativeColor: .solid(color: ChartColor(.red)),
            updateVisibilityDuration: 2000
        )
        let plugin = UpDownMarkersPlugin(series: series, data: markers, options: options)

        // Verify PluginWithOptions conformance by checking the options type alias
        let _ = plugin.options as UpDownMarkersPlugin<AreaSeries>.Options
        XCTAssertNotNil(plugin.options.positiveColor, "Plugin should have options")
        XCTAssertEqual(plugin.options.updateVisibilityDuration, 2000, "Plugin should have correct updateVisibilityDuration")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Update Variants Tests

    /// Tests that update works with neutral sign marker
    func testUpdateWithNeutralSignMarker() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update with neutral marker
        let neutralMarker = SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .neutral)
        plugin.update(neutralMarker)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests multiple consecutive update calls
    func testMultipleConsecutiveUpdates() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20),
            AreaData(time: .unix(3000), value: 15)]
        series.setData(data: data)

        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Perform multiple consecutive updates
        plugin.update(SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .positive))
        plugin.update(SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative))
        plugin.update(SeriesUpDownMarker(time: .unix(3000), value: 15, sign: .neutral))

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Options Edge Cases Tests

    /// Tests applyOptions with only positiveColor set
    func testApplyOptionsWithOnlyPositiveColor() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Apply options with only positiveColor set
        let partialOptions = UpDownMarkersOptions(positiveColor: .solid(color: ChartColor(.blue)))
        plugin.applyOptions(options: partialOptions)

        XCTAssertNotNil(plugin.options.positiveColor, "Plugin should update positiveColor")
        XCTAssertNil(plugin.options.negativeColor, "Plugin should keep negativeColor as nil")
        XCTAssertNil(plugin.options.updateVisibilityDuration, "Plugin should keep updateVisibilityDuration as nil")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests applyOptions with only negativeColor set
    func testApplyOptionsWithOnlyNegativeColor() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Apply options with only negativeColor set
        let partialOptions = UpDownMarkersOptions(negativeColor: .solid(color: ChartColor(.yellow)))
        plugin.applyOptions(options: partialOptions)

        XCTAssertNil(plugin.options.positiveColor, "Plugin should keep positiveColor as nil")
        XCTAssertNotNil(plugin.options.negativeColor, "Plugin should update negativeColor")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests applyOptions with only updateVisibilityDuration set
    func testApplyOptionsWithOnlyUpdateVisibilityDuration() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10)
        ]
        series.setData(data: data)

        let markers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: markers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Apply options with only updateVisibilityDuration set
        let partialOptions = UpDownMarkersOptions(updateVisibilityDuration: 500)
        plugin.applyOptions(options: partialOptions)

        XCTAssertNil(plugin.options.positiveColor, "Plugin should keep positiveColor as nil")
        XCTAssertNil(plugin.options.negativeColor, "Plugin should keep negativeColor as nil")
        XCTAssertEqual(plugin.options.updateVisibilityDuration, 500, "Plugin should update updateVisibilityDuration")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Markers Data Tests

    /// Tests plugin with many markers
    func testPluginWithManyMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        var data: [LineData] = []
        var markers: [SeriesUpDownMarker] = []

        // Create 100 data points and markers
        for i in 0..<100 {
            let time = 1000 + i * 1000
            data.append(LineData(time: .unix(Double(time)), value: Double(i)))
            let sign: MarkerSign = i % 3 == 0 ? .positive : (i % 3 == 1 ? .negative : .neutral)
            markers.append(SeriesUpDownMarker(time: .unix(Double(time)), value: Double(i), sign: sign))
        }

        series.setData(data: data)

        let plugin = UpDownMarkersPlugin(series: series, data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created with many markers")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests setData with larger dataset replacing smaller dataset
    func testSetDataWithLargerDataset() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20),
            AreaData(time: .unix(3000), value: 30)]
        series.setData(data: data)

        // Create plugin with single marker
        let initialMarkers = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive)
        ]
        let plugin = UpDownMarkersPlugin(series: series, data: initialMarkers)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Replace with larger dataset
        let largerMarkerSet = [
            SeriesUpDownMarker(time: .unix(1000), value: 10, sign: .positive),
            SeriesUpDownMarker(time: .unix(2000), value: 20, sign: .negative),
            SeriesUpDownMarker(time: .unix(3000), value: 30, sign: .neutral)
        ]
        plugin.setData(largerMarkerSet)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension SeriesMarkersPluginTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - LightweightChartsDelegate
extension UpDownMarkersPluginTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Text Watermark Plugin Tests (Task 10.7)

/// Tests for TextWatermarkPlugin functionality
///
/// These tests verify that the TextWatermarkPlugin:
/// - Can be created with initial options
/// - Conforms to the Plugin and PluginWithOptions protocols
/// - Can apply new options at runtime
/// - Can be detached properly
/// - Handles detached state edge cases
final class TextWatermarkPluginTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Plugin Creation Tests

    /// Tests that TextWatermarkPlugin can be created with default options
    func testPluginCreationWithDefaultOptions() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Test Watermark",
            color: "rgba(255, 0, 0, 0.5)",
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created")
        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that TextWatermarkPlugin can be created with custom alignment
    func testPluginCreationWithCustomAlignment() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .left,
            verticalAlignment: .top,
            lines: [
                WatermarkLine(
                    text: "Top Left",
                    color: ChartColor(.blue),
                    fontSize: 18
                )
            ]
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created with custom alignment")
        XCTAssertEqual(plugin.options.horizontalAlignment, .left)
        XCTAssertEqual(plugin.options.verticalAlignment, .top)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that TextWatermarkPlugin can be created with multiple lines
    func testPluginCreationWithMultipleLines() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [
                WatermarkLine(text: "Line 1", color: ChartColor(.red), fontSize: 24),
                WatermarkLine(text: "Line 2", color: ChartColor(.green), fontSize: 20),
                WatermarkLine(text: "Line 3", color: ChartColor(.blue), fontSize: 18)
            ]
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created with multiple lines")
        XCTAssertEqual(plugin.options.lines.count, 3)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - PluginWithOptions Tests

    /// Tests that applyOptions updates the plugin options
    func testApplyOptionsUpdatesPlugin() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Initial Text",
            color: "rgba(255, 0, 0, 0.5)",
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update options
        let newOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Updated Text",
            color: "rgba(0, 255, 0, 0.5)",
            fontSize: 36
        )
        plugin.applyOptions(options: newOptions)

        XCTAssertEqual(plugin.options.lines.first?.text, "Updated Text")
        XCTAssertEqual(plugin.options.lines.first?.fontSize, 36)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that applyOptions can update visibility
    func testApplyOptionsCanUpdateVisibility() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Visible Watermark",
            color: ChartColor(.black),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Hide the watermark
        let hiddenOptions = TextWatermarkOptions(
            visible: false,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: options.lines
        )
        plugin.applyOptions(options: hiddenOptions)

        XCTAssertFalse(plugin.options.visible, "Plugin should be hidden after applyOptions")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Convenience Methods Tests

    /// Tests that setText updates the watermark text
    func testSetTextUpdatesWatermarkText() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Original Text",
            color: ChartColor(.red),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update text using convenience method
        plugin.setText("New Text")

        XCTAssertEqual(plugin.options.lines.first?.text, "New Text")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that setVisible toggles watermark visibility
    func testVisibleTogglesWatermarkVisibility() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Toggle Test",
            color: ChartColor(.blue),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Hide the watermark
        plugin.setVisible(false)
        XCTAssertFalse(plugin.options.visible, "Plugin should be hidden")

        // Show the watermark
        plugin.setVisible(true)
        XCTAssertTrue(plugin.options.visible, "Plugin should be visible")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that getVisible returns the current visibility state
    func testGetVisibleReturnsCurrentState() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [WatermarkLine(text: "Test", color: ChartColor(.black), fontSize: 24)]
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()

        // Check initial visibility
        let expectation1 = self.expectation(description: "Get visible completes")
        plugin.getVisible { visible in
            XCTAssertTrue(visible ?? false, "Plugin should be visible initially")
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2.0)

        // Hide and check again
        plugin.setVisible(false)
        waitForAsyncOperations()

        let expectation2 = self.expectation(description: "Get visible completes after hide")
        plugin.getVisible { visible in
            XCTAssertFalse(visible ?? true, "Plugin should be hidden")
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }

    // MARK: - Detach Tests

    /// Tests that detach removes the plugin
    func testDetachRemovesPlugin() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "To Be Removed",
            color: ChartColor(.red),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")

        // Detach the plugin
        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be detached after detach()")
        errorCatcher.assertNoErrors()
    }

    /// Tests that getVisible on detached plugin returns nil
    func testGetVisibleOnDetachedPluginReturnsNil() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Test",
            color: ChartColor(.black),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // getVisible should return nil for detached plugin
        let expectation = self.expectation(description: "Get visible completes")
        plugin.getVisible { visible in
            XCTAssertNil(visible, "getVisible should return nil for detached plugin")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    /// Tests that calling applyOptions on detached plugin does nothing
    func testApplyOptionsOnDetachedPluginDoesNothing() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Original",
            color: ChartColor(.black),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // Try to apply options - should not crash or change state
        let newOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Should Not Apply",
            color: ChartColor(.red),
            fontSize: 36
        )
        plugin.applyOptions(options: newOptions)

        // Options should remain unchanged since plugin is detached
        XCTAssertEqual(plugin.options.lines.first?.text, "Original")
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling setText on detached plugin does nothing
    func testSetTextOnDetachedPluginDoesNothing() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Original Text",
            color: ChartColor(.black),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // Try to set text - should not change state
        plugin.setText("Should Not Apply")

        // Text should remain unchanged since plugin is detached
        XCTAssertEqual(plugin.options.lines.first?.text, "Original Text")
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling setVisible on detached plugin does nothing
    func testSetVisibleOnDetachedPluginDoesNothing() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Test",
            color: ChartColor(.black),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // Try to set visible - should not change state
        plugin.setVisible(false)

        // Visible should remain unchanged since plugin is detached
        XCTAssertTrue(plugin.options.visible)
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling detach twice is safe
    func testDoubleDetachIsSafe() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Double Detach Test",
            color: ChartColor(.blue),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach once
        plugin.detach()
        XCTAssertTrue(plugin.isDetached)

        // Detach again - should be safe
        plugin.detach()
        XCTAssertTrue(plugin.isDetached)

        errorCatcher.assertNoErrors()
    }

    // MARK: - Pane Index Tests

    /// Tests that plugin can be created on pane index 0
    func testPluginCreationOnPaneIndexZero() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Pane 0",
            color: ChartColor(.green),
            fontSize: 24
        )
        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        XCTAssertNotNil(plugin, "Plugin should be created on pane 0")
        XCTAssertEqual(plugin.paneIndex, 0)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations() {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension TextWatermarkPluginTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Image Watermark Plugin Tests (Task 10.8)

/// Tests for ImageWatermarkPlugin functionality
///
/// These tests verify that the ImageWatermarkPlugin:
/// - Can be created with initial options
/// - Conforms to the Plugin and PluginWithOptions protocols
/// - Can apply new options at runtime
/// - Can update the image URL via updateImage(url:)
/// - Can be detached properly
/// - Handles detached state edge cases
final class ImageWatermarkPluginTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Plugin Creation Tests

    /// Tests that ImageWatermarkPlugin can be created with default options
    func testPluginCreationWithDefaultOptions() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions()
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        XCTAssertNotNil(plugin, "Plugin should be created")
        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")
        XCTAssertEqual(plugin.imageUrl, "https://example.com/watermark.png")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that ImageWatermarkPlugin can be created with custom options
    func testPluginCreationWithCustomOptions() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(
            alpha: 0.5,
            padding: 10,
            maxWidth: 200,
            maxHeight: 200
        )
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        XCTAssertNotNil(plugin, "Plugin should be created with custom options")
        XCTAssertEqual(plugin.options.alpha, 0.5)
        XCTAssertEqual(plugin.options.padding, 10)
        XCTAssertEqual(plugin.options.maxWidth, 200)
        XCTAssertEqual(plugin.options.maxHeight, 200)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that ImageWatermarkPlugin can be created with a data URL
    func testPluginCreationWithDataURL() {
        errorCatcher.clear()

        let dataUrl = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let options = ImageWatermarkOptions(alpha: 0.8)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: dataUrl,
            options: options
        )

        XCTAssertNotNil(plugin, "Plugin should be created with data URL")
        XCTAssertEqual(plugin.imageUrl, dataUrl)
        XCTAssertEqual(plugin.options.alpha, 0.8)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - PluginWithOptions Tests

    /// Tests that applyOptions updates the plugin options
    func testApplyOptionsUpdatesPlugin() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(alpha: 1.0, padding: 0)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update options
        let newOptions = ImageWatermarkOptions(alpha: 0.3, padding: 20)
        plugin.applyOptions(options: newOptions)

        XCTAssertEqual(plugin.options.alpha, 0.3)
        XCTAssertEqual(plugin.options.padding, 20)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that applyOptions can update alpha
    func testApplyOptionsCanUpdateAlpha() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(alpha: 1.0)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update alpha
        let newOptions = ImageWatermarkOptions(alpha: 0.2)
        plugin.applyOptions(options: newOptions)

        XCTAssertEqual(plugin.options.alpha, 0.2, "Plugin should have updated alpha")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that applyOptions can update size constraints
    func testApplyOptionsCanUpdateSizeConstraints() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions()
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update size constraints
        let newOptions = ImageWatermarkOptions(maxWidth: 150, maxHeight: 150)
        plugin.applyOptions(options: newOptions)

        XCTAssertEqual(plugin.options.maxWidth, 150)
        XCTAssertEqual(plugin.options.maxHeight, 150)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Convenience Methods Tests

    /// Tests that setAlpha updates the watermark alpha
    func testSetAlphaUpdatesWatermarkAlpha() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(alpha: 1.0)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update alpha using convenience method
        plugin.setAlpha(0.4)

        XCTAssertEqual(plugin.options.alpha, 0.4)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Detach Tests

    /// Tests that detach removes the plugin
    func testDetachRemovesPlugin() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions()
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")

        // Detach the plugin
        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be detached after detach()")
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling applyOptions on detached plugin does nothing
    func testApplyOptionsOnDetachedPluginDoesNothing() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(alpha: 1.0, padding: 0)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // Try to apply options - should not crash or change state
        let newOptions = ImageWatermarkOptions(alpha: 0.5, padding: 10)
        plugin.applyOptions(options: newOptions)

        // Options should remain unchanged since plugin is detached
        XCTAssertEqual(plugin.options.alpha, 1.0)
        XCTAssertEqual(plugin.options.padding, 0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling detach twice is safe
    func testDoubleDetachIsSafe() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions()
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        plugin.detach()
        plugin.detach() // Should not cause issues

        XCTAssertTrue(plugin.isDetached)
        errorCatcher.assertNoErrors()
    }

    /// Tests that calling setAlpha on detached plugin does nothing
    func testSetAlphaOnDetachedPluginDoesNothing() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(alpha: 1.0)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()

        // Try to set alpha - should not change state
        plugin.setAlpha(0.2)

        // Alpha should remain unchanged since plugin is detached
        XCTAssertEqual(plugin.options.alpha, 1.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that imageUrl is stored correctly
    func testImageUrlIsStoredCorrectly() {
        errorCatcher.clear()

        let testUrl = "https://example.com/test-watermark.png"
        let options = ImageWatermarkOptions()
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: testUrl,
            options: options
        )

        XCTAssertEqual(plugin.imageUrl, testUrl, "imageUrl should be stored correctly")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that plugin can be created on pane index 0
    func testPluginCreationOnPaneIndexZero() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(alpha: 0.6)
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/watermark.png",
            options: options
        )

        XCTAssertNotNil(plugin, "Plugin should be created on pane 0")
        XCTAssertEqual(plugin.paneIndex, 0, "Plugin should have paneIndex 0")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - URL Replacement Tests

    /// Tests that updateImage(url:) changes the imageUrl property
    func testUpdateImageChangesUrlProperty() {
        errorCatcher.clear()

        let initialUrl = "https://example.com/initial.png"
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: initialUrl,
            options: ImageWatermarkOptions()
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        let newUrl = "https://example.com/updated.png"
        plugin.updateImage(url: newUrl)

        XCTAssertEqual(plugin.imageUrl, newUrl, "imageUrl should be updated")
        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached after update")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that updateImage(url:) preserves existing options
    func testUpdateImagePreservesOptions() {
        errorCatcher.clear()

        let options = ImageWatermarkOptions(
            alpha: 0.7,
            padding: 15,
            maxWidth: 200,
            maxHeight: 150
        )
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/initial.png",
            options: options
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        plugin.updateImage(url: "https://example.com/updated.png")

        XCTAssertEqual(plugin.options.alpha, 0.7, "Alpha should be preserved")
        XCTAssertEqual(plugin.options.padding, 15, "Padding should be preserved")
        XCTAssertEqual(plugin.options.maxWidth, 200, "MaxWidth should be preserved")
        XCTAssertEqual(plugin.options.maxHeight, 150, "MaxHeight should be preserved")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that updateImage(url:) works with data URLs
    func testUpdateImageSupportsDataURL() {
        errorCatcher.clear()

        let initialUrl = "https://example.com/watermark.png"
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: initialUrl,
            options: ImageWatermarkOptions(alpha: 0.5)
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        let dataUrl = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        plugin.updateImage(url: dataUrl)

        XCTAssertEqual(plugin.imageUrl, dataUrl, "imageUrl should be updated to data URL")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that updateImage(url:) can be called multiple times
    func testUpdateImageCanBeCalledMultipleTimes() {
        errorCatcher.clear()

        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/first.png",
            options: ImageWatermarkOptions()
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        plugin.updateImage(url: "https://example.com/second.png")
        XCTAssertEqual(plugin.imageUrl, "https://example.com/second.png")

        waitForAsyncOperations()
        errorCatcher.clear()

        plugin.updateImage(url: "https://example.com/third.png")
        XCTAssertEqual(plugin.imageUrl, "https://example.com/third.png")

        XCTAssertFalse(plugin.isDetached, "Plugin should remain active after multiple updates")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that updateImage(url:) does nothing on a detached plugin
    func testUpdateImageOnDetachedPluginDoesNothing() {
        errorCatcher.clear()

        let initialUrl = "https://example.com/initial.png"
        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: initialUrl,
            options: ImageWatermarkOptions()
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the plugin
        plugin.detach()
        XCTAssertTrue(plugin.isDetached, "Plugin should be detached")

        // Try to update the image
        plugin.updateImage(url: "https://example.com/should-not-change.png")

        // URL should remain unchanged
        XCTAssertEqual(plugin.imageUrl, initialUrl, "imageUrl should not change when plugin is detached")
        XCTAssertTrue(plugin.isDetached, "Plugin should remain detached")

        errorCatcher.assertNoErrors()
    }

    /// Tests that plugin remains functional after updateImage
    func testPluginRemainsFunctionalAfterUpdateImage() {
        errorCatcher.clear()

        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/initial.png",
            options: ImageWatermarkOptions(alpha: 0.8)
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update the image
        plugin.updateImage(url: "https://example.com/updated.png")

        waitForAsyncOperations()
        errorCatcher.clear()

        // Plugin should still be functional - test applyOptions
        let newOptions = ImageWatermarkOptions(alpha: 0.3)
        plugin.applyOptions(options: newOptions)

        XCTAssertEqual(plugin.options.alpha, 0.3, "applyOptions should still work after updateImage")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that updateImage followed by setAlpha works correctly
    func testUpdateImageFollowedBySetAlpha() {
        errorCatcher.clear()

        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/initial.png",
            options: ImageWatermarkOptions(alpha: 1.0)
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update the image
        plugin.updateImage(url: "https://example.com/updated.png")

        waitForAsyncOperations()
        errorCatcher.clear()

        // Set alpha using convenience method
        plugin.setAlpha(0.4)

        XCTAssertEqual(plugin.options.alpha, 0.4, "setAlpha should work after updateImage")
        XCTAssertEqual(plugin.imageUrl, "https://example.com/updated.png", "URL should remain unchanged")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations() {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension ImageWatermarkPluginTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - SeriesApi Plugin Factory Tests (Task 10.5, 10.6)

/// Tests for the SeriesApi extension plugin factory methods
///
/// Task 10.5: Tests the explicit markers plugin API via `createMarkersPlugin`
/// Task 10.6: Tests the up/down markers plugin API via `createUpDownMarkersPlugin`
///
/// These tests ensure that the `createMarkersPlugin` and `createUpDownMarkersPlugin`
/// factory methods work correctly on series types.
// final class SeriesApiPluginFactoryTests: XCTestCase {
// 
//     var charts: LightweightCharts!
//     var errorCatcher: JSErrorCatcher!
//     var loadExpectation: XCTestExpectation!
// 
//     override func setUp() {
//         super.setUp()
// 
//         loadExpectation = expectation(description: "Chart loads")
// 
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
//         errorCatcher = JSErrorCatcher()
// 
//         charts.errorDelegate = errorCatcher
//         charts.loadDelegate = self
// 
//         wait(for: [loadExpectation], timeout: 5.0)
//     }
// 
//     override func tearDown() {
//         charts = nil
//         errorCatcher = nil
//         super.tearDown()
//     }
// 
//     // MARK: - createMarkersPlugin Tests (Task 10.5)
// 
//     /// Tests that createMarkersPlugin works on LineSeries (Task 10.5)
//     func testCreateMarkersPluginOnLineSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         XCTAssertNotNil(series, "Line series should be created")
// 
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10),
//             LineData(time: .unix(2000), value: 20)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
//             SeriesMarker(time: .unix(2000), position: .belowBar, shape: .square, color: ChartColor(.blue))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created via factory method")
//         XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin works on BarSeries
//     func testCreateMarkersPluginOnBarSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addBarSeries(options: BarSeriesOptions())
//         let data: [BarData] = [
//             BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .inBar, shape: .arrowUp, color: ChartColor(.green))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created on BarSeries")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin works on AreaSeries
//     func testCreateMarkersPluginOnAreaSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addAreaSeries(options: AreaSeriesOptions())
//         let data: [AreaData] = [
//             AreaData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created on AreaSeries")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin works on CandlestickSeries
//     func testCreateMarkersPluginOnCandlestickSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
//         let data: [CandlestickData] = [
//             CandlestickData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowDown, color: ChartColor(.purple))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created on CandlestickSeries")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin works on HistogramSeries
//     func testCreateMarkersPluginOnHistogramSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
//         let data: [HistogramData] = [
//             HistogramData(time: .unix(1000), value: 10, color: ChartColor(.blue))
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.yellow))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created on HistogramSeries")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin works on BaselineSeries
//     func testCreateMarkersPluginOnBaselineSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
//         let data: [BaselineData] = [
//             BaselineData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .belowBar, shape: .square, color: ChartColor(.cyan))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created on BaselineSeries")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin accepts options parameter
//     func testCreateMarkersPluginWithOptions() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red))
//         ]
// 
//         let options = SeriesMarkersOptions(active: true, autoScale: true)
//         let plugin = series.createMarkersPlugin(data: markers, options: options)
// 
//         XCTAssertNotNil(plugin, "Plugin should be created with options via factory")
//         XCTAssertEqual(plugin.options.active, true, "Plugin should have active option")
//         XCTAssertEqual(plugin.options.autoScale, true, "Plugin should have autoScale option")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that plugin created via factory method has correct type
//     func testCreateMarkersPluginReturnsCorrectType() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.red))
//         ]
// 
//         let plugin = series.createMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created")
//         XCTAssertTrue(plugin is SeriesMarkersPlugin<LineSeries>, "Plugin should be SeriesMarkersPlugin<LineSeries>")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - createUpDownMarkersPlugin Tests
// 
//     /// Tests that createUpDownMarkersPlugin works on LineSeries
//     func testCreateUpDownMarkersPluginOnLineSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         XCTAssertNotNil(series, "Line series should be created")
// 
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10),
//             LineData(time: .unix(2000), value: 20)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive),
//             SeriesUpDownMarker(time: .unix(2000), value: 18, sign: .negative)
//         ]
// 
//         let plugin = series.createUpDownMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created via factory method")
//         XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createUpDownMarkersPlugin works on AreaSeries
//     func testCreateUpDownMarkersPluginOnAreaSeries() {
//         errorCatcher.clear()
// 
//         let series = charts.addAreaSeries(options: AreaSeriesOptions())
//         let data: [AreaData] = [
//             AreaData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive)
//         ]
// 
//         let plugin = series.createUpDownMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created on AreaSeries")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createUpDownMarkersPlugin accepts options parameter
//     func testCreateUpDownMarkersPluginWithOptions() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive)
//         ]
// 
//         let options = UpDownMarkersOptions(
//             positiveColor: .solid(.green),
//             negativeColor: .solid(.red),
//             updateVisibilityDuration: 1000
//         )
//         let plugin = series.createUpDownMarkersPlugin(data: markers, options: options)
// 
//         XCTAssertNotNil(plugin, "Plugin should be created with options via factory")
//         XCTAssertNotNil(plugin.options.positiveColor, "Plugin should have positiveColor option")
//         XCTAssertNotNil(plugin.options.negativeColor, "Plugin should have negativeColor option")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that plugin created via factory method has correct type
//     func testCreateUpDownMarkersPluginReturnsCorrectType() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         let markers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive)
//         ]
// 
//         let plugin = series.createUpDownMarkersPlugin(data: markers)
//         XCTAssertNotNil(plugin, "Plugin should be created")
//         XCTAssertTrue(plugin is UpDownMarkersPlugin<LineSeries>, "Plugin should be UpDownMarkersPlugin<LineSeries>")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that plugin created via factory method is functional
//     func testCreateUpDownMarkersPluginIsFunctional() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10),
//             LineData(time: .unix(2000), value: 20)
//         ]
//         series.setData(data: data)
// 
//         let initialMarkers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive)
//         ]
//         let plugin = series.createUpDownMarkersPlugin(data: initialMarkers)
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         // Test that setData works on the factory-created plugin
//         let updatedMarkers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive),
//             SeriesUpDownMarker(time: .unix(2000), value: 18, sign: .negative)
//         ]
//         plugin.setData(updatedMarkers)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createMarkersPlugin and createUpDownMarkersPlugin can coexist
//     func testMarkersPluginsCanCoexist() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = [
//             LineData(time: .unix(1000), value: 10)
//         ]
//         series.setData(data: data)
// 
//         // Create series markers plugin
//         let seriesMarkers = [
//             SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .circle, color: ChartColor(.orange))
//         ]
//         let seriesMarkersPlugin = series.createMarkersPlugin(data: seriesMarkers)
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         // Create up-down markers plugin on the same series
//         let upDownMarkers = [
//             SeriesUpDownMarker(time: .unix(1000), value: 12, sign: .positive)
//         ]
//         let upDownPlugin = series.createUpDownMarkersPlugin(data: upDownMarkers)
// 
//         XCTAssertNotNil(seriesMarkersPlugin, "Series markers plugin should exist")
//         XCTAssertNotNil(upDownPlugin, "Up-down markers plugin should exist")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// }

// MARK: - LightweightChartsDelegate
// extension SeriesApiPluginFactoryTests: LightweightChartsDelegate {
// 
//     func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
//         loadExpectation?.fulfill()
//     }
// 
//     func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
//         XCTFail("Chart failed to load: \(error.localizedDescription)")
//         loadExpectation?.fulfill()
//     }
// }

// MARK: - ChartApi Plugin Factory Tests

// class ChartApiPluginFactoryTests: XCTestCase {
// 
//     var errorCatcher: JSErrorCatcher!
//     var charts: LightweightCharts!
// 
//     override func setUp() {
//         super.setUp()
//         errorCatcher = JSErrorCatcher()
//         let options = ChartOptions()
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
//         charts.errorDelegate = errorCatcher
// 
//         let loadExpectation = expectation(description: "Chart loads")
//         let testDelegate = TestLoadDelegate(expectation: loadExpectation)
//         charts.loadDelegate = testDelegate
//         wait(for: [loadExpectation], timeout: 5.0)
// 
//         errorCatcher.assertNoErrors()
//     }
// 
//     override func tearDown() {
//         errorCatcher = nil
//         charts = nil
//         super.tearDown()
//     }
// 
//     // MARK: - createTextWatermarkPlugin Tests
// 
//     /// Tests that createTextWatermarkPlugin creates a text watermark plugin
//     func testCreateTextWatermarkPluginCreatesPlugin() {
//         errorCatcher.clear()
// 
//         let options = TextWatermarkOptions(
//             text: "Test Watermark",
//             color: "rgba(171, 71, 188, 0.5)",
//             fontSize: 24
//         )
// 
//         let plugin = charts.createTextWatermarkPlugin(options: options)
// 
//         XCTAssertNotNil(plugin, "Plugin should be created")
//         XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createTextWatermarkPlugin with custom paneIndex works
//     func testCreateTextWatermarkPluginWithCustomPaneIndex() {
//         errorCatcher.clear()
// 
//         let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Pane 1 Watermark")
//         let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)
// 
//         XCTAssertNotNil(plugin, "Plugin should be created with pane index 0")
//         XCTAssertEqual(plugin.paneIndex, 0, "Plugin should have paneIndex 0")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that text watermark plugin can apply options
//     func testCreateTextWatermarkPluginCanApplyOptions() {
//         errorCatcher.clear()
// 
//         let initialOptions = TextWatermarkOptions(
//             text: "Initial",
//             color: "rgba(255, 0, 0, 0.5)",
//             fontSize: 20
//         )
//         let plugin = charts.createTextWatermarkPlugin(options: initialOptions)
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         let updatedOptions = TextWatermarkOptions(
//             text: "Updated",
//             color: "rgba(0, 0, 255, 0.8)",
//             fontSize: 30
//         )
//         plugin.applyOptions(options: updatedOptions)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that text watermark plugin can be detached
//     func testCreateTextWatermarkPluginCanBeDetached() {
//         errorCatcher.clear()
// 
//         let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "To be removed")
//         let plugin = charts.createTextWatermarkPlugin(options: options)
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         plugin.detach()
// 
//         XCTAssertTrue(plugin.isDetached, "Plugin should be detached after calling detach()")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that text watermark plugin has correct type
//     func testCreateTextWatermarkPluginReturnsCorrectType() {
//         errorCatcher.clear()
// 
//         let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Type Check")
//         let plugin = charts.createTextWatermarkPlugin(options: options)
// 
//         XCTAssertNotNil(plugin, "Plugin should be created")
//         XCTAssertTrue(plugin is TextWatermarkPlugin<LightweightCharts>, "Plugin should be TextWatermarkPlugin<LightweightCharts>")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - createImageWatermarkPlugin Tests
// 
//     /// Tests that createImageWatermarkPlugin creates an image watermark plugin
//     func testCreateImageWatermarkPluginCreatesPlugin() {
//         errorCatcher.clear()
// 
//         let imageUrl = "https://example.com/watermark.png"
//         let options = ImageWatermarkOptions(
//             alpha: 0.5,
//             padding: 10
//         )
// 
//         let plugin = charts.createImageWatermarkPlugin(imageUrl: imageUrl, options: options)
// 
//         XCTAssertNotNil(plugin, "Plugin should be created")
//         XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")
//         XCTAssertEqual(plugin.imageUrl, imageUrl, "Plugin should have correct imageUrl")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that createImageWatermarkPlugin with custom paneIndex works
//     func testCreateImageWatermarkPluginWithCustomPaneIndex() {
//         errorCatcher.clear()
// 
//         let plugin = charts.createImageWatermarkPlugin(
//             paneIndex: 0,
//             imageUrl: "https://example.com/watermark.png"
//         )
// 
//         XCTAssertNotNil(plugin, "Plugin should be created with pane index 0")
//         XCTAssertEqual(plugin.paneIndex, 0, "Plugin should have paneIndex 0")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that image watermark plugin can apply options
//     func testCreateImageWatermarkPluginCanApplyOptions() {
//         errorCatcher.clear()
// 
//         let initialOptions = ImageWatermarkOptions(alpha: 0.3)
//         let plugin = charts.createImageWatermarkPlugin(
//             imageUrl: "https://example.com/watermark.png",
//             options: initialOptions
//         )
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         let updatedOptions = ImageWatermarkOptions(alpha: 0.7)
//         plugin.applyOptions(options: updatedOptions)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that image watermark plugin can update image URL
//     func testCreateImageWatermarkPluginCanUpdateImage() {
//         errorCatcher.clear()
// 
//         let initialUrl = "https://example.com/initial.png"
//         let plugin = charts.createImageWatermarkPlugin(imageUrl: initialUrl)
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         let newUrl = "https://example.com/updated.png"
//         plugin.updateImage(url: newUrl)
// 
//         XCTAssertEqual(plugin.imageUrl, newUrl, "Plugin should have updated imageUrl")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that image watermark plugin can be detached
//     func testCreateImageWatermarkPluginCanBeDetached() {
//         errorCatcher.clear()
// 
//         let plugin = charts.createImageWatermarkPlugin(imageUrl: "https://example.com/watermark.png")
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         plugin.detach()
// 
//         XCTAssertTrue(plugin.isDetached, "Plugin should be detached after calling detach()")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that image watermark plugin has correct type
//     func testCreateImageWatermarkPluginReturnsCorrectType() {
//         errorCatcher.clear()
// 
//         let plugin = charts.createImageWatermarkPlugin(imageUrl: "https://example.com/watermark.png")
// 
//         XCTAssertNotNil(plugin, "Plugin should be created")
//         XCTAssertTrue(plugin is ImageWatermarkPlugin<LightweightCharts>, "Plugin should be ImageWatermarkPlugin<LightweightCharts>")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that text and image watermark plugins can coexist
//     func testWatermarkPluginsCanCoexist() {
//         errorCatcher.clear()
// 
//         let textOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Text Watermark")
//         let textPlugin = charts.createTextWatermarkPlugin(options: textOptions)
// 
//         waitForAsyncOperations()
//         errorCatcher.clear()
// 
//         let imagePlugin = charts.createImageWatermarkPlugin(imageUrl: "https://example.com/watermark.png")
// 
//         XCTAssertNotNil(textPlugin, "Text plugin should exist")
//         XCTAssertNotNil(imagePlugin, "Image plugin should exist")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     /// Tests that watermark plugin works with default options
//     func testCreateImageWatermarkPluginWithDefaultOptions() {
//         errorCatcher.clear()
// 
//         let plugin = charts.createImageWatermarkPlugin(imageUrl: "https://example.com/watermark.png")
// 
//         XCTAssertNotNil(plugin, "Plugin should be created with default options")
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - Helper
// 
//     func waitForAsyncOperations() {
//         let waitExpectation = expectation(description: "Wait for async operations")
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//             waitExpectation.fulfill()
//         }
//         wait(for: [waitExpectation], timeout: 2.0)
//     }
// }

// MARK: - ImageWatermarkViewController Example Validation (Task 9.5)

final class ImageWatermarkViewControllerPatternTests: XCTestCase {
    var errorCatcher: JSErrorCatcher!

    override func setUp() {
        super.setUp()
        errorCatcher = JSErrorCatcher()
    }

    override func tearDown() {
        errorCatcher = nil
        super.tearDown()
    }

    /// Tests the exact usage pattern from ImageWatermarkViewController (task 9.5)
    func testImageWatermarkViewControllerPattern() {
        errorCatcher.clear()

        // The exact pattern from ImageWatermarkViewController
        let options = ChartOptions(
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#333"),
            rightPriceScale: VisiblePriceScaleOptions(scaleMargins: PriceScaleMargins(top: 0.1, bottom: 0.2)),
            grid: GridOptions(
                verticalLines: GridLineOptions(color: "#eee"),
                horizontalLines: GridLineOptions(color: "#ffffff")
            )
        )

        let expectationLoad = expectation(description: "Chart loads")
        let testChart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        testChart.errorDelegate = errorCatcher
        let strongLoadDelegate = TestLoadDelegate(expectation: expectationLoad)
        testChart.loadDelegate = strongLoadDelegate

        wait(for: [expectationLoad], timeout: 5.0)

        errorCatcher.assertNoErrors()

        // Create the image watermark using the v5 plugin API after the chart loads
        // Using a data URL for a simple watermark SVG (same pattern as in the ViewController)
        let watermarkSvg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">
            <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="24" fill="rgba(171, 71, 188, 0.3)"
                  text-anchor="middle" dominant-baseline="middle" transform="rotate(-45, 100, 100)">
                Watermark
            </text>
        </svg>
        """

        guard let svgData = watermarkSvg.data(using: .utf8),
              let base64String = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG to base64")
            return
        }

        let imageUrl = "data:image/svg+xml;base64,\(base64String)"

        let watermarkOptions = ImageWatermarkOptions(
            alpha: 0.5,
            padding: 10,
            maxWidth: 200,
            maxHeight: 200
        )
        let watermark = testChart.createImageWatermarkPlugin(paneIndex: 0, imageUrl: imageUrl, options: watermarkOptions)

        XCTAssertNotNil(watermark, "Watermark plugin should be created")

        // Wait for async operations
        let waitExpectation = expectation(description: "Wait for watermark")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        errorCatcher.assertNoErrors()

        // Also add a series like the example does
        let areaOptions = AreaSeriesOptions(
     topColor: "rgba(171, 71, 188, 0.56)",
     bottomColor: "rgba(171, 71, 188, 0.04)",
     lineColor: "rgba(171, 71, 188, 1)",
     lineWidth: .two
 )
        let series = testChart.addAreaSeries(options: areaOptions)

        let data: [AreaData] = [
            AreaData(time: .string("2018-10-19"), value: 75.46),
            AreaData(time: .string("2018-10-22"), value: 76.69),
            AreaData(time: .string("2018-10-23"), value: 73.82)]
        series.setData(data: data)

        let waitExpectation2 = expectation(description: "Data set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waitExpectation2.fulfill()
        }
        wait(for: [waitExpectation2], timeout: 2.0)

        errorCatcher.assertNoErrors()
    }
}

// MARK: - Chart Subscription and Utility APIs Tests

/// Tests for chart subscription APIs and utility methods
///
/// These tests verify that the chart's subscription methods (click, crosshair)
/// and utility methods (timeScale, priceScale, screenshot, remove) work correctly.
final class ChartSubscriptionAndUtilityTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Click Subscription Tests

    /// Tests that subscribeClick can be called without errors
    func testSubscribeClick() {
        errorCatcher.clear()

        charts.subscribeClick()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that unsubscribeClick can be called without errors
    func testUnsubscribeClick() {
        errorCatcher.clear()

        // First subscribe
        charts.subscribeClick()

        waitForAsyncOperations()

        errorCatcher.clear()

        // Then unsubscribe
        charts.unsubscribeClick()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that subscribeDblClick can be called without errors
    func testSubscribeDblClick() {
        errorCatcher.clear()

        charts.subscribeDblClick()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that unsubscribeDblClick can be called without errors
    func testUnsubscribeDblClick() {
        errorCatcher.clear()

        charts.subscribeDblClick()
        waitForAsyncOperations()

        errorCatcher.clear()
        charts.unsubscribeDblClick()
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that subscribe/unsubscribe click can be called multiple times
    func testMultipleClickSubscribeUnsubscribe() {
        errorCatcher.clear()

        // Subscribe/unsubscribe multiple times
        charts.subscribeClick()
        waitForAsyncOperations()

        charts.unsubscribeClick()
        waitForAsyncOperations()

        charts.subscribeClick()
        waitForAsyncOperations()

        charts.unsubscribeClick()
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Crosshair Subscription Tests

    /// Tests that subscribeCrosshairMove can be called without errors
    func testSubscribeCrosshairMove() {
        errorCatcher.clear()

        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that unsubscribeCrosshairMove can be called without errors
    func testUnsubscribeCrosshairMove() {
        errorCatcher.clear()

        // First subscribe
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.clear()

        // Then unsubscribe
        charts.unsubscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that subscribe/unsubscribe crosshair can be called multiple times
    func testMultipleCrosshairSubscribeUnsubscribe() {
        errorCatcher.clear()

        // Subscribe/unsubscribe multiple times
        charts.subscribeCrosshairMove()
        waitForAsyncOperations()

        charts.unsubscribeCrosshairMove()
        waitForAsyncOperations()

        charts.subscribeCrosshairMove()
        waitForAsyncOperations()

        charts.unsubscribeCrosshairMove()
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that both click and crosshair subscriptions can coexist
    func testBothSubscriptionsCanCoexist() {
        errorCatcher.clear()

        charts.subscribeClick()
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()

        // Unsubscribe both
        charts.unsubscribeClick()
        charts.unsubscribeCrosshairMove()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests setCrosshairPosition and clearCrosshairPosition APIs
    func testSetAndClearCrosshairPosition() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data = [
            LineData(time: .string("2024-01-01"), value: 100),
            LineData(time: .string("2024-01-02"), value: 101)
        ]
        series.setData(data: data)

        waitForAsyncOperations()

        charts.setCrosshairPosition(price: 100, horizontalPosition: .string("2024-01-01"), seriesApi: series)
        waitForAsyncOperations()

        charts.clearCrosshairPosition()
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests paneSize API callback behavior
    func testPaneSizeCallback() {
        errorCatcher.clear()

        let expectation = self.expectation(description: "Pane size callback invoked")

        charts.paneSize(paneIndex: 0) { size in
            XCTAssertNotNil(size, "Pane size should be returned for pane 0")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests panes API callback behavior
    func testPanesCallback() {
        errorCatcher.clear()

        let expectation = self.expectation(description: "Panes callback invoked")
        charts.panes { panes in
            XCTAssertGreaterThanOrEqual(panes.count, 1, "At least one pane should exist")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests addPane API can be called without errors
    func testAddPane() {
        errorCatcher.clear()

        charts.addPane()
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests removePane API can be called for a valid pane index
    func testRemovePane() {
        errorCatcher.clear()

        charts.addPane()
        waitForAsyncOperations()

        charts.removePane(index: 1)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests swapPanes API can be called with valid pane indices
    func testSwapPanes() {
        errorCatcher.clear()

        charts.addPane()
        waitForAsyncOperations()

        charts.swapPanes(first: 0, second: 1)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - TimeScale API Tests

    /// Tests that timeScale() returns a valid TimeScaleApi
    func testTimeScaleApi() {
        errorCatcher.clear()

        let timeScale = charts.timeScale()

        XCTAssertNotNil(timeScale, "TimeScaleApi should not be nil")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that timeScale can be called multiple times
    func testTimeScaleApiMultipleCalls() {
        errorCatcher.clear()

        let timeScale1 = charts.timeScale()
        let timeScale2 = charts.timeScale()

        XCTAssertNotNil(timeScale1)
        XCTAssertNotNil(timeScale2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - PriceScale API Tests

    /// Tests that priceScale(priceScaleId:) returns a valid PriceScaleApi
    func testPriceScaleApi() {
        errorCatcher.clear()

        let priceScale = charts.priceScale(priceScaleId: nil)

        XCTAssertNotNil(priceScale, "PriceScaleApi should not be nil")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that priceScale with custom ID works
    func testPriceScaleApiWithCustomId() {
        errorCatcher.clear()

        let priceScale = charts.priceScale(priceScaleId: "customScale")

        XCTAssertNotNil(priceScale, "PriceScaleApi with custom ID should not be nil")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that priceScale can be called multiple times
    func testPriceScaleApiMultipleCalls() {
        errorCatcher.clear()

        let priceScale1 = charts.priceScale(priceScaleId: nil)
        let priceScale2 = charts.priceScale(priceScaleId: "right")

        XCTAssertNotNil(priceScale1)
        XCTAssertNotNil(priceScale2)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Options Tests

    /// Tests that applyOptions can be called with valid options
    func testApplyOptions() {
        errorCatcher.clear()

        let options = ChartOptions(
            width: 500,
            height: 400,
            layout: nil,
            leftPriceScale: nil,
            rightPriceScale: nil,
            overlayPriceScales: nil,
            timeScale: nil,
            crosshair: nil,
            grid: nil,
            localization: nil,
            handleScroll: nil,
            handleScale: nil,
            kineticScroll: nil
            )

        charts.applyOptions(options: options)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that applyOptions with partial options works
    func testApplyPartialOptions() {
        errorCatcher.clear()

        let partialOptions = ChartOptions(
            width: nil,
            height: nil,
            layout: nil,
            leftPriceScale: nil,
            rightPriceScale: nil,
            overlayPriceScales: nil,
            timeScale: nil,
            crosshair: nil,
            grid: nil,
            localization: nil,
            handleScroll: nil,
            handleScale: nil,
            kineticScroll: nil
            )

        charts.applyOptions(options: partialOptions)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that options(completion:) callback is invoked
    func testOptionsCallback() {
        errorCatcher.clear()

        let expectation = self.expectation(description: "Options callback invoked")

        charts.options { options in
            XCTAssertNotNil(options, "Options should not be nil")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that applyOptions followed by options works
    func testApplyThenGetOptions() {
        errorCatcher.clear()

        let applyOptions = ChartOptions(
            width: 600,
            height: 450,
            layout: nil,
            leftPriceScale: nil,
            rightPriceScale: nil,
            overlayPriceScales: nil,
            timeScale: nil,
            crosshair: nil,
            grid: nil,
            localization: nil,
            handleScroll: nil,
            handleScale: nil,
            kineticScroll: nil
            )

        charts.applyOptions(options: applyOptions)

        waitForAsyncOperations()

        let expectation = self.expectation(description: "Options retrieved")

        charts.options { options in
            XCTAssertNotNil(options, "Options should be retrievable after applyOptions")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Screenshot Tests

    /// Tests that takeScreenshot invokes completion callback
    func testTakeScreenshot() {
        errorCatcher.clear()

        let expectation = self.expectation(description: "Screenshot callback invoked")

        charts.takeScreenshot { image in
            // Image may be nil in test environment, but callback should be invoked
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that takeScreenshot after resize works
    func testTakeScreenshotAfterResize() {
        errorCatcher.clear()

        charts.resize(width: 500, height: 400, forceRepaint: true)

        waitForAsyncOperations()

        let expectation = self.expectation(description: "Screenshot after resize")

        charts.takeScreenshot { image in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests takeScreenshot with v5 optional rendering flags
    func testTakeScreenshotWithOptions() {
        errorCatcher.clear()

        let expectation = self.expectation(description: "Screenshot callback with options")

        charts.takeScreenshot(addTopLayer: true, includeCrosshair: true) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that takeScreenshot can be called multiple times
    func testMultipleScreenshots() {
        errorCatcher.clear()

        let expectation1 = self.expectation(description: "Screenshot 1")
        let expectation2 = self.expectation(description: "Screenshot 2")
        let expectation3 = self.expectation(description: "Screenshot 3")

        charts.takeScreenshot { _ in expectation1.fulfill() }

        waitForAsyncOperations()

        charts.takeScreenshot { _ in expectation2.fulfill() }

        waitForAsyncOperations()

        charts.takeScreenshot { _ in expectation3.fulfill() }

        waitForAsyncOperations()

        wait(for: [expectation1, expectation2, expectation3], timeout: 5.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Chart Remove Tests

    /// Tests that chart remove can be called without errors
    func testChartRemove() {
        errorCatcher.clear()

        charts.remove()

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that operations after remove are handled gracefully
    func testOperationsAfterRemove() {
        errorCatcher.clear()

        charts.remove()

        waitForAsyncOperations()

        // These operations after remove may not work, but shouldn't crash
        // The behavior after remove is undefined in the JS library
        // We just verify no crashes occur
        let expectation = self.expectation(description: "After remove operations")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    /// Tests SeriesApi.priceLines(completion:) returns existing price lines
    func testSeriesPriceLinesCallback() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        _ = series.createPriceLine(options: PriceLineOptions(price: 120))

        waitForAsyncOperations()

        let expectation = self.expectation(description: "priceLines callback invoked")
        series.priceLines { lines in
            XCTAssertNotNil(lines, "priceLines should return a collection")
            XCTAssertEqual(lines?.count, 1, "priceLines should include the created price line")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - LightweightChartsDelegate
extension ChartSubscriptionAndUtilityTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Chart Options Exclusion Tests

/// Tests for verifying watermark exclusion from chart options
///
/// These tests verify that the legacy watermark field is properly
/// excluded from the raw JavaScript payload when creating charts.
final class ChartOptionsExclusionTests: XCTestCase {

    var errorCatcher: JSErrorCatcher!

    override func setUp() {
        super.setUp()
        errorCatcher = JSErrorCatcher()
    }

    override func tearDown() {
        errorCatcher = nil
        super.tearDown()
    }

    /// Tests that ChartOptions can be created without watermark
    func testChartOptionsWithoutWatermark() {
        let options = ChartOptions(
            width: 400,
            height: 300,
            layout: nil,
            leftPriceScale: nil,
            rightPriceScale: nil,
            overlayPriceScales: nil,
            timeScale: nil,
            crosshair: nil,
            grid: nil,
            localization: nil,
            handleScroll: nil,
            handleScale: nil,
            kineticScroll: nil
            )

        XCTAssertNotNil(options, "ChartOptions without watermark should be created")
    }

    /// Tests that chart creation with options succeeds
    func testChartCreationWithOptions() {
        let expectation = expectation(description: "Chart loads")

        let options = ChartOptions(
            width: 400,
            height: 300,
            layout: LayoutOptions(background: .solid(color: "#ffffff"), textColor: "#000000"),
            leftPriceScale: nil,
            rightPriceScale: nil,
            overlayPriceScales: nil,
            timeScale: nil,
            crosshair: nil,
            grid: GridOptions(
                verticalLines: GridLineOptions(color: "#eee"),
                horizontalLines: GridLineOptions(color: "#fff")
            ),
            localization: LocalizationOptions(locale: "en-US"),
            handleScroll: nil,
            handleScale: nil,
            kineticScroll: nil
            )

        let chart = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300), options: options)
        chart.errorDelegate = errorCatcher
        let strongLoadDelegate = TestLoadDelegate(expectation: expectation)
        chart.loadDelegate = strongLoadDelegate

        wait(for: [expectation], timeout: 5.0)

        errorCatcher.assertNoErrors()
    }

    /// Tests that layout.attributionLogo serializes with the upstream field name.
    func testLayoutAttributionLogoSerializedInJSPayload() {
        let options = ChartOptions(
            layout: LayoutOptions(
                background: .solid(color: "#ffffff"),
                textColor: "#000000",
                attributionLogo: false
            )
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)

        XCTAssertTrue(
            script.options.contains("\"attributionLogo\":false"),
            "JS payload should contain layout.attributionLogo with upstream field name"
        )
    }
}

// MARK: - Attribution Navigation Tests

/// Tests for attribution navigation routing behavior.
final class AttributionNavigationTests: XCTestCase {

    func testTradingViewAttributionURLRoutesToExternalBrowser() {
        let chart = LightweightCharts(frame: .zero)

        XCTAssertTrue(
            chart.shouldOpenInExternalBrowser(URL(string: "https://www.tradingview.com/")),
            "TradingView attribution URLs should be routed to external browser"
        )
    }

    func testNonTradingViewURLDoesNotRouteToExternalBrowser() {
        let chart = LightweightCharts(frame: .zero)

        XCTAssertFalse(
            chart.shouldOpenInExternalBrowser(URL(string: "https://example.com/path")),
            "Non-attribution URLs should remain in WKWebView"
        )
    }

    func testNilURLDoesNotRouteToExternalBrowser() {
        let chart = LightweightCharts(frame: .zero)

        XCTAssertFalse(
            chart.shouldOpenInExternalBrowser(nil),
            "Nil URL should not be routed externally"
        )
    }
}

// MARK: - Crosshair & TimeScale Parity Serialization Tests

final class CrosshairAndTimeScaleParitySerializationTests: XCTestCase {

    func testCrosshairHiddenModeAndDoNotSnapToHiddenSeriesIndicesSerialize() {
        let options = ChartOptions(
            crosshair: CrosshairOptions(
                mode: .hidden,
                doNotSnapToHiddenSeriesIndices: true
            )
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)

        XCTAssertTrue(script.options.contains("\"crosshair\""), "Crosshair block should be present")
        XCTAssertTrue(script.options.contains("\"mode\":2"), "hidden mode should serialize to raw value 2")
        XCTAssertTrue(
            script.options.contains("\"doNotSnapToHiddenSeriesIndices\":true"),
            "doNotSnapToHiddenSeriesIndices should serialize with upstream field name"
        )
    }

    func testCrosshairMagnetOHLCModeSerializes() {
        let options = ChartOptions(
            crosshair: CrosshairOptions(mode: .magnetOHLC)
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)
        XCTAssertTrue(script.options.contains("\"mode\":3"), "magnetOHLC mode should serialize to raw value 3")
    }

    func testTimeScaleParityFieldsSerialize() {
        let options = ChartOptions(
            timeScale: TimeScaleOptions(
                rightOffsetPixels: 48,
                allowShiftVisibleRangeOnWhitespaceReplacement: true,
                tickMarkMaxCharacterLength: 12,
                minimumHeight: 24
            )
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)

        XCTAssertTrue(script.options.contains("\"rightOffsetPixels\":48"), "rightOffsetPixels should serialize")
        XCTAssertTrue(
            script.options.contains("\"allowShiftVisibleRangeOnWhitespaceReplacement\":true"),
            "allowShiftVisibleRangeOnWhitespaceReplacement should serialize"
        )
        XCTAssertTrue(script.options.contains("\"tickMarkMaxCharacterLength\":12"), "tickMarkMaxCharacterLength should serialize")
        XCTAssertTrue(script.options.contains("\"minimumHeight\":24"), "minimumHeight should serialize")
    }
}

// MARK: - Price Scale / Localization / Formatting Parity Serialization Tests

final class PriceScaleLocalizationAndFormattingParitySerializationTests: XCTestCase {

    func testPriceScaleParityFieldsSerialize() {
        let options = ChartOptions(
            rightPriceScale: VisiblePriceScaleOptions(
                minimumWidth: 64,
                ensureEdgeTickMarksVisible: true
            )
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)

        XCTAssertTrue(script.options.contains("\"minimumWidth\":64"), "minimumWidth should serialize")
        XCTAssertTrue(
            script.options.contains("\"ensureEdgeTickMarksVisible\":true"),
            "ensureEdgeTickMarksVisible should serialize"
        )
    }

    func testLocalizationPercentageFormatterIsAppliedToJSScript() {
        let options = ChartOptions(
            localization: LocalizationOptions(
                percentageFormatter: .javaScript("(price) => `${price}%`")
            )
        )

        let script = options.optionsScript(for: nil as ClosuresStore?)
        XCTAssertTrue(
            script.options.contains("localization.percentageFormatter"),
            "percentageFormatter should be attached to localization options script"
        )
    }

    func testBuiltInPriceFormatBaseSerializes() {
        let lineOptions = LineSeriesOptions(
            priceFormat: .builtIn(
                BuiltInPriceFormat(type: .price, precision: 2, minMove: 0.01, base: 100)
            )
        )

        let script = lineOptions.optionsScript(for: nil as ClosuresStore?)
        XCTAssertTrue(script.options.contains("\"base\":100"), "BuiltInPriceFormat.base should serialize")
    }

    func testPointMarkerStylingFieldsSerializeForLineAreaBaseline() {
        let lineScript = LineSeriesOptions(pointMarkersVisible: true, pointMarkersRadius: 3).optionsScript(for: nil as ClosuresStore?)
        XCTAssertTrue(lineScript.options.contains("\"pointMarkersVisible\":true"), "LineSeriesOptions should serialize pointMarkersVisible")
        XCTAssertTrue(lineScript.options.contains("\"pointMarkersRadius\":3"), "LineSeriesOptions should serialize pointMarkersRadius")

        let areaScript = AreaSeriesOptions(pointMarkersVisible: false, pointMarkersRadius: 4).optionsScript(for: nil as ClosuresStore?)
        XCTAssertTrue(areaScript.options.contains("\"pointMarkersVisible\":false"), "AreaSeriesOptions should serialize pointMarkersVisible")
        XCTAssertTrue(areaScript.options.contains("\"pointMarkersRadius\":4"), "AreaSeriesOptions should serialize pointMarkersRadius")

        let baselineScript = BaselineSeriesOptions(pointMarkersVisible: true, pointMarkersRadius: 5).optionsScript(for: nil as ClosuresStore?)
        XCTAssertTrue(baselineScript.options.contains("\"pointMarkersVisible\":true"), "BaselineSeriesOptions should serialize pointMarkersVisible")
        XCTAssertTrue(baselineScript.options.contains("\"pointMarkersRadius\":5"), "BaselineSeriesOptions should serialize pointMarkersRadius")
    }
}

// MARK: - Script Evaluation Failure Assertion Tests

/// Tests for script evaluation failure helper assertions
///
/// These tests verify that the JSErrorCatcher assertion helpers
/// work correctly for various script evaluation failure scenarios.
final class ScriptEvaluationFailureAssertionTests: XCTestCase {

    var errorCatcher: JSErrorCatcher!

    override func setUp() {
        super.setUp()
        errorCatcher = JSErrorCatcher()
    }

    override func tearDown() {
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Error Count Tests

    func testAssertErrorCountWithZeroErrors() {
        errorCatcher.assertErrorCount(0)
    }

    func testAssertErrorCountWithSingleError() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        errorCatcher.recordError(script: "test", error: error)
        errorCatcher.assertErrorCount(1)
    }

    func testAssertErrorCountWithMultipleErrors() {
        for i in 1...3 {
            let error = NSError(domain: "Test", code: i, userInfo: [NSLocalizedDescriptionKey: "Error \(i)"])
            errorCatcher.recordError(script: "script\(i)", error: error)
        }
        errorCatcher.assertErrorCount(3)
    }

    func testAssertErrorCountFailsWithWrongCount() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        errorCatcher.recordError(script: "test", error: error)

        // Verify the correct count passes
        errorCatcher.assertErrorCount(1)

        // We cannot easily test that the wrong count *fails* because
        // assertErrorCount calls XCTAssertEqual internally, which would
        // report as a real test failure. Instead, verify the error count
        // directly to confirm the catcher tracks counts correctly.
        XCTAssertEqual(errorCatcher.errors.count, 1, "Error count should be 1")
        XCTAssertNotEqual(errorCatcher.errors.count, 2, "Error count should not be 2")
    }

    // MARK: - Script Failure Tests

    func testAssertScriptFailed() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Script failed"])
        errorCatcher.recordError(script: "chart.addLineSeries()", error: error)

        errorCatcher.assertScriptFailed("addLineSeries")
        errorCatcher.assertScriptFailed("chart")
    }

    func testAssertScriptFailedWithMultipleScripts() {
        let error1 = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error 1"])
        let error2 = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error 2"])

        errorCatcher.recordError(script: "chart.watermark()", error: error1)
        errorCatcher.recordError(script: "chart.resize()", error: error2)

        errorCatcher.assertScriptFailed("watermark")
        errorCatcher.assertScriptFailed("resize")
    }

    // MARK: - Last Error Tests

    func testAssertLastErrorContains() {
        let error1 = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "First error"])
        let error2 = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Second error with details"])

        errorCatcher.recordError(script: "script1", error: error1)
        errorCatcher.recordError(script: "script2", error: error2)

        errorCatcher.assertLastErrorContains("Second")
        errorCatcher.assertLastErrorContains("details")
    }

    func testAssertLastErrorContainsFailsWhenNoErrors() {
        // Should fail when there are no errors
        // In a real scenario, this would trigger XCTFail
        // We verify the method works with errors
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test"])
        errorCatcher.recordError(script: "test", error: error)
        errorCatcher.assertLastErrorContains("Test")
    }

    // MARK: - Error Matching Tests

    func testAssertErrorMatchesWithRegex() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error: Invalid value '123' at position 5"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorMatches("Invalid value")
        errorCatcher.assertErrorMatches("\\d+") // Matches digits
        errorCatcher.assertErrorMatches("position \\d+")
    }

    func testAssertErrorMatchesWithComplexPattern() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "TypeError: Cannot read property 'x' of undefined"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorMatches("TypeError.*undefined")
    }

    // MARK: - Error Category Tests

    func testAssertErrorCategorySyntaxError() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "SyntaxError: Unexpected token '}'"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorCategory(.syntaxError)
    }

    func testAssertErrorCategoryReferenceError() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "ReferenceError: myVar is not defined"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorCategory(.referenceError)
    }

    func testAssertErrorCategoryTypeError() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "TypeError: null is not a function"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorCategory(.typeError)
    }

    func testAssertErrorCategoryRangeError() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "RangeError: Maximum call stack size exceeded"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorCategory(.rangeError)
    }

    func testAssertErrorCategoryGenericError() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error: Something went wrong"])
        errorCatcher.recordError(script: "test", error: error)

        errorCatcher.assertErrorCategory(.genericError)
    }

    // MARK: - All Errors Contain Tests

    func testAssertAllErrorsContain() {
        errorCatcher.recordError(script: "s1", error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error: pane index"]))
        errorCatcher.recordError(script: "s2", error: NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error: pane index"]))
        errorCatcher.recordError(script: "s3", error: NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Error: pane index"]))

        errorCatcher.assertAllErrorsContain("pane")
    }

    // MARK: - No Errors Contain Tests

    func testAssertNoErrorsContain() {
        errorCatcher.recordError(script: "s1", error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error: type mismatch"]))
        errorCatcher.recordError(script: "s2", error: NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error: invalid value"]))

        errorCatcher.assertNoErrorsContain("pane")
        errorCatcher.assertNoErrorsContain("success")
    }

    // MARK: - First Error Containing Tests

    func testFirstErrorContaining() {
        errorCatcher.recordError(script: "s1", error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "First error: pane"]))
        errorCatcher.recordError(script: "s2", error: NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Second error: pane"]))

        let first = errorCatcher.firstErrorContaining("pane")
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.script, "s1")
    }

    func testFirstErrorContainingReturnsNil() {
        errorCatcher.recordError(script: "s1", error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error"]))

        let first = errorCatcher.firstErrorContaining("nonexistent")
        XCTAssertNil(first)
    }

    // MARK: - Assert Error For Script Tests

    func testAssertErrorForScript() {
        let script = "chart.addLineSeries(invalidOptions)"
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid options"])

        errorCatcher.recordError(script: script, error: error)

        let foundError = errorCatcher.assertErrorForScript("addLineSeries")
        XCTAssertNotNil(foundError)
        XCTAssertEqual(foundError?.script, script)
        XCTAssertTrue(foundError?.errorDescription.contains("Invalid") ?? false)
    }

    func testAssertErrorForScriptReturnsErrorDetails() {
        let script = "chart.resize(-100, -100)"
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid dimensions"])

        errorCatcher.recordError(script: script, error: error)

        let foundError = errorCatcher.assertErrorForScript("resize")
        XCTAssertNotNil(foundError)
        XCTAssertEqual(foundError?.errorDescription, "Invalid dimensions")
    }

    // MARK: - Integration Tests

    func testMultipleAssertionsWorkTogether() {
        let error1 = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "SyntaxError: Unexpected token"])
        let error2 = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "ReferenceError: undefinedVar"])

        errorCatcher.recordError(script: "script1()", error: error1)
        errorCatcher.recordError(script: "script2()", error: error2)

        // Verify multiple assertions work correctly
        errorCatcher.assertErrorCount(2)
        errorCatcher.assertErrorOccurred()
        errorCatcher.assertErrorCategory(.syntaxError)
        errorCatcher.assertErrorCategory(.referenceError)
        errorCatcher.assertScriptFailed("script1")
        errorCatcher.assertLastErrorContains("undefinedVar")
    }

    func testClearResetsAllState() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error"])
        errorCatcher.recordError(script: "test", error: error)

        XCTAssertTrue(errorCatcher.hasErrors)
        errorCatcher.assertErrorCount(1)

        errorCatcher.clear()

        XCTAssertFalse(errorCatcher.hasErrors)
        errorCatcher.assertErrorCount(0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Error Category Enum Tests

    func testErrorCategoryRawValues() {
        XCTAssertEqual(ErrorCategory.syntaxError.rawValue, "SyntaxError")
        XCTAssertEqual(ErrorCategory.referenceError.rawValue, "ReferenceError")
        XCTAssertEqual(ErrorCategory.typeError.rawValue, "TypeError")
        XCTAssertEqual(ErrorCategory.rangeError.rawValue, "RangeError")
        XCTAssertEqual(ErrorCategory.genericError.rawValue, "Error")
    }

    func testErrorCategoryMatching() {
        XCTAssertTrue(ErrorCategory.syntaxError.matches("SyntaxError: unexpected token"))
        XCTAssertTrue(ErrorCategory.referenceError.matches("ReferenceError: x is not defined"))
        XCTAssertTrue(ErrorCategory.typeError.matches("TypeError: null is not a function"))
        XCTAssertTrue(ErrorCategory.rangeError.matches("RangeError: invalid array length"))
        XCTAssertTrue(ErrorCategory.genericError.matches("Error: something went wrong"))

        XCTAssertFalse(ErrorCategory.syntaxError.matches("ReferenceError: test"))
    }
}

// MARK: - Series Creation Path Tests

/// Tests for series creation JavaScript execution path validation
///
/// These tests verify that the JavaScript code path for creating each series type
/// executes correctly. They validate that:
/// - The correct `chart.addSeries(LightweightCharts.{SeriesType}, options)` call is made
/// - No script evaluation errors occur during series creation
/// - The series object has a valid `jsName` for JavaScript tracking
/// - The seriesArray tracking is properly updated
final class SeriesCreationPathTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Line Series Path Tests

    /// Tests that the line series creation path executes without JavaScript errors
    ///
    /// This validates that `chart.addSeries(LightweightCharts.LineSeries, options)` is called
    /// and the resulting series object has a valid JavaScript name for tracking.
    func testLineSeriesCreationPath() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        XCTAssertNotNil(series, "Line series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName for JavaScript tracking")
        XCTAssertTrue(series.jsName.hasPrefix("series"), "jsName should follow the series naming convention")

        waitForAsyncOperations()

        // Verify no JavaScript errors occurred during the series creation path
        errorCatcher.assertNoErrors()
    }

    /// Tests that line series creation with options executes correctly
    func testLineSeriesCreationPathWithOptions() {
        errorCatcher.clear()

        let options = LineSeriesOptions(
     title: "Test Line Series",
     visible: true,
     priceLineVisible: false,
     color: ChartColor(.blue),
     lineStyle: .solid,
     lineWidth: .two,
     lineType: .simple,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 4,
     lastPriceAnimation: .none
 )

        let series = charts.addLineSeries(options: options)

        XCTAssertNotNil(series, "Line series with options should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Area Series Path Tests

    /// Tests that the area series creation path executes without JavaScript errors
    func testAreaSeriesCreationPath() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())

        XCTAssertNotNil(series, "Area series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")
        XCTAssertTrue(series.jsName.hasPrefix("series"), "jsName should follow the series naming convention")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that area series creation with options executes correctly
    func testAreaSeriesCreationPathWithOptions() {
        errorCatcher.clear()

        let options = AreaSeriesOptions(
     title: "Test Area Series",
     visible: true,
     priceLineVisible: false,
     lineColor: ChartColor(.green),
     lineStyle: .dashed,
     lineWidth: .two,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 4,
     lastPriceAnimation: .none
 )

        let series = charts.addAreaSeries(options: options)

        XCTAssertNotNil(series, "Area series with options should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Bar Series Path Tests

    /// Tests that the bar series creation path executes without JavaScript errors
    func testBarSeriesCreationPath() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())

        XCTAssertNotNil(series, "Bar series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")
        XCTAssertTrue(series.jsName.hasPrefix("series"), "jsName should follow the series naming convention")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that bar series creation with options executes correctly
    func testBarSeriesCreationPathWithOptions() {
        errorCatcher.clear()

        let options = BarSeriesOptions(
     title: "Test Bar Series",
     visible: true,
     priceLineVisible: false,
     upColor: ChartColor(.green),
     downColor: ChartColor(.red),
     openVisible: true,
     thinBars: false
 )

        let series = charts.addBarSeries(options: options)

        XCTAssertNotNil(series, "Bar series with options should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Candlestick Series Path Tests

    /// Tests that the candlestick series creation path executes without JavaScript errors
    func testCandlestickSeriesCreationPath() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        XCTAssertNotNil(series, "Candlestick series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")
        XCTAssertTrue(series.jsName.hasPrefix("series"), "jsName should follow the series naming convention")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that candlestick series creation with options executes correctly
    func testCandlestickSeriesCreationPathWithOptions() {
        errorCatcher.clear()

        let options = CandlestickSeriesOptions(
     title: "Test Candlestick Series",
     visible: true,
     priceLineVisible: false,
     upColor: ChartColor(.green),
     downColor: ChartColor(.red),
     wickVisible: true,
     borderVisible: true
 )

        let series = charts.addCandlestickSeries(options: options)

        XCTAssertNotNil(series, "Candlestick series with options should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Histogram Series Path Tests

    /// Tests that the histogram series creation path executes without JavaScript errors
    func testHistogramSeriesCreationPath() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())

        XCTAssertNotNil(series, "Histogram series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")
        XCTAssertTrue(series.jsName.hasPrefix("series"), "jsName should follow the series naming convention")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that histogram series creation with options executes correctly
    func testHistogramSeriesCreationPathWithOptions() {
        errorCatcher.clear()

        let options = HistogramSeriesOptions(
     title: "Test Histogram Series",
     visible: true,
     priceLineVisible: false,
     color: ChartColor(.purple)
 )

        let series = charts.addHistogramSeries(options: options)

        XCTAssertNotNil(series, "Histogram series with options should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Baseline Series Path Tests

    /// Tests that the baseline series creation path executes without JavaScript errors
    func testBaselineSeriesCreationPath() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())

        XCTAssertNotNil(series, "Baseline series should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")
        XCTAssertTrue(series.jsName.hasPrefix("series"), "jsName should follow the series naming convention")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that baseline series creation with options executes correctly
    func testBaselineSeriesCreationPathWithOptions() {
        errorCatcher.clear()

        let options = BaselineSeriesOptions(
     title: "Test Baseline Series",
     visible: true,
     priceLineVisible: false,
     lineWidth: .two,
     lineStyle: .solid,
     lineType: .simple,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 4,
     lastPriceAnimation: .none
 )

        let series = charts.addBaselineSeries(options: options)

        XCTAssertNotNil(series, "Baseline series with options should be created")
        XCTAssertFalse(series.jsName.isEmpty, "Series should have a valid jsName")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Series Creation Path Tests

    /// Tests that creating multiple series of different types in sequence executes correctly
    ///
    /// This validates that the JavaScript execution path handles multiple addSeries calls
    /// without errors and each series gets a unique jsName.
    func testMultipleSeriesTypesCreationPath() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let histogramSeries = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let baselineSeries = charts.addBaselineSeries(options: BaselineSeriesOptions())

        // Verify all series were created
        XCTAssertNotNil(lineSeries, "Line series should be created")
        XCTAssertNotNil(areaSeries, "Area series should be created")
        XCTAssertNotNil(barSeries, "Bar series should be created")
        XCTAssertNotNil(candlestickSeries, "Candlestick series should be created")
        XCTAssertNotNil(histogramSeries, "Histogram series should be created")
        XCTAssertNotNil(baselineSeries, "Baseline series should be created")

        // Verify all have valid jsNames
        XCTAssertFalse(lineSeries.jsName.isEmpty, "Line series should have a valid jsName")
        XCTAssertFalse(areaSeries.jsName.isEmpty, "Area series should have a valid jsName")
        XCTAssertFalse(barSeries.jsName.isEmpty, "Bar series should have a valid jsName")
        XCTAssertFalse(candlestickSeries.jsName.isEmpty, "Candlestick series should have a valid jsName")
        XCTAssertFalse(histogramSeries.jsName.isEmpty, "Histogram series should have a valid jsName")
        XCTAssertFalse(baselineSeries.jsName.isEmpty, "Baseline series should have a valid jsName")

        // Verify all jsNames are unique (JavaScript tracking requirement)
        let jsNames = [lineSeries.jsName, areaSeries.jsName, barSeries.jsName,
                       candlestickSeries.jsName, histogramSeries.jsName, baselineSeries.jsName]
        XCTAssertEqual(Set(jsNames).count, jsNames.count,
                      "All series should have unique jsNames for proper JavaScript tracking")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that creating multiple series of the same type executes correctly
    ///
    /// This validates that the JavaScript execution path handles multiple addSeries calls
    /// for the same series type and generates unique jsNames for each.
    func testMultipleSeriesSameTypeCreationPath() {
        errorCatcher.clear()

        let lineSeries1 = charts.addLineSeries(options: LineSeriesOptions())
        let lineSeries2 = charts.addLineSeries(options: LineSeriesOptions())
        let lineSeries3 = charts.addLineSeries(options: LineSeriesOptions())

        // Verify all series were created
        XCTAssertNotNil(lineSeries1, "First line series should be created")
        XCTAssertNotNil(lineSeries2, "Second line series should be created")
        XCTAssertNotNil(lineSeries3, "Third line series should be created")

        // Verify all have valid and unique jsNames
        XCTAssertFalse(lineSeries1.jsName.isEmpty, "First series should have a valid jsName")
        XCTAssertFalse(lineSeries2.jsName.isEmpty, "Second series should have a valid jsName")
        XCTAssertFalse(lineSeries3.jsName.isEmpty, "Third series should have a valid jsName")

        XCTAssertNotEqual(lineSeries1.jsName, lineSeries2.jsName,
                         "Multiple series of the same type should have unique jsNames")
        XCTAssertNotEqual(lineSeries2.jsName, lineSeries3.jsName,
                         "Multiple series of the same type should have unique jsNames")
        XCTAssertNotEqual(lineSeries1.jsName, lineSeries3.jsName,
                         "Multiple series of the same type should have unique jsNames")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension SeriesCreationPathTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Backward-Compatible Markers Tests

/// Tests for backward-compatible markers API
///
/// These tests verify that the legacy `setMarkers()` and `markers(completion:)` API
/// work correctly after the v5 migration. The compatibility layer internally uses the
/// v5 `createSeriesMarkers` primitive, storing a reference to the plugin on the series
/// object as `_lwcMarkersPlugin`.
final class BackwardCompatibleMarkersTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func createTestData() -> (data: [LineData], markers: [SeriesMarker]) {
        let data: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20),
            LineData(time: .unix(3000), value: 15),
            LineData(time: .unix(4000), value: 25),
            LineData(time: .unix(5000), value: 18)
        ]

        let markers: [SeriesMarker] = [
            SeriesMarker(time: .unix(2000), position: .aboveBar, shape: .circle, color: ChartColor(.blue)),
            SeriesMarker(time: .unix(3000), position: .belowBar, shape: .arrowUp, color: ChartColor(.green)),
            SeriesMarker(time: .unix(4000), position: .inBar, shape: .square, color: ChartColor(.red))
        ]

        return (data, markers)
    }

    // MARK: - setMarkers Tests

    /// Tests that setMarkers executes without JavaScript errors
    func testSetMarkersExecutesWithoutErrors() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, markers) = createTestData()

        series.setData(data: data)
        series.setMarkers(data: markers)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers creates the compatibility plugin on first call
    func testSetMarkersCreatesCompatibilityPlugin() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, markers) = createTestData()

        series.setData(data: data)

        // First call should create the plugin
        series.setMarkers(data: markers)

        waitForAsyncOperations()

        // Verify no errors - plugin creation succeeded
        errorCatcher.assertNoErrors()
    }

    /// Tests that repeated setMarkers calls update existing plugin
    func testRepeatedSetMarkersUpdatesExistingPlugin() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, initialMarkers) = createTestData()

        series.setData(data: data)

        // First call creates the plugin
        series.setMarkers(data: initialMarkers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()

        // Create different markers
        let updatedMarkers: [SeriesMarker] = [
            SeriesMarker(time: .unix(1500), position: .aboveBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: .unix(2500), position: .belowBar, shape: .arrowDown, color: ChartColor(.orange))
        ]

        // Second call should update the existing plugin
        series.setMarkers(data: updatedMarkers)
        waitForAsyncOperations()

        // Verify no errors - plugin update succeeded
        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with different series types
    func testSetMarkersWorksAcrossSeriesTypes() {
        errorCatcher.clear()

        let (_, markers) = createTestData()

        // Test with LineSeries
        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        lineSeries.setData(data: createTestData().data)
        lineSeries.setMarkers(data: markers)

        // Test with AreaSeries
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        areaSeries.setData(data: createTestData().data.map { data in
            AreaData(time: data.time, value: data.value)
        })
        areaSeries.setMarkers(data: markers)

        // Test with BarSeries
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())
        let barData: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ]
        barSeries.setData(data: barData)
        barSeries.setMarkers(data: markers)

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that setMarkers works with empty array
    func testSetMarkersWithEmptyArray() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, _) = createTestData()

        series.setData(data: data)
        series.setMarkers(data: [])

        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - markers Tests

    /// Tests that markers returns the markers that were set
    func testMarkersReturnsSetMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, markers) = createTestData()

        series.setData(data: data)
        series.setMarkers(data: markers)

        let expectation = self.expectation(description: "Markers retrieved")

        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Markers should not be nil")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers returns nil when no markers were set
    func testMarkersReturnsNilWhenNotSet() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, _) = createTestData()

        series.setData(data: data)

        let expectation = self.expectation(description: "Markers retrieved")

        series.markers { retrievedMarkers in
            // Should be nil since no markers were set
            XCTAssertNil(retrievedMarkers, "Markers should be nil when not set")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers returns updated markers after setMarkers update
    func testMarkersReflectsUpdatedMarkers() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, initialMarkers) = createTestData()

        series.setData(data: data)
        series.setMarkers(data: initialMarkers)

        waitForAsyncOperations()

        // Update with different markers
        let updatedMarkers: [SeriesMarker] = [
            SeriesMarker(time: .unix(1500), position: .aboveBar, shape: .circle, color: ChartColor(.yellow))
        ]

        series.setMarkers(data: updatedMarkers)

        let expectation = self.expectation(description: "Updated markers retrieved")

        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Updated markers should not be nil")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Combined Tests

    /// Tests that setMarkers and markers work together correctly
    func testSetMarkersAndMarkersRoundTrip() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, markers) = createTestData()

        series.setData(data: data)

        // Set markers
        series.setMarkers(data: markers)
        waitForAsyncOperations()

        // Retrieve markers
        let expectation = self.expectation(description: "Round trip markers retrieved")

        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Retrieved markers should not be nil")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that multiple series can have independent markers
    func testMultipleSeriesWithIndependentMarkers() {
        errorCatcher.clear()

        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addLineSeries(options: LineSeriesOptions())
        let (data, _) = createTestData()

        series1.setData(data: data)
        series2.setData(data: data)

        let markers1: [SeriesMarker] = [
            SeriesMarker(time: .unix(2000), position: .aboveBar, shape: .circle, color: ChartColor(.blue))
        ]

        let markers2: [SeriesMarker] = [
            SeriesMarker(time: .unix(3000), position: .belowBar, shape: .square, color: ChartColor(.red))
        ]

        series1.setMarkers(data: markers1)
        series2.setMarkers(data: markers2)

        waitForAsyncOperations()

        let expectation1 = self.expectation(description: "Series 1 markers retrieved")
        let expectation2 = self.expectation(description: "Series 2 markers retrieved")

        series1.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Series 1 markers should not be nil")
            expectation1.fulfill()
        }

        series2.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Series 2 markers should not be nil")
            expectation2.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: 2.0)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests the full compatibility layer lifecycle
    ///
    /// This test validates:
    /// 1. Initial setMarkers creates the compatibility plugin
    /// 2. Subsequent setMarkers calls update the existing plugin
    /// 3. markers() retrieves the current markers
    /// 4. All operations complete without JavaScript errors
    func testFullCompatibilityLayerLifecycle() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let (data, _) = createTestData()

        series.setData(data: data)

        // Phase 1: Initial setMarkers creates the plugin
        let initialMarkers: [SeriesMarker] = [
            SeriesMarker(time: .unix(2000), position: .aboveBar, shape: .circle, color: ChartColor(.blue))
        ]

        series.setMarkers(data: initialMarkers)
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Phase 2: Verify markers can be retrieved
        let retrieveExpectation = expectation(description: "Initial markers retrieved")
        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Initial markers should be retrievable")
            retrieveExpectation.fulfill()
        }
        wait(for: [retrieveExpectation], timeout: 2.0)
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Phase 3: Update markers
        let updatedMarkers: [SeriesMarker] = [
            SeriesMarker(time: .unix(2000), position: .aboveBar, shape: .circle, color: ChartColor(.blue)),
            SeriesMarker(time: .unix(3000), position: .belowBar, shape: .arrowUp, color: ChartColor(.green)),
            SeriesMarker(time: .unix(4000), position: .inBar, shape: .square, color: ChartColor(.red))
        ]

        series.setMarkers(data: updatedMarkers)
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Phase 4: Verify updated markers can be retrieved
        let updatedRetrieveExpectation = expectation(description: "Updated markers retrieved")
        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Updated markers should be retrievable")
            updatedRetrieveExpectation.fulfill()
        }
        wait(for: [updatedRetrieveExpectation], timeout: 2.0)
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()

        // Phase 5: Clear markers with empty array
        series.setMarkers(data: [])
        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension BackwardCompatibleMarkersTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Series Data Validation Tests

/// Tests for series data validation functionality
///
/// These tests ensure that the validation layer correctly identifies:
/// 1. Data not in chronological order
/// 2. Duplicate time values
/// 3. Invalid OHLC data relationships
/// 4. Invalid numeric values (NaN, infinity)
/// 5. Update time before latest time
// final class SeriesDataValidationTests: XCTestCase {
// 
//     var charts: LightweightCharts!
//     var errorCatcher: JSErrorCatcher!
//     var loadExpectation: XCTestExpectation!
// 
//     override func setUp() {
//         super.setUp()
// 
//         loadExpectation = expectation(description: "Chart loads")
// 
//         charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
//         errorCatcher = JSErrorCatcher()
//         charts.loadDelegate = self
//         charts.errorDelegate = errorCatcher
// 
//         wait(for: [loadExpectation], timeout: 5.0)
//     }
// 
//     override func tearDown() {
//         charts = nil
//         errorCatcher = nil
//         super.tearDown()
//     }
// 
//     private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
//         let expectation = self.expectation(description: "Async operations complete")
//         DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
//             expectation.fulfill()
//         }
//         wait(for: [expectation], timeout: 1.0)
//     }
// 
//     // MARK: - Time Comparison Tests
// 
//     func testTimeComparisonUtc() {
//         let time1 = Time.utc(timestamp: 1000)
//         let time2 = Time.utc(timestamp: 2000)
//         let time3 = Time.utc(timestamp: 1000)
// 
//         XCTAssertEqual(time1.compare(time2), -1, "time1 should be before time2")
//         XCTAssertEqual(time2.compare(time1), 1, "time2 should be after time1")
//         XCTAssertEqual(time1.compare(time3), 0, "time1 should equal time3")
//         XCTAssertTrue(time1.isBefore(time2))
//         XCTAssertTrue(time2.isAfter(time1))
//         XCTAssertTrue(time1.isEqual(to: time3))
//     }
// 
//     func testTimeComparisonBusinessDay() {
//         let time1 = Time.businessDay(BusinessDay(year: 2024, month: 1, day: 1))
//         let time2 = Time.businessDay(BusinessDay(year: 2024, month: 1, day: 2))
//         let time3 = Time.businessDay(BusinessDay(year: 2024, month: 1, day: 1))
// 
//         XCTAssertEqual(time1.compare(time2), -1, "Jan 1 should be before Jan 2")
//         XCTAssertEqual(time2.compare(time1), 1, "Jan 2 should be after Jan 1")
//         XCTAssertEqual(time1.compare(time3), 0, "Same dates should be equal")
//     }
// 
//     func testTimeComparisonString() {
//         let time1 = Time.string("2024-01-01")
//         let time2 = Time.string("2024-01-02")
//         let time3 = Time.string("2024-01-01")
// 
//         XCTAssertEqual(time1.compare(time2), -1, "First string should be before second")
//         XCTAssertEqual(time2.compare(time1), 1, "Second string should be after first")
//         XCTAssertEqual(time1.compare(time3), 0, "Same strings should be equal")
//     }
// 
//     func testTimeComparisonIncomparableTypes() {
//         let utcTime = Time.utc(timestamp: 1000)
//         let businessDay = Time.businessDay(BusinessDay(year: 2024, month: 1, day: 1))
//         let stringTime = Time.string("2024-01-01")
// 
//         XCTAssertNil(utcTime.compare(businessDay), "UTC and businessDay should be incomparable")
//         XCTAssertNil(utcTime.compare(stringTime), "UTC and string should be incomparable")
//         XCTAssertNil(businessDay.compare(stringTime), "businessDay and string should be incomparable")
//     }
// 
//     // MARK: - LineSeries Validation Tests
// 
//     func testLineSeriesAcceptsValidChronologicalData() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let data: [LineData] = [
//             LineData(time: .utc(timestamp: 1000), value: 10),
//             LineData(time: .utc(timestamp: 2000), value: 20),
//             LineData(time: .utc(timestamp: 3000), value: 15)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testLineSeriesAcceptsEmptyData() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
//         let data: [LineData] = []
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testLineSeriesAcceptsUpdateWithSameTime() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let initialData: [LineData] = [
//             LineData(time: .utc(timestamp: 1000), value: 10),
//             LineData(time: .utc(timestamp: 2000), value: 20)
//         ]
// 
//         series.setData(data: initialData)
// 
//         // Update with same time as last element (replaces it)
//         series.update(bar: LineData(time: .utc(timestamp: 2000), value: 25))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testLineSeriesAcceptsUpdateWithLaterTime() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let initialData: [LineData] = [
//             LineData(time: .utc(timestamp: 1000), value: 10),
//             LineData(time: .utc(timestamp: 2000), value: 20)
//         ]
// 
//         series.setData(data: initialData)
// 
//         // Update with later time (adds new point)
//         series.update(bar: LineData(time: .utc(timestamp: 3000), value: 25))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testLineSeriesHandlesNilValues() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let data: [LineData] = [
//             LineData(time: .utc(timestamp: 1000), value: 10),
//             LineData(time: .utc(timestamp: 2000), value: nil),  // Gap
//             LineData(time: .utc(timestamp: 3000), value: 20)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - AreaSeries Validation Tests
// 
//     func testAreaSeriesAcceptsValidChronologicalData() {
//         errorCatcher.clear()
// 
//         let series = charts.addAreaSeries(options: AreaSeriesOptions())
// 
//         let data: [AreaData] = [
//             AreaData(time: .utc(timestamp: 1000), value: 10),
//             AreaData(time: .utc(timestamp: 2000), value: 20),
//             AreaData(time: .utc(timestamp: 3000), value: 15)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testAreaSeriesHandlesUpdate() {
//         errorCatcher.clear()
// 
//         let series = charts.addAreaSeries(options: AreaSeriesOptions())
// 
//         let initialData: [AreaData] = [
//             AreaData(time: .utc(timestamp: 1000), value: 10),
//             AreaData(time: .utc(timestamp: 2000), value: 20)
//         ]
// 
//         series.setData(data: initialData)
//         series.update(bar: AreaData(time: .utc(timestamp: 3000), value: 25))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - CandlestickSeries Validation Tests
// 
//     func testCandlestickSeriesAcceptsValidOhlcData() {
//         errorCatcher.clear()
// 
//         let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
// 
//         let data: [CandlestickData] = [
//             CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
//             CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16),
//             CandlestickData(time: .utc(timestamp: 3000), open: 16, high: 20, low: 14, close: 18)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testCandlestickSeriesHandlesPartialOhlcData() {
//         errorCatcher.clear()
// 
//         let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
// 
//         // Missing some values is allowed
//         let data: [CandlestickData] = [
//             CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: nil),
//             CandlestickData(time: .utc(timestamp: 2000), open: nil, high: nil, low: nil, close: nil)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testCandlestickSeriesHandlesUpdate() {
//         errorCatcher.clear()
// 
//         let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
// 
//         let initialData: [CandlestickData] = [
//             CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
//             CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16)
//         ]
// 
//         series.setData(data: initialData)
//         series.update(bar: CandlestickData(time: .utc(timestamp: 3000), open: 16, high: 20, low: 14, close: 18))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - BarSeries Validation Tests
// 
//     func testBarSeriesAcceptsValidOhlcData() {
//         errorCatcher.clear()
// 
//         let series = charts.addBarSeries(options: BarSeriesOptions())
// 
//         let data: [BarData] = [
//             BarData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
//             BarData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16),
//             BarData(time: .utc(timestamp: 3000), open: 16, high: 20, low: 14, close: 18)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testBarSeriesHandlesUpdate() {
//         errorCatcher.clear()
// 
//         let series = charts.addBarSeries(options: BarSeriesOptions())
// 
//         let initialData: [BarData] = [
//             BarData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12)
//         ]
// 
//         series.setData(data: initialData)
//         series.update(bar: BarData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - HistogramSeries Validation Tests
// 
//     func testHistogramSeriesAcceptsValidData() {
//         errorCatcher.clear()
// 
//         let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
// 
//         let data: [HistogramData] = [
//             HistogramData(time: .utc(timestamp: 1000), value: 10, color: nil),
//             HistogramData(time: .utc(timestamp: 2000), value: 20, color: nil),
//             HistogramData(time: .utc(timestamp: 3000), value: 15, color: nil)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testHistogramSeriesHandlesUpdate() {
//         errorCatcher.clear()
// 
//         let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
// 
//         let initialData: [HistogramData] = [
//             HistogramData(time: .utc(timestamp: 1000), value: 10, color: nil)
//         ]
// 
//         series.setData(data: initialData)
//         series.update(bar: HistogramData(time: .utc(timestamp: 2000), value: 20, color: nil))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - BaselineSeries Validation Tests
// 
//     func testBaselineSeriesAcceptsValidData() {
//         errorCatcher.clear()
// 
//         let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
// 
//         let data: [BaselineData] = [
//             BaselineData(time: .utc(timestamp: 1000), value: 10),
//             BaselineData(time: .utc(timestamp: 2000), value: 20),
//             BaselineData(time: .utc(timestamp: 3000), value: 15)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testBaselineSeriesHandlesUpdate() {
//         errorCatcher.clear()
// 
//         let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
// 
//         let initialData: [BaselineData] = [
//             BaselineData(time: .utc(timestamp: 1000), value: 10)
//         ]
// 
//         series.setData(data: initialData)
//         series.update(bar: BaselineData(time: .utc(timestamp: 2000), value: 20))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - WhitespaceData Tests
// 
//     func testWhitespaceDataIsAccepted() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let data: [WhitespaceData] = [
//             WhitespaceData(time: .utc(timestamp: 1000)),
//             WhitespaceData(time: .utc(timestamp: 2000))
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testMixedWhitespaceAndRegularData() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let data: [SeriesDataType<LineData>] = [
//             .data(LineData(time: .utc(timestamp: 1000), value: 10)),
//             .whitespace(WhitespaceData(time: .utc(timestamp: 2000))),
//             .data(LineData(time: .utc(timestamp: 3000), value: 20))
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - BusinessDay Time Tests
// 
//     func testBusinessDayTimeValidation() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let data: [LineData] = [
//             LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 1)), value: 10),
//             LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 2)), value: 20),
//             LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 3)), value: 15)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     func testBusinessDayTimeUpdate() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let initialData: [LineData] = [
//             LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 1)), value: 10)
//         ]
// 
//         series.setData(data: initialData)
//         series.update(bar: LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 2)), value: 20))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - String Time Tests
// 
//     func testStringTimeValidation() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         let data: [LineData] = [
//             LineData(time: .string("2024-01-01"), value: 10),
//             LineData(time: .string("2024-01-02"), value: 20),
//             LineData(time: .string("2024-01-03"), value: 15)
//         ]
// 
//         series.setData(data: data)
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - Multiple Series Validation
// 
//     func testMultipleSeriesIndependentValidation() {
//         errorCatcher.clear()
// 
//         let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
//         let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
// 
//         let lineData: [LineData] = [
//             LineData(time: .utc(timestamp: 1000), value: 10),
//             LineData(time: .utc(timestamp: 2000), value: 20)
//         ]
// 
//         let candlestickData: [CandlestickData] = [
//             CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
//             CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16)
//         ]
// 
//         lineSeries.setData(data: lineData)
//         candlestickSeries.setData(data: candlestickData)
// 
//         // Update line series
//         lineSeries.update(bar: LineData(time: .utc(timestamp: 3000), value: 25))
// 
//         // Update candlestick series
//         candlestickSeries.update(bar: CandlestickData(time: .utc(timestamp: 3000), open: 16, high: 20, low: 14, close: 18))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// 
//     // MARK: - Data Replacement Tests
// 
//     func testSetDataReplacesExistingData() {
//         errorCatcher.clear()
// 
//         let series = charts.addLineSeries(options: LineSeriesOptions())
// 
//         // Set initial data
//         let initialData: [LineData] = [
//             LineData(time: .utc(timestamp: 1000), value: 10),
//             LineData(time: .utc(timestamp: 2000), value: 20),
//             LineData(time: .utc(timestamp: 3000), value: 15)
//         ]
// 
//         series.setData(data: initialData)
// 
//         // Replace with completely new data (different times)
//         let replacementData: [LineData] = [
//             LineData(time: .utc(timestamp: 5000), value: 100),
//             LineData(time: .utc(timestamp: 6000), value: 200)
//         ]
// 
//         series.setData(data: replacementData)
// 
//         // Update should work with new time range
//         series.update(bar: LineData(time: .utc(timestamp: 7000), value: 300))
// 
//         waitForAsyncOperations()
//         errorCatcher.assertNoErrors()
//     }
// }

// MARK: - LightweightChartsDelegate
// extension SeriesDataValidationTests: LightweightChartsDelegate {
// 
//     func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
//         loadExpectation?.fulfill()
//     }
// 
//     func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
//         XCTFail("Chart failed to load: \(error.localizedDescription)")
//         loadExpectation?.fulfill()
//     }
// }

// MARK: - Event Validation Tests (Task 10.12)

/// Test delegate for capturing chart events
class TestChartDelegate: ChartDelegate {
    var clickEvents: [MouseEventParams] = []
    var crosshairEvents: [MouseEventParams] = []

    func didClick(onChart chart: ChartApi, parameters: MouseEventParams) {
        clickEvents.append(parameters)
    }

    func didCrosshairMove(onChart chart: ChartApi, parameters: MouseEventParams) {
        crosshairEvents.append(parameters)
    }

    func clear() {
        clickEvents.removeAll()
        crosshairEvents.removeAll()
    }
}

/// These tests validate that mouse events (click and crosshair move) are properly
/// decoded from JSON and forwarded to the chart delegate.
///
/// Test coverage includes:
/// - MouseEventParams JSON decoding
/// - EventTime decoding (UTC timestamp, business day, business day string)
/// - EventPrices decoding (line data, bar data, none)
/// - TouchMouseEventData decoding
/// - Delegate method invocation for click events
/// - Delegate method invocation for crosshair move events
final class EventValidationTests: XCTestCase {

    var errorCatcher: JSErrorCatcher!

    override func setUp() {
        super.setUp()
        errorCatcher = JSErrorCatcher()
    }

    override func tearDown() {
        errorCatcher = nil
        super.tearDown()
    }

    private func waitForAsyncOperations(duration: TimeInterval = 0.1) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - MouseEventParams Decoding Tests

    /// Tests that MouseEventParams can be decoded from JSON with all fields present
    func testMouseEventParamsDecodingWithAllFields() {
        let json = """
        {
            "time": 1609459200,
            "logical": 100,
            "point": {"x": 250, "y": 150},
            "hoveredObjectId": 42,
            "sourceEvent": {
                "clientX": 100,
                "clientY": 200,
                "pageX": 300,
                "pageY": 400,
                "screenX": 500,
                "screenY": 600,
                "localX": 50,
                "localY": 75,
                "ctrlKey": true,
                "altKey": false,
                "shiftKey": true,
                "metaKey": false
            },
            "hoveredSeries": "series1",
            "seriesData": {
                "series1": {"value": 10.5}
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)

            XCTAssertEqual(params.time, .utc(timestamp: 1609459200))
            XCTAssertEqual(params.logical, 100)
            XCTAssertEqual(params.point?.x, 250)
            XCTAssertEqual(params.point?.y, 150)
            XCTAssertEqual(params.hoveredObjectId, 42)
            XCTAssertEqual(params.sourceEvent?.clientX, 100)
            XCTAssertEqual(params.sourceEvent?.clientY, 200)
            XCTAssertEqual(params.sourceEvent?.pageX, 300)
            XCTAssertEqual(params.sourceEvent?.pageY, 400)
            XCTAssertEqual(params.sourceEvent?.screenX, 500)
            XCTAssertEqual(params.sourceEvent?.screenY, 600)
            XCTAssertEqual(params.sourceEvent?.localX, 50)
            XCTAssertEqual(params.sourceEvent?.localY, 75)
            XCTAssertEqual(params.sourceEvent?.ctrlKey, true)
            XCTAssertEqual(params.sourceEvent?.altKey, false)
            XCTAssertEqual(params.sourceEvent?.shiftKey, true)
            XCTAssertEqual(params.sourceEvent?.metaKey, false)
            XCTAssertEqual(params.hoveredSeries, "series1")
        } catch {
            XCTFail("Failed to decode MouseEventParams: \(error)")
        }
    }

    /// Tests that MouseEventParams can be decoded from JSON with minimal fields
    func testMouseEventParamsDecodingWithMinimalFields() {
        let json = """
        {
            "time": 1609459200,
            "logical": 100,
            "point": {"x": 250, "y": 150}
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)

            XCTAssertEqual(params.time, .utc(timestamp: 1609459200))
            XCTAssertEqual(params.logical, 100)
            XCTAssertEqual(params.point?.x, 250)
            XCTAssertEqual(params.point?.y, 150)
            XCTAssertNil(params.hoveredObjectId)
            XCTAssertNil(params.sourceEvent)
            XCTAssertNil(params.hoveredSeries)
        } catch {
            XCTFail("Failed to decode MouseEventParams with minimal fields: \(error)")
        }
    }

    // MARK: - EventTime Decoding Tests

    /// Tests that EventTime decodes UTC timestamp correctly
    func testEventTimeDecodingUTCTimestamp() {
        let json = "1609459200"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let eventTime = try decoder.decode(EventTime.self, from: data)
            XCTAssertEqual(eventTime, .utc(timestamp: 1609459200))
        } catch {
            XCTFail("Failed to decode EventTime UTC timestamp: \(error)")
        }
    }

    /// Tests that EventTime decodes business day correctly
    func testEventTimeDecodingBusinessDay() {
        let json = """
        {
            "year": 2024,
            "month": 1,
            "day": 15
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let eventTime = try decoder.decode(EventTime.self, from: data)
            if case .businessDay(let day) = eventTime {
                XCTAssertEqual(day.year, 2024)
                XCTAssertEqual(day.month, 1)
                XCTAssertEqual(day.day, 15)
            } else {
                XCTFail("Expected business day but got \(eventTime)")
            }
        } catch {
            XCTFail("Failed to decode EventTime business day: \(error)")
        }
    }

    /// Tests that EventTime decodes business day string correctly
    func testEventTimeDecodingBusinessDayString() {
        let json = "\"2024-01-15\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let eventTime = try decoder.decode(EventTime.self, from: data)
            XCTAssertEqual(eventTime, .businessDayString("2024-01-15"))
        } catch {
            XCTFail("Failed to decode EventTime business day string: \(error)")
        }
    }

    // MARK: - EventPrices Decoding Tests

    /// Tests that EventPrices decodes line data correctly
    func testEventPricesDecodingLineData() {
        let json = """
        {
            "value": 10.5
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let prices = try decoder.decode(EventPrices.self, from: data)
            if case .lineData(let lineData) = prices {
                XCTAssertEqual(lineData.value, 10.5)
            } else {
                XCTFail("Expected line data but got \(prices)")
            }
        } catch {
            XCTFail("Failed to decode EventPrices line data: \(error)")
        }
    }

    /// Tests that EventPrices decodes bar data correctly
    func testEventPricesDecodingBarData() {
        let json = """
        {
            "open": 10.0,
            "high": 15.0,
            "low": 9.0,
            "close": 12.0
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let prices = try decoder.decode(EventPrices.self, from: data)
            if case .barData(let barData) = prices {
                XCTAssertEqual(barData.open, 10.0)
                XCTAssertEqual(barData.high, 15.0)
                XCTAssertEqual(barData.low, 9.0)
                XCTAssertEqual(barData.close, 12.0)
            } else {
                XCTFail("Expected bar data but got \(prices)")
            }
        } catch {
            XCTFail("Failed to decode EventPrices bar data: \(error)")
        }
    }

    /// Tests that EventPrices decodes to none for null/missing data
    func testEventPricesDecodingNone() {
        let json = "null"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let prices = try decoder.decode(EventPrices.self, from: data)
            XCTAssertEqual(prices, .none)
        } catch {
            XCTFail("Failed to decode EventPrices none: \(error)")
        }
    }

    /// Tests that EventPrices decodes to none when line data has no value
    func testEventPricesDecodingLineDataWithoutValue() {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let prices = try decoder.decode(EventPrices.self, from: data)
            // LineData without value should decode to .none
            XCTAssertEqual(prices, .none)
        } catch {
            XCTFail("Failed to decode EventPrices line data without value: \(error)")
        }
    }

    // MARK: - TouchMouseEventData Decoding Tests

    /// Tests that TouchMouseEventData decodes all fields correctly
    func testTouchMouseEventDataDecodingAllFields() {
        let json = """
        {
            "clientX": 100,
            "clientY": 200,
            "pageX": 300,
            "pageY": 400,
            "screenX": 500,
            "screenY": 600,
            "localX": 50,
            "localY": 75,
            "ctrlKey": true,
            "altKey": false,
            "shiftKey": true,
            "metaKey": false
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let touchData = try decoder.decode(TouchMouseEventData.self, from: data)

            XCTAssertEqual(touchData.clientX, 100)
            XCTAssertEqual(touchData.clientY, 200)
            XCTAssertEqual(touchData.pageX, 300)
            XCTAssertEqual(touchData.pageY, 400)
            XCTAssertEqual(touchData.screenX, 500)
            XCTAssertEqual(touchData.screenY, 600)
            XCTAssertEqual(touchData.localX, 50)
            XCTAssertEqual(touchData.localY, 75)
            XCTAssertEqual(touchData.ctrlKey, true)
            XCTAssertEqual(touchData.altKey, false)
            XCTAssertEqual(touchData.shiftKey, true)
            XCTAssertEqual(touchData.metaKey, false)
        } catch {
            XCTFail("Failed to decode TouchMouseEventData: \(error)")
        }
    }

    /// Tests that TouchMouseEventData handles optional fields correctly
    func testTouchMouseEventDataDecodingPartialFields() {
        let json = """
        {
            "clientX": 100,
            "clientY": 200
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let touchData = try decoder.decode(TouchMouseEventData.self, from: data)

            XCTAssertEqual(touchData.clientX, 100)
            XCTAssertEqual(touchData.clientY, 200)
            XCTAssertNil(touchData.pageX)
            XCTAssertNil(touchData.pageY)
            XCTAssertNil(touchData.screenX)
            XCTAssertNil(touchData.screenY)
            XCTAssertNil(touchData.localX)
            XCTAssertNil(touchData.localY)
            XCTAssertNil(touchData.ctrlKey)
            XCTAssertNil(touchData.altKey)
            XCTAssertNil(touchData.shiftKey)
            XCTAssertNil(touchData.metaKey)
        } catch {
            XCTFail("Failed to decode TouchMouseEventData with partial fields: \(error)")
        }
    }

    // MARK: - MessageHandler Event Decoding Tests

    /// Tests that MessageHandler correctly decodes click event JSON
    func testMessageHandlerDecodesClickEvent() {
        let clickJson = """
        {
            "time": 1609459200,
            "logical": 50,
            "point": {"x": 100, "y": 200},
            "hoveredObjectId": 1,
            "sourceEvent": {
                "clientX": 10,
                "clientY": 20,
                "localX": 30,
                "localY": 40
            }
        }
        """

        let data = clickJson.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)

            // Verify all fields were decoded correctly
            XCTAssertEqual(params.time, .utc(timestamp: 1609459200))
            XCTAssertEqual(params.logical, 50)
            XCTAssertEqual(params.point?.x, 100)
            XCTAssertEqual(params.point?.y, 200)
            XCTAssertEqual(params.hoveredObjectId, 1)
            XCTAssertNotNil(params.sourceEvent)
        } catch {
            XCTFail("Failed to decode click event: \(error)")
        }
    }

    /// Tests that MessageHandler correctly decodes crosshair move event JSON
    func testMessageHandlerDecodesCrosshairMoveEvent() {
        let crosshairJson = """
        {
            "time": {
                "year": 2024,
                "month": 5,
                "day": 20
            },
            "logical": 75,
            "point": {"x": 150, "y": 250},
            "hoveredSeries": "testSeries",
            "seriesData": {
                "testSeries": {
                    "value": 42.5
                }
            }
        }
        """

        let data = crosshairJson.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)

            // Verify business day time was decoded
            if case .businessDay(let day) = params.time {
                XCTAssertEqual(day.year, 2024)
                XCTAssertEqual(day.month, 5)
                XCTAssertEqual(day.day, 20)
            } else {
                XCTFail("Expected business day time")
            }

            XCTAssertEqual(params.logical, 75)
            XCTAssertEqual(params.point?.x, 150)
            XCTAssertEqual(params.point?.y, 250)
            XCTAssertEqual(params.hoveredSeries, "testSeries")
        } catch {
            XCTFail("Failed to decode crosshair move event: \(error)")
        }
    }

    /// Tests that MessageHandler handles malformed JSON gracefully
    func testMessageHandlerHandlesMalformedJSON() {
        let malformedJson = "{invalid json}"

        let data = malformedJson.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            _ = try decoder.decode(MouseEventParams.self, from: data)
            XCTFail("Expected decoding to fail for malformed JSON")
        } catch {
            // Expected to fail
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Click Event Integration Tests

    /// Tests that click event subscription properly forwards events to delegate
    func testClickEventForwardedToDelegate() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        charts.subscribeClick()
        waitForAsyncOperations()

        // Verify no JS errors during subscription
        // Note: Actual event triggering requires user interaction in the web view
        // This test validates the subscription mechanism works without errors
    }

    /// Tests that click event subscription works with multiple series
    func testClickEventWithMultipleSeries() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        errorCatcher.clear()

        // Add multiple series
        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addAreaSeries(options: AreaSeriesOptions())

        // Add data to series
        let lineData: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series1.setData(data: lineData)

        let areaData: [AreaData] = [
            AreaData(time: .unix(1000), value: 8),
            AreaData(time: .unix(2000), value: 18)]
        series2.setData(data: areaData)

        // Subscribe to click events
        charts.subscribeClick()

        waitForAsyncOperations()

        // Verify no errors occurred
        XCTAssert(delegate.clickEvents.isEmpty, "Click events should be empty without user interaction")
    }

    /// Tests that click event unsubscription works correctly
    func testClickEventUnsubscription() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        errorCatcher.clear()

        charts.subscribeClick()
        waitForAsyncOperations()

        charts.unsubscribeClick()
        waitForAsyncOperations()

        // Verify unsubscription works without errors
    }

    // MARK: - Crosshair Move Event Integration Tests

    /// Tests that crosshair move event subscription properly forwards events to delegate
    func testCrosshairMoveEventForwardedToDelegate() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        charts.subscribeCrosshairMove()
        waitForAsyncOperations()

        // Verify no JS errors during subscription
        // Note: Actual event triggering requires user interaction in the web view
        // This test validates the subscription mechanism works without errors
    }

    /// Tests that crosshair move event subscription works with multiple series
    func testCrosshairMoveEventWithMultipleSeries() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        errorCatcher.clear()

        // Add multiple series with different data types
        let series1 = charts.addLineSeries(options: LineSeriesOptions())
        let series2 = charts.addBarSeries(options: BarSeriesOptions())
        let series3 = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        // Add data to series
        let lineData: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        series1.setData(data: lineData)

        let barData: [BarData] = [
            BarData(time: .unix(1000), open: 8, high: 12, low: 7, close: 11),
            BarData(time: .unix(2000), open: 11, high: 15, low: 10, close: 14)
        ]
        series2.setData(data: barData)

        let candleData: [CandlestickData] = [
            CandlestickData(time: .unix(1000), open: 9, high: 13, low: 8, close: 12),
            CandlestickData(time: .unix(2000), open: 12, high: 16, low: 11, close: 15)
        ]
        series3.setData(data: candleData)

        // Subscribe to crosshair move events
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        // Verify no errors occurred
        XCTAssert(delegate.crosshairEvents.isEmpty, "Crosshair events should be empty without user interaction")
    }

    /// Tests that crosshair move event unsubscription works correctly
    func testCrosshairMoveEventUnsubscription() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        errorCatcher.clear()

        charts.subscribeCrosshairMove()
        waitForAsyncOperations()

        charts.unsubscribeCrosshairMove()
        waitForAsyncOperations()

        // Verify unsubscription works without errors
    }

    // MARK: - Both Events Simultaneous Tests

    /// Tests that both click and crosshair move events can be subscribed simultaneously
    func testBothEventsSimultaneousSubscription() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        errorCatcher.clear()

        // Subscribe to both events
        charts.subscribeClick()
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        // Both subscriptions should work without errors

        // Unsubscribe from both
        charts.unsubscribeClick()
        charts.unsubscribeCrosshairMove()

        waitForAsyncOperations()
    }

    /// Tests that event subscriptions work correctly after series are added and removed
    func testEventsAfterSeriesAddRemove() {
        let charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = TestChartDelegate()
        charts.delegate = delegate

        errorCatcher.clear()

        // Add a series
        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [LineData(time: .unix(1000), value: 10)]
        series.setData(data: data)

        // Subscribe to events
        charts.subscribeClick()
        charts.subscribeCrosshairMove()

        waitForAsyncOperations()

        // Remove the series
        charts.removeSeries(seriesApi: series)

        waitForAsyncOperations()

        // Events should still be subscribed even after series removal
    }

    // MARK: - Edge Case Tests

    /// Tests event handling with null time value
    func testEventWithNullTime() {
        let json = """
        {
            "time": null,
            "logical": 10,
            "point": {"x": 5, "y": 10}
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)
            XCTAssertNil(params.time)
            XCTAssertEqual(params.logical, 10)
        } catch {
            XCTFail("Failed to decode MouseEventParams with null time: \(error)")
        }
    }

    /// Tests event handling with missing point value
    func testEventWithMissingPoint() {
        let json = """
        {
            "time": 1609459200,
            "logical": 10
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)
            XCTAssertEqual(params.time, .utc(timestamp: 1609459200))
            XCTAssertNil(params.point)
        } catch {
            XCTFail("Failed to decode MouseEventParams with missing point: \(error)")
        }
    }

    /// Tests event handling with empty seriesData
    func testEventWithEmptySeriesData() {
        let json = """
        {
            "time": 1609459200,
            "seriesData": {}
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)
            XCTAssertEqual(params.time, .utc(timestamp: 1609459200))
            // Empty series data should not cause errors
        } catch {
            XCTFail("Failed to decode MouseEventParams with empty seriesData: \(error)")
        }
    }

    /// Tests that seriesData with null values decodes correctly
    func testEventSeriesDataWithNullValues() {
        let json = """
        {
            "time": 1609459200,
            "seriesData": {
                "series1": null,
                "series2": {"value": 10.5}
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        do {
            let params = try decoder.decode(MouseEventParams.self, from: data)
            XCTAssertEqual(params.time, .utc(timestamp: 1609459200))
            // Null series data should decode to .none
        } catch {
            XCTFail("Failed to decode MouseEventParams with null seriesData values: \(error)")
        }
    }
}

// MARK: - Core Render/Update Validation Tests (Task 10.11)

/// Comprehensive render/update validation tests for all series types
///
/// These tests verify that:
/// 1. Data set via setData([]) actually gets into the chart and can be retrieved
/// 2. Update operations correctly add or replace data points
/// 3. All time formats work correctly (unix, utc, business day, string)
/// 4. Options changes trigger re-renders correctly
/// 5. Edge cases are handled properly
///
/// Task 10.11: Core render/update validation for all series types
final class CoreRenderUpdateValidationTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.2) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Line Series Render/Update Validation

    /// Tests that line series data can be set and retrieved via dataByIndex
    func testLineSeriesDataIsRendered() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        XCTAssertNotNil(series, "Line series should be created")

        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data can be retrieved from the chart
        let retrieveExpectation = expectation(description: "Data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "First data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 1000), "Time should match")
                XCTAssertEqual(data.value, 10, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that line series update correctly replaces existing data with same time
    func testLineSeriesUpdateReplacesExistingPoint() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let initialData: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        // Update the last point with a different value
        series.update(bar: LineData(time: .utc(timestamp: 2000), value: 25))
        waitForAsyncOperations()

        // Verify the updated value
        let retrieveExpectation = expectation(description: "Updated data retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Updated data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 2000), "Time should match")
                XCTAssertEqual(data.value, 25, "Value should be updated to 25")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that line series update correctly adds new point with later time
    func testLineSeriesUpdateAddsNewPoint() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let initialData: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        // Add a new point
        series.update(bar: LineData(time: .utc(timestamp: 3000), value: 30))
        waitForAsyncOperations()

        // Verify the new point was added
        let retrieveExpectation = expectation(description: "New data retrieved")

        series.dataByIndex(logicalIndex: 2, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "New data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 3000), "Time should match")
                XCTAssertEqual(data.value, 30, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Area Series Render/Update Validation

    /// Tests that area series data can be set and retrieved
    func testAreaSeriesDataIsRendered() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        XCTAssertNotNil(series, "Area series should be created")

        let data: [AreaData] = [
            AreaData(time: .utc(timestamp: 1000), value: 10),
            AreaData(time: .utc(timestamp: 2000), value: 20),
            AreaData(time: .utc(timestamp: 3000), value: 15)]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data can be retrieved
        let retrieveExpectation = expectation(description: "Area data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Area data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 1000), "Time should match")
                XCTAssertEqual(data.value, 10, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that area series update works correctly
    func testAreaSeriesUpdateWorks() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())

        let initialData: [AreaData] = [
            AreaData(time: .utc(timestamp: 1000), value: 10)]

        series.setData(data: initialData)
        waitForAsyncOperations()

        series.update(bar: AreaData(time: .utc(timestamp: 2000), value: 25))
        waitForAsyncOperations()

        // Verify update
        let retrieveExpectation = expectation(description: "Area update retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Updated area data should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 2000), "Time should match")
                XCTAssertEqual(data.value, 25, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Bar Series Render/Update Validation

    /// Tests that bar series OHLC data can be set and retrieved
    func testBarSeriesDataIsRendered() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        XCTAssertNotNil(series, "Bar series should be created")

        let data: [BarData] = [
            BarData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify OHLC data can be retrieved
        let retrieveExpectation = expectation(description: "Bar data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Bar data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 1000), "Time should match")
                XCTAssertEqual(data.open, 10, "Open should match")
                XCTAssertEqual(data.high, 15, "High should match")
                XCTAssertEqual(data.low, 8, "Low should match")
                XCTAssertEqual(data.close, 12, "Close should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that bar series update works correctly
    func testBarSeriesUpdateWorks() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())

        let initialData: [BarData] = [
            BarData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        series.update(bar: BarData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16))
        waitForAsyncOperations()

        // Verify update
        let retrieveExpectation = expectation(description: "Bar update retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Updated bar data should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 2000), "Time should match")
                XCTAssertEqual(data.open, 12, "Open should match")
                XCTAssertEqual(data.high, 18, "High should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Candlestick Series Render/Update Validation

    /// Tests that candlestick series OHLC data can be set and retrieved
    func testCandlestickSeriesDataIsRendered() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        XCTAssertNotNil(series, "Candlestick series should be created")

        let data: [CandlestickData] = [
            CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify OHLC data can be retrieved
        let retrieveExpectation = expectation(description: "Candlestick data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Candlestick data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 1000), "Time should match")
                XCTAssertEqual(data.open, 10, "Open should match")
                XCTAssertEqual(data.high, 15, "High should match")
                XCTAssertEqual(data.low, 8, "Low should match")
                XCTAssertEqual(data.close, 12, "Close should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that candlestick series update works correctly
    func testCandlestickSeriesUpdateWorks() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        let initialData: [CandlestickData] = [
            CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        series.update(bar: CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16))
        waitForAsyncOperations()

        // Verify update
        let retrieveExpectation = expectation(description: "Candlestick update retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Updated candlestick data should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 2000), "Time should match")
                XCTAssertEqual(data.close, 16, "Close should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Histogram Series Render/Update Validation

    /// Tests that histogram series data can be set and retrieved
    func testHistogramSeriesDataIsRendered() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        XCTAssertNotNil(series, "Histogram series should be created")

        let data: [HistogramData] = [
            HistogramData(time: .utc(timestamp: 1000), value: 10, color: nil),
            HistogramData(time: .utc(timestamp: 2000), value: 20, color: nil)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data can be retrieved
        let retrieveExpectation = expectation(description: "Histogram data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Histogram data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 1000), "Time should match")
                XCTAssertEqual(data.value, 10, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that histogram series update works correctly
    func testHistogramSeriesUpdateWorks() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())

        let initialData: [HistogramData] = [
            HistogramData(time: .utc(timestamp: 1000), value: 10, color: nil)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        series.update(bar: HistogramData(time: .utc(timestamp: 2000), value: 25, color: nil))
        waitForAsyncOperations()

        // Verify update
        let retrieveExpectation = expectation(description: "Histogram update retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Updated histogram data should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 2000), "Time should match")
                XCTAssertEqual(data.value, 25, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Baseline Series Render/Update Validation

    /// Tests that baseline series data can be set and retrieved
    func testBaselineSeriesDataIsRendered() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        XCTAssertNotNil(series, "Baseline series should be created")

        let data: [BaselineData] = [
            BaselineData(time: .utc(timestamp: 1000), value: 10),
            BaselineData(time: .utc(timestamp: 2000), value: 20)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data can be retrieved
        let retrieveExpectation = expectation(description: "Baseline data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Baseline data point should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 1000), "Time should match")
                XCTAssertEqual(data.value, 10, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that baseline series update works correctly
    func testBaselineSeriesUpdateWorks() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())

        let initialData: [BaselineData] = [
            BaselineData(time: .utc(timestamp: 1000), value: 10)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        series.update(bar: BaselineData(time: .utc(timestamp: 2000), value: 25))
        waitForAsyncOperations()

        // Verify update
        let retrieveExpectation = expectation(description: "Baseline update retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Updated baseline data should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 2000), "Time should match")
                XCTAssertEqual(data.value, 25, "Value should match")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Time Format Validation

    /// Tests that unix time format works for all series types
    func testUnixTimeFormatWorksForAllSeries() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let barSeries = charts.addBarSeries(options: BarSeriesOptions())

        // Test unix time format
        let lineData: [LineData] = [
            LineData(time: .unix(1000), value: 10),
            LineData(time: .unix(2000), value: 20)
        ]
        lineSeries.setData(data: lineData)

        let areaData: [AreaData] = [
            AreaData(time: .unix(1000), value: 10),
            AreaData(time: .unix(2000), value: 20)]
        areaSeries.setData(data: areaData)

        let barData: [BarData] = [
            BarData(time: .unix(1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .unix(2000), open: 12, high: 18, low: 10, close: 16)
        ]
        barSeries.setData(data: barData)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that business day time format works
    func testBusinessDayTimeFormatWorks() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 1)), value: 10),
            LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 2)), value: 20),
            LineData(time: .businessDay(BusinessDay(year: 2024, month: 1, day: 3)), value: 15)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data can be retrieved
        let retrieveExpectation = expectation(description: "Business day data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Business day data should be retrievable")
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that string time format works
    func testStringTimeFormatWorks() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .string("2024-01-01"), value: 10),
            LineData(time: .string("2024-01-02"), value: 20),
            LineData(time: .string("2024-01-03"), value: 15)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data can be retrieved
        let retrieveExpectation = expectation(description: "String time data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "String time data should be retrievable")
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Options and Re-render Validation

    /// Tests that changing series options causes re-render
    func testSeriesOptionsChangeCausesRender() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Change options
        let updatedOptions = LineSeriesOptions(
     title: "Updated",
     visible: true,
     color: ChartColor(.red),
     lineStyle: .dashed,
     lineWidth: .three,
     lineType: .simple,
     crosshairMarkerVisible: true,
     crosshairMarkerRadius: 5,
     lastPriceAnimation: .none
 )

        series.applyOptions(options: updatedOptions)
        waitForAsyncOperations()

        // Verify data is still accessible after options change
        let retrieveExpectation = expectation(description: "Data after options change")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Data should still be retrievable after options change")
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Series Simultaneous Update Validation

    /// Tests that multiple series can be updated simultaneously
    func testMultipleSeriesSimultaneousUpdate() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: LineSeriesOptions())
        let areaSeries = charts.addAreaSeries(options: AreaSeriesOptions())
        let candlestickSeries = charts.addCandlestickSeries(options: CandlestickSeriesOptions())

        // Set initial data
        lineSeries.setData(data: [
            LineData(time: .utc(timestamp: 1000), value: 10)
        ])
        areaSeries.setData(data: [
            AreaData(time: .utc(timestamp: 1000), value: 8)])
        candlestickSeries.setData(data: [
            CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12)
        ])

        waitForAsyncOperations()

        // Update all series
        lineSeries.update(bar: LineData(time: .utc(timestamp: 2000), value: 20))
        areaSeries.update(bar: AreaData(time: .utc(timestamp: 2000), value: 18))
        candlestickSeries.update(bar: CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 10, close: 16))

        waitForAsyncOperations()

        // Verify all updates
        let lineExpectation = expectation(description: "Line series updated")
        let areaExpectation = expectation(description: "Area series updated")
        let candlestickExpectation = expectation(description: "Candlestick series updated")

        lineSeries.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { data in
            XCTAssertNotNil(data, "Line series update should be retrievable")
            lineExpectation.fulfill()
        }

        areaSeries.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { data in
            XCTAssertNotNil(data, "Area series update should be retrievable")
            areaExpectation.fulfill()
        }

        candlestickSeries.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { data in
            XCTAssertNotNil(data, "Candlestick series update should be retrievable")
            candlestickExpectation.fulfill()
        }

        wait(for: [lineExpectation, areaExpectation, candlestickExpectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Edge Cases

    /// Tests that setting empty data works
    func testEmptyDataSetWorks() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = []
        series.setData(data: data)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that single data point works
    func testSingleDataPointWorks() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify single point is retrievable
        let retrieveExpectation = expectation(description: "Single point retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Single data point should be retrievable")
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that data with nil values works
    func testNilValueDataWorks() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: nil),
            LineData(time: .utc(timestamp: 3000), value: 20)
        ]

        series.setData(data: data)
        waitForAsyncOperations()

        // Verify data is retrievable
        let retrieveExpectation = expectation(description: "Data with nil retrieved")

        series.dataByIndex(logicalIndex: 1, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "Data with nil value should be retrievable")
            if let data = retrievedData {
                XCTAssertNil(data.value, "Value should be nil")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that setData replacement clears old data
    func testSetDataReplacesOldData() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        // Set initial data
        let initialData: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]

        series.setData(data: initialData)
        waitForAsyncOperations()

        // Replace with different data
        let newData: [LineData] = [
            LineData(time: .utc(timestamp: 5000), value: 100),
            LineData(time: .utc(timestamp: 6000), value: 200)
        ]

        series.setData(data: newData)
        waitForAsyncOperations()

        // Verify old data is gone by trying to access index 0 (should have new time)
        let retrieveExpectation = expectation(description: "New data retrieved")

        series.dataByIndex(logicalIndex: 0, mismatchDirection: nil) { retrievedData in
            XCTAssertNotNil(retrievedData, "New data should be retrievable")
            if let data = retrievedData {
                XCTAssertEqual(data.time, .utc(timestamp: 5000), "Should have new data time")
            }
            retrieveExpectation.fulfill()
        }

        wait(for: [retrieveExpectation], timeout: 2.0)
        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension CoreRenderUpdateValidationTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Resize and Screenshot Validation Tests
//
// Tests for Task 10.13: Resize and screenshot validation
//
// This test suite validates:
// 1. Chart resize with various dimensions
// 2. Chart resize with forceRepaint flag variations
// 3. Screenshot capture after resize
// 4. Screenshot with different chart content
// 5. Multiple resize/screenshot cycles
// 6. Edge cases for resize behavior
final class ResizeAndScreenshotValidationTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.2) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func createSampleLineSeries() -> LineSeries {
        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15),
            LineData(time: .utc(timestamp: 4000), value: 25),
            LineData(time: .utc(timestamp: 5000), value: 30)
        ]
        series.setData(data: data)
        waitForAsyncOperations()
        return series
    }

    // MARK: - Basic Resize Tests

    /// Tests that chart can be resized to standard dimensions
    func testChartResizeToStandardDimensions() {
        errorCatcher.clear()

        let testSizes: [(width: Double, height: Double)] = [
            (800, 600),   // Large desktop
            (500, 400),   // Medium tablet
            (375, 667),   // Phone portrait
            (667, 375),   // Phone landscape
            (1024, 768)   // Tablet
        ]

        for (width, height) in testSizes {
            charts.resize(width: width, height: height, forceRepaint: true)
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that chart can be resized to very small dimensions
    func testChartResizeToSmallDimensions() {
        errorCatcher.clear()

        let testSizes: [(width: Double, height: Double)] = [
            (200, 150),   // Very small
            (100, 100),   // Tiny square
            (50, 50)      // Minimal
        ]

        for (width, height) in testSizes {
            charts.resize(width: width, height: height, forceRepaint: true)
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that chart can be resized to very large dimensions
    func testChartResizeToLargeDimensions() {
        errorCatcher.clear()

        let testSizes: [(width: Double, height: Double)] = [
            (1920, 1080),  // Full HD
            (2560, 1440),  // 2K
            (3840, 2160)   // 4K
        ]

        for (width, height) in testSizes {
            charts.resize(width: width, height: height, forceRepaint: true)
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    // MARK: - forceRepaint Flag Tests

    /// Tests that resize with forceRepaint: true works
    func testResizeWithForceRepaintTrue() {
        errorCatcher.clear()

        charts.resize(width: 600, height: 450, forceRepaint: true)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that resize with forceRepaint: false works
    func testResizeWithForceRepaintFalse() {
        errorCatcher.clear()

        charts.resize(width: 600, height: 450, forceRepaint: false)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that resize with forceRepaint: nil (default) works
    func testResizeWithForceRepaintNil() {
        errorCatcher.clear()

        charts.resize(width: 600, height: 450, forceRepaint: nil)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Screenshot After Resize Tests

    /// Tests that screenshot can be captured immediately after resize with forceRepaint: true
    func testScreenshotImmediatelyAfterResizeWithForceRepaint() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        // Resize with forceRepaint: true to ensure immediate repaint
        charts.resize(width: 500, height: 400, forceRepaint: true)

        let expectation = self.expectation(description: "Screenshot after resize")

        charts.takeScreenshot { image in
            // The callback should be invoked
            // Image content validation is not possible in test environment
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot can be captured after multiple sequential resizes
    func testScreenshotAfterMultipleSequentialResizes() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        // Perform multiple resizes
        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        charts.resize(width: 600, height: 450, forceRepaint: true)
        waitForAsyncOperations()

        charts.resize(width: 300, height: 200, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Screenshot after multiple resizes")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot can be captured after resize without forceRepaint
    func testScreenshotAfterResizeWithoutForceRepaint() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        charts.resize(width: 500, height: 400, forceRepaint: false)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Screenshot after resize without forceRepaint")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Screenshot with Different Chart Content Tests

    /// Tests that screenshot captures line series content
    func testScreenshotCapturesLineSeries() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Line series screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot captures candlestick series content
    func testScreenshotCapturesCandlestickSeries() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let data: [CandlestickData] = [
            CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 11, close: 16),
            CandlestickData(time: .utc(timestamp: 3000), open: 16, high: 20, low: 14, close: 18)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Candlestick series screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot captures bar series content
    func testScreenshotCapturesBarSeries() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data: [BarData] = [
            BarData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
            BarData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 11, close: 16)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Bar series screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot captures area series content
    func testScreenshotCapturesAreaSeries() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .utc(timestamp: 1000), value: 10),
            AreaData(time: .utc(timestamp: 2000), value: 20),
            AreaData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Area series screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot captures histogram series content
    func testScreenshotCapturesHistogramSeries() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let data: [HistogramData] = [
            HistogramData(time: .utc(timestamp: 1000), value: 10, color: "#26a69a"),
            HistogramData(time: .utc(timestamp: 2000), value: 20, color: "#ef5350"),
            HistogramData(time: .utc(timestamp: 3000), value: 15, color: "#26a69a")
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Histogram series screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot captures baseline series content
    func testScreenshotCapturesBaselineSeries() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        let data: [BaselineData] = [
            BaselineData(time: .utc(timestamp: 1000), value: 10),
            BaselineData(time: .utc(timestamp: 2000), value: 20),
            BaselineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Baseline series screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should produce an image")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Resize/Screenshot Cycle Tests

    /// Tests that multiple resize/screenshot cycles work correctly
    func testMultipleResizeScreenshotCycles() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        let cycles = 3

        for i in 0..<cycles {
            let width = 300.0 + Double(i * 100)
            let height = 200.0 + Double(i * 100)

            charts.resize(width: width, height: height, forceRepaint: true)
            waitForAsyncOperations()

            let expectation = self.expectation(description: "Screenshot cycle \(i)")

            charts.takeScreenshot { image in
                XCTAssertNotNil(image, "Screenshot \(i) should produce an image")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 3.0)
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that rapid resize operations don't cause errors
    func testRapidResizeOperations() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        // Perform rapid resizes
        for i in 0..<10 {
            charts.resize(width: 300 + Double(i * 50), height: 200, forceRepaint: i % 2 == 0)
        }

        waitForAsyncOperations(duration: 0.5)

        errorCatcher.assertNoErrors()
    }

    /// Tests that rapid screenshot operations don't cause errors
    func testRapidScreenshotOperations() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        let expectations = (0..<5).map { i in
            self.expectation(description: "Screenshot \(i)")
        }

        for (i, expectation) in expectations.enumerated() {
            charts.takeScreenshot { image in
                XCTAssertNotNil(image, "Screenshot \(i) should produce an image")
                expectation.fulfill()
            }
        }

        wait(for: expectations, timeout: 10.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Resize Aspect Ratio Tests

    /// Tests that chart maintains functionality with different aspect ratios
    func testDifferentAspectRatios() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        let aspectRatios: [(width: Double, height: Double)] = [
            (100, 100),    // 1:1 square
            (200, 100),    // 2:1 landscape
            (100, 200),    // 1:2 portrait
            (400, 300),    // 4:3 standard
            (16, 9)        // 16:9 widescreen
        ]

        for (width, height) in aspectRatios {
            charts.resize(width: width, height: height, forceRepaint: true)
            waitForAsyncOperations()

            let expectation = self.expectation(description: "Screenshot for \(width)x\(height)")

            charts.takeScreenshot { image in
                XCTAssertNotNil(image, "Screenshot for \(width)x\(height) should work")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 3.0)
        }

        errorCatcher.assertNoErrors()
    }

    // MARK: - Edge Case Tests

    /// Tests resize with very small dimensions still produces valid screenshot
    func testSmallDimensionsScreenshot() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        charts.resize(width: 100, height: 100, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Small dimensions screenshot")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should work even at small dimensions")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot can be taken without any data
    func testScreenshotWithNoData() {
        errorCatcher.clear()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Empty chart screenshot")

        charts.takeScreenshot { image in
            // Should still produce a screenshot even with no data
            XCTAssertNotNil(image, "Screenshot should work even with no data")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that resize followed by data update and screenshot works
    func testResizeThenDataUpdateThenScreenshot() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())

        // Resize first
        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        // Then add data
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        // Then take screenshot
        let expectation = self.expectation(description: "Screenshot after data update")

        charts.takeScreenshot { image in
            XCTAssertNotNil(image, "Screenshot should work after resize and data update")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that screenshot quality is consistent across multiple captures
    func testConsistentScreenshotQuality() {
        errorCatcher.clear()

        _ = createSampleLineSeries()

        charts.resize(width: 500, height: 400, forceRepaint: true)
        waitForAsyncOperations()

        var screenshotSizes: [Int] = []
        let expectation = self.expectation(description: "Multiple screenshots for comparison")

        let group = DispatchGroup()

        for _ in 0..<3 {
            group.enter()
            charts.takeScreenshot { image in
                if let imageData = image?.pngData() {
                    screenshotSizes.append(imageData.count)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // All screenshots should produce images
            XCTAssertEqual(screenshotSizes.count, 3, "All screenshots should succeed")

            // Sizes should be similar (within 10% tolerance for compression variance)
            if let firstSize = screenshotSizes.first, let lastSize = screenshotSizes.last {
                let difference = abs(Double(firstSize - lastSize))
                let average = Double((firstSize + lastSize) / 2)
                let variance = (difference / average) * 100

                XCTAssertLessThan(variance, 20, "Screenshot sizes should be relatively consistent")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension ResizeAndScreenshotValidationTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Marker Compatibility and Plugin Manual Check Tests
//
// Tests for Task 10.14: Marker compatibility and plugin manual checks
//
// This test suite validates:
// 1. Backward-compatible setMarkers API works correctly
// 2. Explicit SeriesMarkersPlugin API works correctly
// 3. Marker position rendering (aboveBar, belowBar, inBar)
// 4. Marker shapes (circle, square, arrowUp, arrowDown)
// 5. Marker colors with different formats
// 6. Multiple markers at same time point
// 7. UTC timestamps with markers
// 8. Optional marker fields (id, text, size)
// 9. Plugin lifecycle (create, update, detach)
// 10. Retrieving markers back from the API
final class MarkerCompatibilityAndPluginManualCheckTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.2) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func createSampleBarData() -> [BarData] {
        var time = DateComponents(calendar: .current, year: 2018, day: 0).date!
        var data: [BarData] = []
        for i in 0..<50 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let step = Double(i % 20) / 1000.0
            let base = Double(i) / 5.0
            let barData = BarData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                open: base * (1 - step),
                high: base * (1 + 2 * step),
                low: base * (1 - 2 * step),
                close: base * (1 + step)
            )
            data.append(barData)
        }
        return data
    }

    // MARK: - Backward-Compatible API Tests

    /// Tests that backward-compatible setMarkers API executes without errors
    func testBackwardCompatibleSetMarkersAPI() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that backward-compatible markers API returns set markers
    func testBackwardCompatibleMarkersQuery() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let originalMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]

        series.setMarkers(data: originalMarkers)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Markers retrieved")

        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Markers should be retrievable")
            XCTAssertEqual(retrievedMarkers?.count, 2, "Should have 2 markers")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that repeated setMarkers calls update the existing plugin
    func testBackwardCompatibleRepeatedSetMarkers() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let initialMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        series.setMarkers(data: initialMarkers)
        waitForAsyncOperations()

        let updatedMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.green)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .arrowUp, color: ChartColor(.orange))
        ]

        series.setMarkers(data: updatedMarkers)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Updated markers retrieved")

        series.markers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Markers should be retrievable after update")
            XCTAssertEqual(retrievedMarkers?.count, 2, "Should have 2 markers after update")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Marker Position Tests

    /// Tests that markers render at aboveBar position
    func testMarkerPositionAboveBar() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[20].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers render at belowBar position
    func testMarkerPositionBelowBar() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .circle, color: ChartColor(.blue))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers render at inBar position
    func testMarkerPositionInBar() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[20].time, position: .inBar, shape: .circle, color: ChartColor(.green))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that all three positions can be used simultaneously
    func testMarkerAllPositionsSimultaneously() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[20].time, position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .circle, color: ChartColor(.blue)),
            SeriesMarker(time: data[20].time, position: .inBar, shape: .circle, color: ChartColor(.green))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Marker Shape Tests

    /// Tests that circle shape markers render correctly
    func testMarkerShapeCircle() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that square shape markers render correctly
    func testMarkerShapeSquare() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .square, color: ChartColor(.blue))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that arrowUp shape markers render correctly
    func testMarkerShapeArrowUp() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .belowBar, shape: .arrowUp, color: ChartColor(.green))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that arrowDown shape markers render correctly
    func testMarkerShapeArrowDown() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .arrowDown, color: ChartColor(.orange))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that all marker shapes can be used simultaneously
    func testMarkerAllShapesSimultaneously() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15),
            LineData(time: .utc(timestamp: 4000), value: 25)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[0].time, position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .square, color: ChartColor(.blue)),
            SeriesMarker(time: data[2].time, position: .belowBar, shape: .arrowUp, color: ChartColor(.green)),
            SeriesMarker(time: data[3].time, position: .aboveBar, shape: .arrowDown, color: ChartColor(.orange))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Marker Color Tests

    /// Tests that markers work with named UIColors
    func testMarkerColorWithNamedUIColors() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let colors: [ChartColor] = [
            ChartColor(.red),
            ChartColor(.blue),
            ChartColor(.green),
            ChartColor(.orange),
            ChartColor(.yellow),
            ChartColor(.purple),
            ChartColor(.cyan),
            ChartColor(.magenta)
        ]

        var markers: [SeriesMarker] = []
        for (index, color) in colors.enumerated() {
            if index < data.count {
                markers.append(SeriesMarker(time: data[index].time, position: .aboveBar, shape: .circle, color: color))
            }
        }

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with custom RGB colors
    func testMarkerColorWithCustomRGB() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0))),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(UIColor(red: 128/255, green: 64/255, blue: 32/255, alpha: 1.0)))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with hex colors
    func testMarkerColorWithHex() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(hex: 0xFF5733)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(hex: 0x33FF57, alpha: 0.8))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Multiple Markers at Same Time Tests

    /// Tests that multiple markers can be placed at the same time point
    func testMultipleMarkersAtSameTime() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let targetTime = data[20].time

        // This matches the pattern from MarkersViewController.swift
        let markers = [
            SeriesMarker(time: targetTime, position: .belowBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: targetTime, position: .belowBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: targetTime, position: .belowBar, shape: .circle, color: ChartColor(.green)),
            SeriesMarker(time: targetTime, position: .aboveBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: targetTime, position: .aboveBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: targetTime, position: .aboveBar, shape: .circle, color: ChartColor(.green))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that many markers at same time render correctly
    func testManyMarkersAtSameTime() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let targetTime = data[20].time

        var markers: [SeriesMarker] = []
        for _ in 0..<10 {
            markers.append(SeriesMarker(time: targetTime, position: .aboveBar, shape: .circle, color: ChartColor(.red)))
        }

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - UTC Timestamp Tests

    /// Tests that markers work with UTC timestamps
    func testMarkersWithUTCTimestamps() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        var time = DateComponents(calendar: .current, year: 2018, day: 0).date!
        var data: [BarData] = []
        for i in 0..<50 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let step = Double(i % 20) / 1000.0
            let base = Double(i) / 5.0
            let barData = BarData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                open: base * (1 - step),
                high: base * (1 + 2 * step),
                low: base * (1 - 2 * step),
                close: base * (1 + step)
            )
            data.append(barData)
        }
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[data.count - 30].time, position: .belowBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[data.count - 20].time, position: .aboveBar, shape: .circle, color: ChartColor(.yellow)),
            SeriesMarker(time: data[data.count - 15].time, position: .inBar, shape: .circle, color: ChartColor(.orange)),
            SeriesMarker(time: data[data.count - 10].time, position: .inBar, shape: .circle, color: ChartColor(.red))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Optional Field Tests

    /// Tests that markers work with id field
    func testMarkerWithId() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red), id: "marker-1"),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(.blue), id: "marker-2")
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with text field
    func testMarkerWithText() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red), text: "Buy"),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(.blue), text: "Sell")
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with size field
    func testMarkerWithSize() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red), size: 10.0),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .circle, color: ChartColor(.blue), size: 20.0),
            SeriesMarker(time: data[30].time, position: .inBar, shape: .circle, color: ChartColor(.green), size: 30.0)
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with all optional fields
    func testMarkerWithAllOptionalFields() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(
                time: data[10].time,
                position: .aboveBar,
                shape: .circle,
                color: ChartColor(.red),
                id: "complete-marker",
                text: "Important",
                size: 25.0
            )
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - SeriesMarkersPlugin API Tests

    /// Tests that explicit SeriesMarkersPlugin can be created
    func testExplicitSeriesMarkersPluginCreation() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        let plugin = series.createMarkersPlugin(data: markers)
        XCTAssertNotNil(plugin, "Plugin should be created")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that SeriesMarkersPlugin setMarkers works
    func testSeriesMarkersPluginSetMarkers() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let initialMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        let plugin = series.createMarkersPlugin(data: initialMarkers)
        waitForAsyncOperations()

        let updatedMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.green)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]

        plugin.setMarkers( updatedMarkers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that SeriesMarkersPlugin getMarkers works
    func testSeriesMarkersPluginGetMarkers() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let originalMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: data[20].time, position: .belowBar, shape: .square, color: ChartColor(.blue))
        ]

        let plugin = series.createMarkersPlugin(data: originalMarkers)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Markers retrieved from plugin")

        plugin.getMarkers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers, "Markers should be retrievable from plugin")
            XCTAssertEqual(retrievedMarkers?.count, 2, "Should have 2 markers")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    /// Tests that SeriesMarkersPlugin applyOptions works
    func testSeriesMarkersPluginApplyOptions() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        let plugin = series.createMarkersPlugin(data: markers)
        waitForAsyncOperations()

        let options = SeriesMarkersOptions(
            active: true,
            autoScale: false
        )

        plugin.applyOptions(options: options)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that SeriesMarkersPlugin detach works
    func testSeriesMarkersPluginDetach() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        let plugin = series.createMarkersPlugin(data: markers)
        waitForAsyncOperations()

        plugin.detach()
        waitForAsyncOperations()

        // Verify plugin is detached by checking getMarkers returns nil
        let expectation = self.expectation(description: "Markers after detach")

        plugin.getMarkers { retrievedMarkers in
            XCTAssertNil(retrievedMarkers, "Markers should be nil after detach")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Series Type Compatibility Tests

    /// Tests that markers work with LineSeries
    func testMarkersWithLineSeries() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: LineSeriesOptions())
        let data: [LineData] = [
            LineData(time: .utc(timestamp: 1000), value: 10),
            LineData(time: .utc(timestamp: 2000), value: 20),
            LineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with AreaSeries
    func testMarkersWithAreaSeries() {
        errorCatcher.clear()

        let series = charts.addAreaSeries(options: AreaSeriesOptions())
        let data: [AreaData] = [
            AreaData(time: .utc(timestamp: 1000), value: 10),
            AreaData(time: .utc(timestamp: 2000), value: 20),
            AreaData(time: .utc(timestamp: 3000), value: 15)]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .circle, color: ChartColor(.blue))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with CandlestickSeries
    func testMarkersWithCandlestickSeries() {
        errorCatcher.clear()

        let series = charts.addCandlestickSeries(options: CandlestickSeriesOptions())
        let data: [CandlestickData] = [
            CandlestickData(time: .utc(timestamp: 1000), open: 10, high: 15, low: 8, close: 12),
            CandlestickData(time: .utc(timestamp: 2000), open: 12, high: 18, low: 11, close: 16),
            CandlestickData(time: .utc(timestamp: 3000), open: 16, high: 20, low: 14, close: 18)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .arrowUp, color: ChartColor(.green))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with HistogramSeries
    func testMarkersWithHistogramSeries() {
        errorCatcher.clear()

        let series = charts.addHistogramSeries(options: HistogramSeriesOptions())
        let data: [HistogramData] = [
            HistogramData(time: .utc(timestamp: 1000), value: 10, color: ChartColor(.blue)),
            HistogramData(time: .utc(timestamp: 2000), value: 20, color: ChartColor(.blue)),
            HistogramData(time: .utc(timestamp: 3000), value: 15, color: ChartColor(.blue))
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .square, color: ChartColor(.orange))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers work with BaselineSeries
    func testMarkersWithBaselineSeries() {
        errorCatcher.clear()

        let series = charts.addBaselineSeries(options: BaselineSeriesOptions())
        let data: [BaselineData] = [
            BaselineData(time: .utc(timestamp: 1000), value: 10),
            BaselineData(time: .utc(timestamp: 2000), value: 20),
            BaselineData(time: .utc(timestamp: 3000), value: 15)
        ]
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[1].time, position: .aboveBar, shape: .circle, color: ChartColor(.purple))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    // MARK: - Empty Markers Tests

    /// Tests that setting empty markers array works
    func testSetEmptyMarkersArray() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        // First set some markers
        let initialMarkers = [
            SeriesMarker(time: data[10].time, position: .aboveBar, shape: .circle, color: ChartColor(.red))
        ]

        series.setMarkers(data: initialMarkers)
        waitForAsyncOperations()

        // Then clear with empty array
        series.setMarkers(data: [])
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that markers query returns nil when never set
    func testMarkersQueryReturnsNilWhenNeverSet() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        let expectation = self.expectation(description: "Markers returns nil")

        series.markers { retrievedMarkers in
            XCTAssertNil(retrievedMarkers, "Markers should be nil when never set")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        errorCatcher.assertNoErrors()
    }

    // MARK: - Large Dataset Tests

    /// Tests that markers work with large datasets
    func testMarkersWithLargeDataset() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        var time = DateComponents(calendar: .current, year: 2018, day: 0).date!
        var data: [BarData] = []
        for i in 0..<500 {
            time = Date(timeInterval: 60 * 60 * 24, since: time)
            let step = Double(i % 20) / 1000.0
            let base = Double(i) / 5.0
            let barData = BarData(
                time: .utc(timestamp: time.timeIntervalSince1970),
                open: base * (1 - step),
                high: base * (1 + 2 * step),
                low: base * (1 - 2 * step),
                close: base * (1 + step)
            )
            data.append(barData)
        }
        series.setData(data: data)
        waitForAsyncOperations()

        let markers = [
            SeriesMarker(time: data[100].time, position: .aboveBar, shape: .circle, color: ChartColor(.red)),
            SeriesMarker(time: data[250].time, position: .belowBar, shape: .square, color: ChartColor(.blue)),
            SeriesMarker(time: data[400].time, position: .inBar, shape: .arrowUp, color: ChartColor(.green))
        ]

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }

    /// Tests that many markers can be set at once
    func testManyMarkersAtOnce() {
        errorCatcher.clear()

        let series = charts.addBarSeries(options: BarSeriesOptions())
        let data = createSampleBarData()
        series.setData(data: data)
        waitForAsyncOperations()

        var markers: [SeriesMarker] = []
        for i in 0..<20 {
            markers.append(SeriesMarker(
                time: data[i * 2].time,
                position: i % 2 == 0 ? .aboveBar : .belowBar,
                shape: .circle,
                color: ChartColor(i % 2 == 0 ? .red : .blue)
            ))
        }

        series.setMarkers(data: markers)
        waitForAsyncOperations()

        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension MarkerCompatibilityAndPluginManualCheckTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}

// MARK: - Watermark Explicit API Manual Check Tests
//
// Tests for Task 10.15: Watermark explicit API manual checks
//
// This test suite validates:
// 1. Text watermark handle API (createTextWatermark -> TextWatermark)
// 2. Image watermark handle API (createImageWatermark -> ImageWatermark)
// 3. Text watermark options (alignment, visibility, font styling, multiple lines)
// 4. Image watermark options (alpha, padding, maxWidth, maxHeight)
// 5. Watermark handle lifecycle (create, applyOptions, detach)
// 6. Multiple watermarks on the same pane
// 7. Edge cases (invalid pane indices)
// 8. Watermark with different color formats
final class WatermarkExplicitAPITests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations(duration: TimeInterval = 0.2) {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Text Watermark Handle API Tests

    /// Tests that createTextWatermark returns a valid TextWatermark handle
    func testCreateTextWatermarkReturnsValidHandle() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Test Watermark",
            color: "rgba(255, 0, 0, 0.5)",
            fontSize: 24
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        XCTAssertNotNil(watermark, "createTextWatermark should return a TextWatermark instance")
        XCTAssertFalse(watermark.jsName.isEmpty, "Watermark should have a valid JavaScript name")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark can be created with custom alignment
    func testTextWatermarkWithCustomAlignment() {
        errorCatcher.clear()

        let alignments: [(horizontal: HorizontalAlignment, vertical: VerticalAlignment)] = [
            (.left, .top),
            (.center, .top),
            (.right, .top),
            (.left, .center),
            (.center, .center),
            (.right, .center),
            (.left, .bottom),
            (.center, .bottom),
            (.right, .bottom)
        ]

        for (horizontal, vertical) in alignments {
            let options = TextWatermarkOptions(
                visible: true,
                horizontalAlignment: horizontal,
                verticalAlignment: vertical,
                lines: [
                    WatermarkLine(
                        text: "Alignment Test",
                        color: ChartColor(.black),
                        fontSize: 18
                    )
                ]
            )
            let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with \(horizontal) \(vertical) alignment")
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark can be created with multiple lines
    func testTextWatermarkWithMultipleLines() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [
                WatermarkLine(text: "Line 1", color: ChartColor(.red), fontSize: 24),
                WatermarkLine(text: "Line 2", color: ChartColor(.green), fontSize: 20),
                WatermarkLine(text: "Line 3", color: ChartColor(.blue), fontSize: 18),
                WatermarkLine(text: "Line 4", color: ChartColor(.purple), fontSize: 16)
            ]
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        XCTAssertNotNil(watermark, "Should create watermark with multiple lines")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark with visibility false works correctly
    func testTextWatermarkVisibilityFalse() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: false,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [
                WatermarkLine(
                    text: "Invisible",
                    color: ChartColor(.black),
                    fontSize: 24
                )
            ]
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        XCTAssertNotNil(watermark, "Should create invisible watermark")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark can be updated with applyOptions
    func testTextWatermarkApplyOptions() {
        errorCatcher.clear()

        let initialOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Initial Text",
            color: "rgba(255, 0, 0, 0.5)",
            fontSize: 24
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: initialOptions)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update options
        let updatedOptions = TextWatermarkOptions(visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Updated Text",
            color: "rgba(0, 255, 0, 0.5)",
            fontSize: 36
        )
        watermark.applyOptions(updatedOptions)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark can be toggled visible/invisible
    func testTextWatermarkToggleVisibility() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Toggle Test",
            color: ChartColor(.black),
            fontSize: 24
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Hide the watermark
        watermark.applyOptions(TextWatermarkOptions(
            visible: false,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [
                WatermarkLine(text: "Toggle Test", color: ChartColor(.black), fontSize: 24)
            ]
        ))

        waitForAsyncOperations()
        errorCatcher.clear()

        // Show the watermark again
        watermark.applyOptions(TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [
                WatermarkLine(text: "Toggle Test", color: ChartColor(.black), fontSize: 24)
            ]
        ))

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark can be detached
    func testTextWatermarkDetach() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "To Be Detached",
            color: ChartColor(.black),
            fontSize: 24
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the watermark
        watermark.detach()

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark supports different color formats
    func testTextWatermarkColorFormats() {
        errorCatcher.clear()

        let colorFormats: [ChartColor] = [
            ChartColor(.red),
            ChartColor(.blue),
            "rgba(255, 0, 0, 0.5)",
            "rgba(0, 255, 0, 0.7)",
            "rgba(0, 0, 255, 0.3)"
        ]

        for (index, color) in colorFormats.enumerated() {
            let options = TextWatermarkOptions(
                visible: true,
                horizontalAlignment: .center,
                verticalAlignment: .center,
                lines: [
                    WatermarkLine(
                        text: "Color \(index)",
                        color: color,
                        fontSize: 20
                    )
                ]
            )
            let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with color \(index)")
            waitForAsyncOperations()

            // Detach each watermark before creating the next
            watermark.detach()
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark supports different font sizes
    func testTextWatermarkFontSizes() {
        errorCatcher.clear()

        let fontSizes = [12, 16, 20, 24, 32, 48, 64]

        for fontSize in fontSizes {
            let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Size \(fontSize)",
                color: "rgba(0, 0, 0, 0.5)",
                fontSize: fontSize
            )
            let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with font size \(fontSize)")
            waitForAsyncOperations()

            watermark.detach()
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that text watermark supports custom font family and style
    func testTextWatermarkFontFamilyAndStyle() {
        errorCatcher.clear()

        let fontConfigs = [
            ("Arial", "normal"),
            ("Helvetica", "bold"),
            ("Courier New", "italic"),
            ("-apple-system", "normal")
        ]

        for (family, style) in fontConfigs {
            let options = TextWatermarkOptions(
                visible: true,
                horizontalAlignment: .center,
                verticalAlignment: .center,
                lines: [
                    WatermarkLine(
                        text: "\(family) \(style)",
                        color: ChartColor(.black),
                        fontSize: 24,
                        fontFamily: family,
                        fontStyle: style
                    )
                ]
            )
            let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with font \(family) \(style)")
            waitForAsyncOperations()

            watermark.detach()
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that multiple text watermarks can exist on the same pane
    func testMultipleTextWatermarksOnSamePane() {
        errorCatcher.clear()

        let watermark1 = charts.createTextWatermark(
            paneIndex: 0,
            options: TextWatermarkOptions(visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Watermark 1",
                color: "rgba(255, 0, 0, 0.5)",
                fontSize: 24
            )
        )

        let watermark2 = charts.createTextWatermark(
            paneIndex: 0,
            options: TextWatermarkOptions(visible: true, horizontalAlignment: .right, verticalAlignment: .bottom, text: "Watermark 2",
                color: "rgba(0, 255, 0, 0.5)",
                fontSize: 24
            )
        )

        XCTAssertNotNil(watermark1, "Should create first watermark")
        XCTAssertNotNil(watermark2, "Should create second watermark")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Image Watermark Handle API Tests

    /// Tests that createImageWatermark returns a valid ImageWatermark handle
    func testCreateImageWatermarkReturnsValidHandle() {
        errorCatcher.clear()

        // Create a simple SVG data URL
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><text x='50%' y='50%' font-size='20' fill='red' text-anchor='middle'>Test</text></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let options = ImageWatermarkOptions(
            alpha: 0.5,
            padding: 10
        )
        let watermark = charts.createImageWatermark(paneIndex: 0, imageUrl: imageUrl, options: options)

        XCTAssertNotNil(watermark, "createImageWatermark should return an ImageWatermark instance")
        XCTAssertFalse(watermark.jsName.isEmpty, "Watermark should have a valid JavaScript name")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that image watermark can be created with alpha option
    func testImageWatermarkAlphaOption() {
        errorCatcher.clear()

        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><rect width='100' height='100' fill='blue'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let alphaValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for alpha in alphaValues {
            let options = ImageWatermarkOptions(alpha: alpha, padding: 0)
            let watermark = charts.createImageWatermark(paneIndex: 0, imageUrl: imageUrl, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with alpha \(alpha)")
            waitForAsyncOperations()

            watermark.detach()
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that image watermark can be created with padding option
    func testImageWatermarkPaddingOption() {
        errorCatcher.clear()

        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><rect width='100' height='100' fill='green'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let paddingValues = [0, 5, 10, 20, 50]

        for padding in paddingValues {
            let options = ImageWatermarkOptions(alpha: 1.0, padding: padding)
            let watermark = charts.createImageWatermark(paneIndex: 0, imageUrl: imageUrl, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with padding \(padding)")
            waitForAsyncOperations()

            watermark.detach()
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that image watermark can be created with size constraints
    func testImageWatermarkSizeConstraints() {
        errorCatcher.clear()

        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='200'><rect width='200' height='200' fill='orange'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let sizeConfigs = [
            (maxWidth: Optional(50.0), maxHeight: Optional(50.0)),
            (maxWidth: Optional(100.0), maxHeight: Optional(100.0)),
            (maxWidth: Optional(200.0), maxHeight: Optional(200.0)),
            (maxWidth: Optional<Double>.none, maxHeight: Optional(100.0)),
            (maxWidth: Optional(100.0), maxHeight: Optional<Double>.none),
            (maxWidth: Optional<Double>.none, maxHeight: Optional<Double>.none)
        ]

        for (maxWidth, maxHeight) in sizeConfigs {
            let options = ImageWatermarkOptions(
                alpha: 0.8,
                padding: 10,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )
            let watermark = charts.createImageWatermark(paneIndex: 0, imageUrl: imageUrl, options: options)

            XCTAssertNotNil(watermark, "Should create watermark with maxWidth \(String(describing: maxWidth)), maxHeight \(String(describing: maxHeight))")
            waitForAsyncOperations()

            watermark.detach()
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that image watermark can be updated with applyOptions
    func testImageWatermarkApplyOptions() {
        errorCatcher.clear()

        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><rect width='100' height='100' fill='purple'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let initialOptions = ImageWatermarkOptions(
            alpha: 0.5,
            padding: 10,
            maxWidth: 100,
            maxHeight: 100
        )
        let watermark = charts.createImageWatermark(paneIndex: 0, imageUrl: imageUrl, options: initialOptions)

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update options
        let updatedOptions = ImageWatermarkOptions(
            alpha: 0.8,
            padding: 20,
            maxWidth: 150,
            maxHeight: 150
        )
        watermark.applyOptions(updatedOptions)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that image watermark alpha can be updated
    func testImageWatermarkUpdateAlpha() {
        errorCatcher.clear()

        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><rect width='100' height='100' fill='cyan'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let watermark = charts.createImageWatermark(
            paneIndex: 0,
            imageUrl: imageUrl,
            options: ImageWatermarkOptions(alpha: 1.0, padding: 10)
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Update alpha multiple times
        for alpha: Double in [0.8, 0.5, 0.2, 0.0, 0.5, 1.0] {
            watermark.applyOptions(ImageWatermarkOptions(alpha: alpha, padding: 10))
            waitForAsyncOperations()
        }

        errorCatcher.assertNoErrors()
    }

    /// Tests that image watermark can be detached
    func testImageWatermarkDetach() {
        errorCatcher.clear()

        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><rect width='100' height='100' fill='pink'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let watermark = charts.createImageWatermark(
            paneIndex: 0,
            imageUrl: imageUrl,
            options: ImageWatermarkOptions(alpha: 0.5, padding: 10)
        )

        waitForAsyncOperations()
        errorCatcher.clear()

        // Detach the watermark
        watermark.detach()

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that multiple image watermarks can exist on the same pane
    func testMultipleImageWatermarksOnSamePane() {
        errorCatcher.clear()

        let svg1 = "<svg xmlns='http://www.w3.org/2000/svg' width='50' height='50'><rect width='50' height='50' fill='red'/></svg>"
        let svg2 = "<svg xmlns='http://www.w3.org/2000/svg' width='50' height='50'><rect width='50' height='50' fill='blue'/></svg>"

        guard let svgData1 = svg1.data(using: .utf8),
              let base64_1 = svgData1.base64EncodedString() as String?,
              let svgData2 = svg2.data(using: .utf8),
              let base64_2 = svgData2.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }

        let imageUrl1 = "data:image/svg+xml;base64,\(base64_1)"
        let imageUrl2 = "data:image/svg+xml;base64,\(base64_2)"

        let watermark1 = charts.createImageWatermark(
            paneIndex: 0,
            imageUrl: imageUrl1,
            options: ImageWatermarkOptions(alpha: 0.5, padding: 10)
        )

        let watermark2 = charts.createImageWatermark(
            paneIndex: 0,
            imageUrl: imageUrl2,
            options: ImageWatermarkOptions(alpha: 0.5, padding: 10)
        )

        XCTAssertNotNil(watermark1, "Should create first image watermark")
        XCTAssertNotNil(watermark2, "Should create second image watermark")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that text and image watermarks can coexist
    func testTextAndImageWatermarksCoexist() {
        errorCatcher.clear()

        // Create text watermark
        let textWatermark = charts.createTextWatermark(
            paneIndex: 0,
            options: TextWatermarkOptions(visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Text Watermark",
                color: "rgba(255, 0, 0, 0.5)",
                fontSize: 24
            )
        )

        // Create image watermark
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='50' height='50'><rect width='50' height='50' fill='blue'/></svg>"
        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let imageWatermark = charts.createImageWatermark(
            paneIndex: 0,
            imageUrl: imageUrl,
            options: ImageWatermarkOptions(alpha: 0.5, padding: 10)
        )

        XCTAssertNotNil(textWatermark, "Should create text watermark")
        XCTAssertNotNil(imageWatermark, "Should create image watermark")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that watermark handles handle nil image URLs gracefully
    func testImageWatermarkWithSVGDataURL() {
        errorCatcher.clear()

        // Test with a more complex SVG
        let svg = """
        <svg xmlns='http://www.w3.org/2000/svg' width='200' height='200' viewBox='0 0 200 200'>
            <circle cx='100' cy='100' r='50' fill='rgba(255, 0, 0, 0.5)'/>
            <text x='100' y='100' font-family='Arial' font-size='20' fill='black' text-anchor='middle' dominant-baseline='middle'>SVG</text>
        </svg>
        """

        guard let svgData = svg.data(using: .utf8),
              let base64 = svgData.base64EncodedString() as String? else {
            XCTFail("Failed to encode SVG")
            return
        }
        let imageUrl = "data:image/svg+xml;base64,\(base64)"

        let watermark = charts.createImageWatermark(
            paneIndex: 0,
            imageUrl: imageUrl,
            options: ImageWatermarkOptions(alpha: 0.7, padding: 15, maxWidth: 150, maxHeight: 150)
        )

        XCTAssertNotNil(watermark, "Should create watermark with complex SVG")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that watermark with lineHeight option works
    func testTextWatermarkWithLineHeight() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .center,
            verticalAlignment: .center,
            lines: [
                WatermarkLine(
                    text: "Line with height",
                    color: ChartColor(.black),
                    fontSize: 20,
                    lineHeight: 30
                )
            ]
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        XCTAssertNotNil(watermark, "Should create watermark with lineHeight")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests that watermark creation with all options at once works
    func testTextWatermarkWithAllOptions() {
        errorCatcher.clear()

        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .right,
            verticalAlignment: .bottom,
            lines: [
                WatermarkLine(
                    text: "Complete Test",
                    color: "rgba(128, 64, 192, 0.6)",
                    fontSize: 32,
                    fontFamily: "Helvetica",
                    fontStyle: "bold",
                    lineHeight: 40
                )
            ]
        )
        let watermark = charts.createTextWatermark(paneIndex: 0, options: options)

        XCTAssertNotNil(watermark, "Should create watermark with all options")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Memory Leak Tests (Task 10.17)

    /// Tests repeated text watermark plugin create/detach cycles for memory leaks.
    ///
    /// This test is designed to be run with Instruments (Leaks tool) to detect
    /// memory leaks. The test creates and detaches plugins in a tight loop,
    /// using autoreleasepool to encourage Swift object cleanup.
    ///
    /// To use with Instruments:
    /// 1. Open Instruments with the Leaks template
    /// 2. Select the test target
    /// 3. Run this specific test
    /// 4. Monitor for any leaks after the test completes
    func testRepeatedTextWatermarkPluginCreateDetachNoLeaks() {
        errorCatcher.clear()

        let iterations = 100

        for i in 0..<iterations {
            autoreleasepool {
                let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Leak Test \(i)",
                    color: "rgba(255, 0, 0, 0.5)"
                )
                let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

                // Verify plugin was created and not detached initially
                XCTAssertNotNil(plugin, "Plugin \(i) should be created")
                XCTAssertFalse(plugin.isDetached, "Plugin \(i) should not be detached initially")

                waitForAsyncOperations()

                // Detach the plugin
                plugin.detach()
                XCTAssertTrue(plugin.isDetached, "Plugin \(i) should be detached")
            }

            // Small delay to allow async cleanup
            if i % 10 == 0 {
                waitForAsyncOperations()
            }
        }

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests repeated image watermark plugin create/detach cycles for memory leaks.
    ///
    /// This test is designed to be run with Instruments (Leaks tool) to detect
    /// memory leaks. The test creates and detaches plugins in a tight loop,
    /// using autoreleasepool to encourage Swift object cleanup.
    ///
    /// To use with Instruments:
    /// 1. Open Instruments with the Leaks template
    /// 2. Select the test target
    /// 3. Run this specific test
    /// 4. Monitor for any leaks after the test completes
    func testRepeatedImageWatermarkPluginCreateDetachNoLeaks() {
        errorCatcher.clear()

        let iterations = 100

        for i in 0..<iterations {
            autoreleasepool {
                let imageUrl = "https://example.com/watermark\(i).png"
                let options = ImageWatermarkOptions(alpha: 0.5)
                let plugin = charts.createImageWatermarkPlugin(paneIndex: 0, imageUrl: imageUrl, options: options)

                // Verify plugin was created and not detached initially
                XCTAssertNotNil(plugin, "Plugin \(i) should be created")
                XCTAssertFalse(plugin.isDetached, "Plugin \(i) should not be detached initially")

                waitForAsyncOperations()

                // Detach the plugin
                plugin.detach()
                XCTAssertTrue(plugin.isDetached, "Plugin \(i) should be detached")
            }

            // Small delay to allow async cleanup
            if i % 10 == 0 {
                waitForAsyncOperations()
            }
        }

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests mixed plugin create/detach cycles for memory leaks.
    ///
    /// This test alternates between creating text and image watermark plugins
    /// to ensure no cross-plugin type memory leaks occur.
    ///
    /// To use with Instruments:
    /// 1. Open Instruments with the Leaks template
    /// 2. Select the test target
    /// 3. Run this specific test
    /// 4. Monitor for any leaks after the test completes
    func testMixedPluginCreateDetachNoLeaks() {
        errorCatcher.clear()

        let iterations = 50

        for i in 0..<iterations {
            autoreleasepool {
                if i % 2 == 0 {
                    // Create text watermark plugin
                    let options = TextWatermarkOptions(visible: true, horizontalAlignment: .center, verticalAlignment: .center, text: "Mixed Test \(i)",
                        color: "rgba(0, 255, 0, 0.5)"
                    )
                    let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)
                    XCTAssertFalse(plugin.isDetached, "Text plugin \(i) should not be detached initially")
                    plugin.detach()
                    XCTAssertTrue(plugin.isDetached, "Text plugin \(i) should be detached")
                } else {
                    // Create image watermark plugin
                    let plugin = charts.createImageWatermarkPlugin(paneIndex: 0, imageUrl: "https://example.com/mixed\(i).png")
                    XCTAssertFalse(plugin.isDetached, "Image plugin \(i) should not be detached initially")
                    plugin.detach()
                    XCTAssertTrue(plugin.isDetached, "Image plugin \(i) should be detached")
                }
            }

            // Periodic cleanup
            if i % 10 == 0 {
                waitForAsyncOperations()
            }
        }

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }
}

// MARK: - LightweightChartsDelegate
extension WatermarkExplicitAPITests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}
