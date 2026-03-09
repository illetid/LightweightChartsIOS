import XCTest
@testable import LightweightCharts

/// Tests that validate the examples in PLUGIN_GUIDE.md compile correctly.
///
/// These tests serve as documentation verification - they ensure that the
/// code examples provided in the plugin guide are syntactically correct
/// and use valid API signatures.
final class PluginGuideTests: XCTestCase {

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

    // MARK: - Plugin Protocol Conformance Tests

    /// Validates that all built-in plugins conform to the Plugin protocol
    func testAllPluginsConformToPluginProtocol() {
        errorCatcher.clear()

        // Series plugins
        let lineSeries = charts.addLineSeries(options: nil)
        let markersPlugin = lineSeries.createMarkersPlugin(data: [])

        XCTAssertNotNil(markersPlugin, "SeriesMarkersPlugin should conform to Plugin")
        XCTAssertFalse(markersPlugin.isDetached, "Newly created plugin should not be detached")

        markersPlugin.detach()
        XCTAssertTrue(markersPlugin.isDetached, "Plugin should be detached after detach() call")

        // Pane plugins
        let textWatermarkOptions = TextWatermarkOptions(
            visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Test", color: "rgba(0,0,0,0.3)", fontSize: 24
        )
        let textWatermarkPlugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: textWatermarkOptions)

        XCTAssertNotNil(textWatermarkPlugin, "TextWatermarkPlugin should conform to Plugin")
        XCTAssertFalse(textWatermarkPlugin.isDetached, "Newly created plugin should not be detached")

        textWatermarkPlugin.detach()
        XCTAssertTrue(textWatermarkPlugin.isDetached, "Plugin should be detached after detach() call")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Validates that plugins with options conform to PluginWithOptions
    func testPluginsWithOptionsConformToProtocol() {
        let series = charts.addLineSeries(options: nil)

        let markersPlugin = series.createMarkersPlugin(
            data: [],
            options: SeriesMarkersOptions()
        )

        let pluginWithOptions: any PluginWithOptions = markersPlugin
        _ = pluginWithOptions

        // Test applyOptions
        let newOptions = SeriesMarkersOptions()
        markersPlugin.applyOptions(options: newOptions)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Series Plugin Tests

    /// Validates SeriesMarkersPlugin usage as documented in PLUGIN_GUIDE.md
    func testSeriesMarkersPluginUsage() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: nil)

        // Create markers as shown in the guide
        let markers: [SeriesMarker] = [
            SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowDown, color: "#ff0000"),
            SeriesMarker(time: .unix(2000), position: .belowBar, shape: .arrowUp, color: "#00ff00")
        ]

        let plugin = series.createMarkersPlugin(
            data: markers,
            options: SeriesMarkersOptions()
        )

        XCTAssertNotNil(plugin)
        XCTAssertFalse(plugin.isDetached)

        // Test setMarkers
        let newMarkers: [SeriesMarker] = [
            SeriesMarker(time: .unix(3000), position: .aboveBar, shape: .circle, color: "#0000ff")
        ]
        plugin.setMarkers(newMarkers)

        // Test getMarkers
        let expectation = self.expectation(description: "Get markers")
        plugin.getMarkers { retrievedMarkers in
            XCTAssertNotNil(retrievedMarkers)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // Test applyOptions
        plugin.applyOptions(options: SeriesMarkersOptions())

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Validates UpDownMarkersPlugin usage as documented in PLUGIN_GUIDE.md
    func testUpDownMarkersPluginUsage() {
        errorCatcher.clear()

        let lineSeries = charts.addLineSeries(options: nil)

        // Create markers as shown in the guide
        let markers: [SeriesUpDownMarker] = [
            SeriesUpDownMarker(time: .unix(1000), value: 100, sign: .positive),
            SeriesUpDownMarker(time: .unix(2000), value: 100, sign: .negative)
        ]

        let plugin = lineSeries.createUpDownMarkersPlugin(
            data: markers,
            options: UpDownMarkersOptions(
                positiveColor: "#00ff00",
                negativeColor: "#ff0000"
            )
        )

        XCTAssertNotNil(plugin)
        XCTAssertFalse(plugin.isDetached)

        // Test setMarkers
        let newMarkers: [SeriesUpDownMarker] = [
            SeriesUpDownMarker(time: .unix(3000), value: 100, sign: .positive)
        ]
        plugin.setMarkers(newMarkers)

        // Test update (calculates sign automatically)
        plugin.update(LineData(time: .unix(3000), value: 100))

        // Test setMarkers alias
        plugin.setMarkers(newMarkers)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Pane Plugin Tests

    /// Validates TextWatermarkPlugin usage as documented in PLUGIN_GUIDE.md
    func testTextWatermarkPluginUsage() {
        errorCatcher.clear()

        // Create options as shown in the guide
        let options = TextWatermarkOptions(
            visible: true,
            horizontalAlignment: .right,
            verticalAlignment: .bottom,
            text: "Confidential",
            color: ChartColor(UIColor(red: 255/255, green: 0, blue: 0, alpha: 0.3)),
            fontSize: 48
        )

        let plugin = charts.createTextWatermarkPlugin(
            paneIndex: 0,
            options: options
        )

        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.paneIndex, 0)
        XCTAssertFalse(plugin.isDetached)

        // Test setText
        plugin.setText("Draft")

        // Test setVisible
        plugin.setVisible(false)

        // Test applyOptions
        plugin.applyOptions(options: TextWatermarkOptions(visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Draft", color: "rgba(0,0,0,0.3)"))

        // Test getVisible
        let expectation = self.expectation(description: "Get visible state")
        plugin.getVisible { visible in
            XCTAssertNotNil(visible)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Validates ImageWatermarkPlugin usage as documented in PLUGIN_GUIDE.md
    func testImageWatermarkPluginUsage() {
        errorCatcher.clear()

        // Use a data URL for testing (no network dependency)
        let dataUrl = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

        // Create options as shown in the guide
        let options = ImageWatermarkOptions(
            alpha: 0.5,
            padding: 10,
            maxWidth: 200,
            maxHeight: 200
        )

        let plugin = charts.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: dataUrl,
            options: options
        )

        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.paneIndex, 0)
        XCTAssertFalse(plugin.isDetached)

        // Test setAlpha
        plugin.setAlpha(0.3)

        // Test updateImage
        let newDataUrl = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAABCAYAAAD5PA/NAAAADElEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        plugin.updateImage(url: newDataUrl)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Plugin Lifecycle Tests

    /// Tests plugin detach behavior
    func testPluginDetachBehavior() {
        errorCatcher.clear()

        let series = charts.addLineSeries(options: nil)
        let plugin = series.createMarkersPlugin(data: [])

        XCTAssertFalse(plugin.isDetached, "Plugin should not be detached initially")

        plugin.detach()

        XCTAssertTrue(plugin.isDetached, "Plugin should be detached after detach() call")
        XCTAssertNil(plugin.series, "Series reference should be cleared after detach")

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    /// Tests multiple detach calls are safe
    func testMultipleDetachCallsAreSafe() {
        let series = charts.addLineSeries(options: nil)
        let plugin = series.createMarkersPlugin(data: [])

        plugin.detach()
        plugin.detach()  // Second call should be safe

        XCTAssertTrue(plugin.isDetached)
    }

    /// Tests that pane index is correctly stored
    func testPanePluginStoresCorrectPaneIndex() {
        let options = TextWatermarkOptions(
            visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Test", color: "rgba(0,0,0,0.3)", fontSize: 24
        )

        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        XCTAssertEqual(plugin.paneIndex, 0, "Plugin should store paneIndex 0")
    }

    // MARK: - Adapter Access Tests

    /// Tests that series plugins can access JavaScript evaluation helpers
    func testSeriesPluginAdapterProvidesEvaluationHelpers() {
        let series = charts.addLineSeries(options: nil)
        let plugin = series.createMarkersPlugin(data: [])

        // Verify the adapter provides the expected properties
        XCTAssertNotNil(plugin.jsName, "Plugin should have a jsName")
        XCTAssertNotNil(plugin.series, "Plugin should have a series reference")

        plugin.detach()
        waitForAsyncOperations()
    }

    /// Tests that pane plugins can access the pane expression
    func testPanePluginAdapterProvidesPaneExpression() {
        // This test verifies the infrastructure is in place
        // The paneExpression() is used internally by pane plugins
        let options = TextWatermarkOptions(
            visible: true, horizontalAlignment: .left, verticalAlignment: .top, text: "Test", color: "rgba(0,0,0,0.3)", fontSize: 24
        )

        let plugin = charts.createTextWatermarkPlugin(paneIndex: 0, options: options)

        // Verify the plugin was created successfully (which uses paneExpression internally)
        XCTAssertNotNil(plugin)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperations() {
        let expectation = self.expectation(description: "Async operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - LightweightChartsDelegate

extension PluginGuideTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}
