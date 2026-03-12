import XCTest
import UIKit
import WebKit
@testable import LightweightCharts

private protocol OptionalMarker {
    static var nilValue: Any { get }
}

extension Optional: OptionalMarker {
    static var nilValue: Any { Self.none as Any }
}

@MainActor
final class Tests: XCTestCase {

    final class MockBridge: JavaScriptEvaluator, JavaScriptMessageProducer, JavaScriptCallbackEvaluator {
        private(set) var submittedScripts: [String] = []
        private(set) var evaluatedScripts: [String] = []
        private(set) var callbackEvaluatedScripts: [String] = []
        private(set) var messageHandlerNames: [String] = []
        var evaluateHandler: ((String, Any.Type) throws -> Any?)?
        var decodedResultHandler: ((String, Any.Type) throws -> Any?)?

        private func bridgeValue<T>(from value: Any?, as type: T.Type) throws -> T {
            if let typedValue = value as? T {
                return typedValue
            }

            if value == nil, let optionalType = T.self as? OptionalMarker.Type {
                return optionalType.nilValue as! T
            }

            throw JavaScriptBridgeError.contextUnavailable
        }

        func submitScript(_ script: String) {
            submittedScripts.append(script)
        }

        func evaluateScript(_ script: String) async throws(JavaScriptBridgeError) -> Any? {
            throw JavaScriptBridgeError.contextUnavailable
        }

        func evaluate<T: Decodable>(script: String, resultType: T.Type) async throws(JavaScriptBridgeError) -> T {
            evaluatedScripts.append(script)
            do {
                let value = try bridgeValue(from: try evaluateHandler?(script, resultType), as: resultType)
                return value
            } catch {
                throw JavaScriptBridgeError.wrap(error, script: script)
            }
        }

        func decodedResult<T: Decodable>(forScript script: String) async throws(JavaScriptBridgeError) -> T {
            evaluatedScripts.append(script)
            do {
                let value = try bridgeValue(from: try decodedResultHandler?(script, T.self), as: T.self)
                return value
            } catch {
                throw JavaScriptBridgeError.wrap(error, script: script)
            }
        }

        func evaluate<T: Decodable>(
            script: String,
            resultType: T.Type,
            completion: @escaping (Result<T, Error>) -> Void
        ) {
            callbackEvaluatedScripts.append(script)
            do {
                let value = try bridgeValue(from: try evaluateHandler?(script, resultType), as: resultType)
                completion(.success(value))
            } catch {
                completion(.failure(error))
            }
        }

        func decodedResult<T: Decodable>(
            forScript script: String,
            completion: @escaping (Result<T, Error>) -> Void
        ) {
            callbackEvaluatedScripts.append(script)
            do {
                let value = try bridgeValue(from: try decodedResultHandler?(script, T.self), as: T.self)
                completion(.success(value))
            } catch {
                completion(.failure(error))
            }
        }

        func addMessageHandler(_ messageHandler: WKScriptMessageHandler, name: String) {
            messageHandlerNames.append(name)
        }
    }

    final class TestPaneReadPlugin: PanePluginAdapter<Chart> {
        func readValue(completion: @escaping (Int?) -> Void) {
            decodedResult(forScript: "1 + 1") { (result: Int?) in
                completion(result)
            }
        }
    }

    final class ChartDelegateSpy: ChartDelegate {
        private(set) var clickParameters: MouseEventParams?
        private(set) var deliveredOnMainThread = false

        func didClick(onChart chart: any ChartApi, parameters: MouseEventParams) {
            deliveredOnMainThread = Thread.isMainThread
            clickParameters = parameters
        }

        func didDoubleClick(onChart chart: any ChartApi, parameters: MouseEventParams) {
        }

        func didCrosshairMove(onChart chart: any ChartApi, parameters: MouseEventParams) {
        }
    }

    final class TimeScaleDelegateSpy: TimeScaleDelegate {
        private(set) var visibleTimeRange: TimeRange?
        private(set) var deliveredOnMainThread = false

        func didVisibleTimeRangeChange(onTimeScale timeScale: any TimeScaleApi, parameters: TimeRange?) {
            deliveredOnMainThread = Thread.isMainThread
            visibleTimeRange = parameters
        }

        func didVisibleLogicalRangeChange(onTimeScale timeScale: any TimeScaleApi, parameters: LogicalRange?) {
        }

        func didReceiveTimeScaleSizeChangeWithParameters(onTimeScale timeScale: any TimeScaleApi, parameters: Rectangle?) {
        }
    }

    final class LightweightChartsDelegateSpy: LightweightChartsDelegate {
        private(set) var didLoad = false
        private(set) var loadError: Error?

        func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
            didLoad = true
        }

        func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
            loadError = error
        }
    }

    func testSeriesMutationsSubmitInCallOrder() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        series.setData(data: [
            LineData(time: .utc(timestamp: 1), value: 10),
            LineData(time: .utc(timestamp: 2), value: 11)
        ])
        series.update(bar: LineData(time: .utc(timestamp: 3), value: 12))

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(series.jsName).setData("))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(series.jsName).update("))
    }

    func testSeriesSetDataRejectsDuplicateTimesBeforeBridgeSubmit() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        series.setDataValidationEnabled(true)

        series.setData(data: [
            LineData(time: .utc(timestamp: 1), value: 10),
            LineData(time: .utc(timestamp: 1), value: 11)
        ])

        XCTAssertEqual(bridge.submittedScripts.count, 0)
    }

    func testSeriesUpdateRejectsEarlierTimeBeforeBridgeSubmit() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        series.setDataValidationEnabled(true)

        series.setData(data: [
            LineData(time: .utc(timestamp: 2), value: 12)
        ])
        series.update(bar: LineData(time: .utc(timestamp: 1), value: 11))

        XCTAssertEqual(bridge.submittedScripts.count, 1)
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(series.jsName).setData("))
    }

    func testSeriesValidationCanBeDisabledForSetData() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        XCTAssertFalse(series.isDataValidationEnabled)
        series.setDataValidationEnabled(true)
        XCTAssertTrue(series.isDataValidationEnabled)
        series.setDataValidationEnabled(false)
        XCTAssertFalse(series.isDataValidationEnabled)

        series.setData(data: [
            LineData(time: .utc(timestamp: 1), value: 10),
            LineData(time: .utc(timestamp: 1), value: 11)
        ])

        XCTAssertEqual(bridge.submittedScripts.count, 1)
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(series.jsName).setData("))
    }

    func testSeriesValidationCanBeDisabledForMixedTimeUpdate() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        series.setData(data: [
            LineData(time: .utc(timestamp: 1), value: 10)
        ])
        series.setDataValidationEnabled(false)
        series.update(bar: LineData(time: .string("2019-01-02"), value: 11))

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(series.jsName).setData("))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(series.jsName).update("))
    }

    func testPaneMutationsSubmitInCallOrder() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let pane = Pane(index: 1, chartJSName: chart.jsName, context: bridge, closureStore: nil)

        pane.setHeight(height: 240)
        pane.moveTo(paneIndex: 0)
        pane.setPreserveEmptyPane(preserve: true)

        XCTAssertEqual(bridge.submittedScripts.count, 4)
        let paneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")
        XCTAssertTrue(bridge.submittedScripts[0].contains("var panes = \(chart.jsName).panes();"))
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(paneIdentifier)'] = panes[1];"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("window['\(paneIdentifier)'].setHeight(240.0);"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("window['\(paneIdentifier)'].moveTo(0);"))
        XCTAssertTrue(bridge.submittedScripts[3].contains("window['\(paneIdentifier)'].setPreserveEmptyPane(true);"))
    }

    func testChartMutationFamiliesSubmitInCallOrder() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let series = LineSeries(context: bridge, closureStore: nil)

        chart.applyOptions(options: ChartOptions(width: 320, height: 180))
        chart.resize(width: 640, height: 360, forceRepaint: true)
        let addedPane = chart.addPane()
        chart.removePane(index: 1)
        chart.swapPanes(first: 0, second: 1)
        chart.setCrosshairPosition(price: 101.5, horizontalPosition: .utc(timestamp: 7), seriesApi: series)
        chart.clearCrosshairPosition()

        XCTAssertEqual(bridge.submittedScripts.count, 7)
        XCTAssertTrue(bridge.submittedScripts[0].contains("\"width\":320"))
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(chart.jsName).applyOptions(options);"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(chart.jsName).resize(640.0, 360.0, true);"))
        let addedPaneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[2], prefix: "pane")
        XCTAssertTrue(bridge.submittedScripts[2].contains("window['\(addedPaneIdentifier)'] = \(chart.jsName).addPane();"))
        XCTAssertTrue(bridge.submittedScripts[3].contains("\(chart.jsName).removePane(1);"))
        XCTAssertTrue(bridge.submittedScripts[4].contains("\(chart.jsName).swapPanes(0, 1);"))
        XCTAssertTrue(bridge.submittedScripts[5].contains("\(chart.jsName).setCrosshairPosition(101.5,"))
        XCTAssertTrue(bridge.submittedScripts[5].contains(series.jsName))
        XCTAssertTrue(bridge.submittedScripts[6].contains("\(chart.jsName).clearCrosshairPosition();"))
        XCTAssertTrue((addedPane as! Pane).jsName == addedPaneIdentifier)
    }

    func testSeriesMutationFamiliesSubmitInCallOrder() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        series.applyOptions(options: LineSeriesOptions(title: "ordered", lineWidth: .three))
        series.setMarkers(data: [sampleSeriesMarker()])
        let priceLine = series.createPriceLine(options: PriceLineOptions())
        series.removePriceLine(line: priceLine)
        series.setSeriesOrder(order: 2)

        XCTAssertEqual(bridge.submittedScripts.count, 5)
        XCTAssertTrue(bridge.submittedScripts[0].contains("\"title\":\"ordered\""))
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(series.jsName).applyOptions(options);"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(series.jsName)._lwcMarkersPlugin"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("window['\(priceLine.jsName)'] = \(series.jsName).createPriceLine("))
        XCTAssertTrue(bridge.submittedScripts[3].contains("\(series.jsName).removePriceLine(\(priceLine.jsName));"))
        XCTAssertTrue(bridge.submittedScripts[4].contains("\(series.jsName).setSeriesOrder(2);"))
    }

    func testScaleMutationFamiliesSubmitInCallOrder() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let timeScale = chart.timeScale()
        let priceScale = chart.priceScale(priceScaleId: "right")

        timeScale.scrollToPosition(position: 12, animated: false)
        timeScale.setVisibleLogicalRange(range: FromToRange(from: 3, to: 9))
        timeScale.applyOptions(options: TimeScaleOptions(visible: true))
        priceScale.applyOptions(options: PriceScaleOptions(visible: true))
        priceScale.setVisibleRange(from: 10, to: 20)
        priceScale.setAutoScale(on: true)

        XCTAssertEqual(bridge.submittedScripts.count, 8)
        let timeScaleIdentifier = try! tryUnwrapVarAssignedIdentifier(in: bridge.submittedScripts[0], prefix: "timeScale")
        let priceScaleIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[1], prefix: "priceScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(chart.jsName).timeScale();"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(chart.jsName).priceScale(\"right\");"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("\(timeScaleIdentifier).scrollToPosition(12.0, false);"))
        XCTAssertTrue(bridge.submittedScripts[3].contains("\(timeScaleIdentifier).setVisibleLogicalRange("))
        XCTAssertTrue(bridge.submittedScripts[3].contains("\"from\":3"))
        XCTAssertTrue(bridge.submittedScripts[3].contains("\"to\":9"))
        XCTAssertTrue(bridge.submittedScripts[4].contains("\(timeScaleIdentifier).applyOptions(options);"))
        XCTAssertTrue(bridge.submittedScripts[5].contains("\(priceScaleIdentifier).applyOptions("))
        XCTAssertTrue(bridge.submittedScripts[6].contains("\(priceScaleIdentifier).setVisibleRange("))
        XCTAssertTrue(bridge.submittedScripts[7].contains("\(priceScaleIdentifier).setAutoScale(true);"))
    }

    func testSeriesPriceFormatterIsUsableImmediatelyAfterFactoryReturns() async throws {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let formatter = series.priceFormatter()
        bridge.evaluateHandler = { script, _ in
            if script.contains(".format(") {
                return "42.00"
            }
            throw JavaScriptBridgeError.contextUnavailable
        }

        let formatted = try await formatter.format(price: 42)

        XCTAssertEqual(formatted, "42.00")
        XCTAssertEqual(bridge.submittedScripts.count, 1)
        let identifier = try tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "priceFormatter")
        XCTAssertTrue(bridge.submittedScripts[0].contains(".priceFormatter();"))
        XCTAssertEqual(bridge.evaluatedScripts, ["\(identifier).format(42.0);"])
    }

    func testSeriesPriceScaleIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let priceScale = series.priceScale()

        priceScale.setAutoScale(on: true)

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        let identifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "priceScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(identifier)'] = \(series.jsName).priceScale();"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(identifier).setAutoScale(true);"))
    }

    func testCreatePriceLineIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let priceLine = series.createPriceLine(options: PriceLineOptions())

        priceLine.applyOptions(options: PriceLineOptions())

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(priceLine.jsName)'] = \(series.jsName).createPriceLine("))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(priceLine.jsName).applyOptions("))
    }

    func testChartPriceScaleIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let priceScale = chart.priceScale(priceScaleId: "right")

        priceScale.setAutoScale(on: false)

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        let identifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "priceScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(chart.jsName).priceScale(\"right\");"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(identifier).setAutoScale(false);"))
    }

    func testChartTimeScaleIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let timeScale = chart.timeScale()

        timeScale.fitContent()

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        let identifier = try! tryUnwrapVarAssignedIdentifier(in: bridge.submittedScripts[0], prefix: "timeScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("\(chart.jsName).timeScale();"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(identifier).fitContent();"))
    }

    func testPanePriceScaleIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let pane = Pane(index: 2, chartJSName: chart.jsName, context: bridge, closureStore: nil)
        let priceScale = pane.priceScale(priceScaleId: "left")

        priceScale.setVisibleRange(from: 10, to: 20)

        XCTAssertEqual(bridge.submittedScripts.count, 3)
        let paneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")
        let identifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[1], prefix: "priceScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("var panes = \(chart.jsName).panes();"))
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(paneIdentifier)'] = panes[2];"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("window['\(identifier)'] = window['\(paneIdentifier)'].priceScale(\"left\");"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("\(identifier).setVisibleRange("))
        XCTAssertTrue(bridge.submittedScripts[2].contains("\"from\":10"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("\"to\":20"))
    }

    func testChartAddLineSeriesIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let series = chart.addLineSeries(options: nil)

        series.setData(data: [LineData(time: .utc(timestamp: 1), value: 5)])

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("var \(series.jsName) = \(chart.jsName).addSeries(LightweightCharts.LineSeries"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(series.jsName).setData("))
    }

    func testSeriesMarkersPluginIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let plugin = series.createMarkersPlugin(
            data: [sampleSeriesMarker()],
            options: SeriesMarkersOptions(active: true)
        )

        plugin.applyOptions(options: SeriesMarkersOptions(active: false))

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(plugin.jsName)'] = LightweightCharts.createSeriesMarkers(\(series.jsName)"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(plugin.jsName).applyOptions("))
    }

    func testUpDownMarkersPluginIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let plugin = series.createUpDownMarkersPlugin(options: UpDownMarkersOptions())

        plugin.clearMarkers()

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(plugin.jsName)'] = LightweightCharts.createUpDownMarkers(\(series.jsName)"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("\(plugin.jsName).clearMarkers();"))
    }

    func testSeriesMarkersPluginReadsViaCallbackBridge() {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let plugin = series.createMarkersPlugin(data: [sampleSeriesMarker()])
        let expectation = expectation(description: "markers returned")

        bridge.decodedResultHandler = { script, _ in
            XCTAssertEqual(script, "\(plugin.jsName).markers();")
            return [self.sampleSeriesMarker()]
        }

        plugin.getMarkers { markers in
            XCTAssertEqual(markers?.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(bridge.callbackEvaluatedScripts, ["\(plugin.jsName).markers();"])
        XCTAssertTrue(bridge.evaluatedScripts.isEmpty)
    }

    func testPanePluginReadsViaCallbackBridge() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let plugin = TestPaneReadPlugin(chart: chart, paneIndex: 0, context: bridge)
        let expectation = expectation(description: "pane read returned")

        bridge.decodedResultHandler = { script, _ in
            XCTAssertEqual(script, "1 + 1")
            return 2
        }

        plugin.readValue { value in
            XCTAssertEqual(value, 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(bridge.callbackEvaluatedScripts, ["1 + 1"])
        XCTAssertTrue(bridge.evaluatedScripts.isEmpty)
    }

    func testTextWatermarkPluginIsUsableImmediatelyAfterFactoryReturns() throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let plugin = chart.createTextWatermarkPlugin(
            paneIndex: 0,
            options: TextWatermarkOptions(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                text: "Ready",
                color: ChartColor(.red)
            )
        )

        plugin.setVisible(false)

        XCTAssertEqual(bridge.submittedScripts.count, 3)
        let paneIdentifier = try tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")
        let identifier = try tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[1], prefix: "textWatermark")
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(paneIdentifier)'] = panes[0];"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("LightweightCharts.createTextWatermark(pane,"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("window['\(identifier)'].applyOptions("))
    }

    func testImageWatermarkPluginIsUsableImmediatelyAfterFactoryReturns() throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let plugin = chart.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/logo.png",
            options: ImageWatermarkOptions()
        )

        plugin.setAlpha(0.4)

        XCTAssertEqual(bridge.submittedScripts.count, 3)
        let paneIdentifier = try tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")
        let identifier = try tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[1], prefix: "imageWatermark")
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(paneIdentifier)'] = panes[0];"))
        XCTAssertTrue(bridge.submittedScripts[1].contains("LightweightCharts.createImageWatermark(pane,"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("window['\(identifier)'].applyOptions("))
    }

    func testTextWatermarkHandleIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let watermark = chart.createTextWatermark(
            paneIndex: 0,
            options: TextWatermarkOptions(
                horizontalAlignment: .center,
                verticalAlignment: .center,
                text: "Handle",
                color: ChartColor(.green)
            )
        )

        watermark.detach()

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(watermark.jsName)'] = LightweightCharts.createTextWatermark("))
        XCTAssertTrue(bridge.submittedScripts[1].contains("window['\(watermark.jsName)'].detach();"))
    }

    func testImageWatermarkHandleIsUsableImmediatelyAfterFactoryReturns() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let watermark = chart.createImageWatermark(
            paneIndex: 0,
            imageUrl: "https://example.com/handle.png",
            options: ImageWatermarkOptions()
        )

        watermark.applyOptions(ImageWatermarkUpdateOptions(alpha: 0.5))

        XCTAssertEqual(bridge.submittedScripts.count, 2)
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(watermark.jsName)'] = LightweightCharts.createImageWatermark("))
        XCTAssertTrue(bridge.submittedScripts[1].contains("window['\(watermark.jsName)'].applyOptions("))
    }

    func testWebViewEvaluatorDecodesPrimitiveResult() async throws {
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())

        let value = try await webView.evaluate(script: "40 + 2", resultType: Int.self)

        XCTAssertEqual(value, 42)
    }

    func testWebViewEvaluatorDecodesObjectResult() async throws {
        struct SampleObject: Decodable, Equatable {
            let value: Int
            let label: String
        }

        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())

        let value = try await webView.evaluate(script: "({ value: 7, label: 'ok' })", resultType: SampleObject.self)

        XCTAssertEqual(value, SampleObject(value: 7, label: "ok"))
    }

    func testWebViewEvaluatorPropagatesJavaScriptFailure() async {
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())

        do {
            let _: Int = try await webView.evaluate(script: "(() => { throw new Error('boom'); })()", resultType: Int.self)
            XCTFail("Expected JavaScript evaluation to throw")
        } catch let .evaluationFailed(script, message) {
            XCTAssertEqual(script, "var scriptResult = (() => { throw new Error('boom'); })(); JSON.stringify(scriptResult);")
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Expected JavaScriptBridgeError.evaluationFailed, got \(error)")
        }
    }

    func testWebViewEvaluatorPropagatesDecodingFailure() async {
        let webView = WebView(frame: .zero, configuration: WKWebViewConfiguration())

        do {
            let _: Int = try await webView.evaluate(script: "({ value: 7 })", resultType: Int.self)
            XCTFail("Expected decoding failure")
        } catch .decodingFailed {
        } catch {
            XCTFail("Expected JavaScriptBridgeError.decodingFailed, got \(error)")
        }
    }

    func testSeriesMarkersPluginSupportsAsyncReads() async throws {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let plugin = series.createMarkersPlugin(data: [sampleSeriesMarker()])

        bridge.decodedResultHandler = { script, _ in
            XCTAssertEqual(script, "\(plugin.jsName).markers();")
            return [self.sampleSeriesMarker()]
        }

        let markers = try await plugin.markers()

        XCTAssertEqual(markers.count, 1)
    }

    func testTextWatermarkPluginSupportsAsyncVisibilityRead() async throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let plugin = chart.createTextWatermarkPlugin(
            paneIndex: 0,
            options: TextWatermarkOptions(
                visible: false,
                horizontalAlignment: .center,
                verticalAlignment: .center,
                text: "Ready",
                color: ChartColor(.red)
            )
        )

        let isVisible = try await plugin.visible()

        XCTAssertFalse(isVisible)
    }

    func testSeriesSupportsAsyncSeriesOrderRead() async throws {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        bridge.evaluateHandler = { script, _ in
            XCTAssertEqual(script, "\(series.jsName).seriesOrder();")
            return 3
        }

        let order = try await series.seriesOrder()

        XCTAssertEqual(order, 3)
    }

    func testSeriesSupportsAsyncPopRead() async throws {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        bridge.decodedResultHandler = { script, _ in
            XCTAssertEqual(script, "\(series.jsName).pop(2);")
            return [
                LineData(time: .utc(timestamp: 10), value: 101),
                LineData(time: .utc(timestamp: 11), value: 102)
            ]
        }

        let removedBars = try await series.pop(count: 2)

        XCTAssertEqual(removedBars.count, 2)
        XCTAssertEqual(removedBars[0].value, 101)
        XCTAssertEqual(removedBars[1].value, 102)
    }

    func testSeriesSupportsAsyncLastValueDataRead() async throws {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        bridge.decodedResultHandler = { script, _ in
            XCTAssertEqual(script, "\(series.jsName).lastValueData(true);")
            return LastValueDataResult(noData: false, price: 42.5, color: "#0b6e4f")
        }

        let lastValue = try await series.lastValueData(globalLast: true)

        XCTAssertFalse(lastValue.noData)
        XCTAssertEqual(lastValue.price, 42.5)
        XCTAssertEqual(lastValue.color, "#0b6e4f")
    }

    func testPriceScaleSupportsAsyncVisibleRangeRead() async throws {
        let bridge = MockBridge()
        let priceScale = PriceScale(context: bridge)

        bridge.decodedResultHandler = { script, _ in
            XCTAssertEqual(script, "\(priceScale.jsName).getVisibleRange();")
            return FromToRange(from: 10.5, to: 20.25)
        }

        let visibleRange = try await priceScale.getVisibleRange()

        XCTAssertEqual(visibleRange?.from, 10.5)
        XCTAssertEqual(visibleRange?.to, 20.25)
    }

    func testPaneSupportsAsyncReads() async throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let pane = Pane(index: 1, chartJSName: chart.jsName, context: bridge, closureStore: nil)
        let paneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")

        bridge.decodedResultHandler = { script, _ in
            switch script {
            case let script where script.contains("return \(chart.jsName).paneSize(paneIndex);"):
                XCTAssertTrue(script.contains("pane === window['\(paneIdentifier)']"))
                return Rectangle(width: 320, height: 180)
            default:
                throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected decoded script")
            }
        }
        bridge.evaluateHandler = { script, resultType in
            switch script {
            case "window['\(paneIdentifier)'].getHeight();":
                return 180.0
            case "window['\(paneIdentifier)'].preserveEmptyPane();":
                return true
            case "window['\(paneIdentifier)'].getStretchFactor();":
                return 2.0
            default:
                throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected evaluate script for \(resultType)")
            }
        }

        let size = try await pane.size()
        let height = try await pane.getHeight()
        let preservesEmptyPane = try await pane.preserveEmptyPane()
        let stretchFactor = try await pane.getStretchFactor()

        XCTAssertEqual(size.width, 320)
        XCTAssertEqual(size.height, 180)
        XCTAssertEqual(height, 180)
        XCTAssertTrue(preservesEmptyPane)
        XCTAssertEqual(stretchFactor, 2)
    }

    func testPaneCurrentIndexTracksLivePositionWhileIndexRemainsSnapshot() async throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let pane = Pane(index: 1, chartJSName: chart.jsName, context: bridge, closureStore: nil)
        let paneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")

        bridge.evaluateHandler = { script, _ in
            XCTAssertTrue(script.contains("pane === window['\(paneIdentifier)']"))
            return 0
        }

        let currentIndex = try await pane.currentIndex()

        XCTAssertEqual(pane.index, 1)
        XCTAssertEqual(currentIndex, 0)
    }

    func testPanePluginUsesStablePaneHandleForRecreationAndCurrentIndex() async throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let plugin = chart.createImageWatermarkPlugin(
            paneIndex: 0,
            imageUrl: "https://example.com/logo.png",
            options: ImageWatermarkOptions()
        )
        let paneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")

        plugin.updateImage(url: "https://example.com/updated.png")

        XCTAssertEqual(plugin.paneIndex, 0)
        XCTAssertTrue(bridge.submittedScripts[1].contains("var pane = window['\(paneIdentifier)'];"))
        XCTAssertTrue(bridge.submittedScripts[3].contains("var pane = window['\(paneIdentifier)'];"))
        XCTAssertFalse(bridge.submittedScripts[3].contains(".panes()[0]"))

        bridge.evaluateHandler = { script, _ in
            XCTAssertTrue(script.contains("pane === window['\(paneIdentifier)']"))
            return 1
        }

        let currentPaneIndex = try await plugin.currentPaneIndex()

        XCTAssertEqual(currentPaneIndex, 1)
    }

    func testRemoveDuringBootstrapCancelsReadinessAndAsyncWaiters() async {
        let delegate = LightweightChartsDelegateSpy()
        let charts = LightweightCharts(
            options: ChartOptions(),
            loadDelegate: delegate,
            bootstrapMode: .deferred
        )
        var whenReadyCalled = false
        var loadErrorCalled = false

        charts.whenReady { _ in
            whenReadyCalled = true
        }
        charts.onLoadError { _, _ in
            loadErrorCalled = true
        }

        let optionsTask = Task {
            try await charts.options()
        }
        await Task.yield()

        charts.remove()

        do {
            _ = try await optionsTask.value
            XCTFail("Expected remove() during bootstrap to cancel pending async reads")
        } catch let error as JavaScriptBridgeError {
            switch error {
            case .cancelled:
                break
            default:
                XCTFail("Expected cancellation, got \(error)")
            }
        } catch {
            XCTFail("Expected JavaScriptBridgeError.cancelled, got \(error)")
        }

        XCTAssertFalse(charts.isReady)
        XCTAssertFalse(whenReadyCalled)
        XCTAssertFalse(loadErrorCalled)
        XCTAssertFalse(delegate.didLoad)
        XCTAssertNil(delegate.loadError)
    }

    func testRemoveAfterChartCreationUsesDirectCleanupAndSuppressesLoadCallbacks() async {
        let delegate = LightweightChartsDelegateSpy()
        let charts = LightweightCharts(
            options: ChartOptions(),
            loadDelegate: delegate,
            bootstrapMode: .deferred
        )
        var whenReadyCalled = false
        var loadErrorCalled = false
        var bootstrapScripts: [String] = []
        var rawScripts: [String] = []
        let createChartHookReached = expectation(description: "chart creation hook reached")

        charts.whenReady { _ in
            whenReadyCalled = true
        }
        charts.onLoadError { _, _ in
            loadErrorCalled = true
        }
        charts.bootstrapScriptEvaluatorOverride = { script in
            bootstrapScripts.append(script)
            return nil
        }
        charts.rawScriptSubmitterOverride = { script in
            rawScripts.append(script)
        }
        charts.afterCreateChartScriptHook = {
            createChartHookReached.fulfill()
            charts.remove()
        }

        let optionsTask = Task {
            try await charts.options()
        }

        charts.startBootstrapIfNeeded()
        await fulfillment(of: [createChartHookReached], timeout: 1.0)

        do {
            _ = try await optionsTask.value
            XCTFail("Expected remove() during bootstrap to cancel pending async reads")
        } catch let error as JavaScriptBridgeError {
            switch error {
            case .cancelled:
                break
            default:
                XCTFail("Expected cancellation, got \(error)")
            }
        } catch {
            XCTFail("Expected JavaScriptBridgeError.cancelled, got \(error)")
        }

        XCTAssertEqual(bootstrapScripts.count, 4)
        XCTAssertEqual(rawScripts.count, 1)
        XCTAssertTrue(rawScripts[0].contains("typeof"))
        XCTAssertTrue(rawScripts[0].contains(".remove()"))
        XCTAssertFalse(charts.isReady)
        XCTAssertFalse(whenReadyCalled)
        XCTAssertFalse(loadErrorCalled)
        XCTAssertFalse(delegate.didLoad)
        XCTAssertNil(delegate.loadError)
    }

    func testReadyChartTransitionsToRemovedTerminalState() async {
        let delegate = LightweightChartsDelegateSpy()
        let charts = LightweightCharts(
            options: ChartOptions(),
            loadDelegate: delegate,
            bootstrapMode: .deferred
        )
        var whenReadyCount = 0
        var loadErrorCalled = false
        let didLoadExpectation = expectation(description: "chart loaded")

        charts.whenReady { _ in
            whenReadyCount += 1
            didLoadExpectation.fulfill()
        }
        charts.onLoadError { _, _ in
            loadErrorCalled = true
        }
        charts.bootstrapScriptEvaluatorOverride = { _ in
            return nil
        }

        charts.startBootstrapIfNeeded()
        await fulfillment(of: [didLoadExpectation], timeout: 1.0)

        XCTAssertTrue(charts.isReady)
        XCTAssertTrue(delegate.didLoad)
        XCTAssertNil(delegate.loadError)

        charts.remove()

        XCTAssertFalse(charts.isReady)
        XCTAssertFalse(loadErrorCalled)

        let whenReadyCountAfterRemoval = whenReadyCount
        charts.whenReady { _ in
            whenReadyCount += 1
        }
        charts.remove()

        XCTAssertEqual(whenReadyCount, whenReadyCountAfterRemoval)
    }

    func testSeriesMarkersReturnsEmptyArrayWithoutPlugin() async throws {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)

        bridge.decodedResultHandler = { script, _ in
            XCTAssertTrue(script.contains("\(series.jsName)._lwcMarkersPlugin"))
            return Optional<[SeriesMarker]>.none as Any
        }

        let markers = try await series.markers()

        XCTAssertTrue(markers.isEmpty)
    }

    func testTimeScaleAsyncReadsSupportNullResults() async throws {
        let bridge = MockBridge()
        let timeScale = TimeScale(context: bridge, closureStore: nil)

        bridge.decodedResultHandler = { script, _ in
            switch script {
            case "\(timeScale.jsName).getVisibleRange();":
                return Optional<TimeRange>.none as Any
            case "\(timeScale.jsName).getVisibleLogicalRange();":
                return Optional<LogicalRange>.none as Any
            case "\(timeScale.jsName).coordinateToTime(42.0);":
                return Optional<Time>.none as Any
            default:
                throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected decoded script")
            }
        }
        bridge.evaluateHandler = { script, _ in
            switch script {
            case "\(timeScale.jsName).logicalToCoordinate(5.0);":
                return Optional<Coordinate>.none as Any
            case "\(timeScale.jsName).coordinateToLogical(42.0);":
                return Optional<Logical>.none as Any
            case "\(timeScale.jsName).timeToCoordinate(\"2024-01-01\");":
                return Optional<Coordinate>.none as Any
            default:
                throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected evaluate script")
            }
        }

        let visibleRange = try await timeScale.getVisibleRange()
        let visibleLogicalRange = try await timeScale.getVisibleLogicalRange()
        let logicalCoordinate = try await timeScale.logicalToCoordinate(logical: 5)
        let logical = try await timeScale.coordinateToLogical(x: 42)
        let timeCoordinate = try await timeScale.timeToCoordinate(time: .string("2024-01-01"))
        let time = try await timeScale.coordinateToTime(x: 42)

        XCTAssertNil(visibleRange)
        XCTAssertNil(visibleLogicalRange)
        XCTAssertNil(logicalCoordinate)
        XCTAssertNil(logical)
        XCTAssertNil(timeCoordinate)
        XCTAssertNil(time)
    }

    func testChartAddPaneSupportsPreserveFlagAndReturnsPaneHandle() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)

        let pane = chart.addPane(preserveEmptyPane: true)

        XCTAssertEqual(bridge.submittedScripts.count, 1)
        let paneIdentifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "pane")
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(paneIdentifier)'] = \(chart.jsName).addPane(true);"))
        XCTAssertEqual((pane as! Pane).jsName, paneIdentifier)
    }

    func testChartPriceScaleSupportsPaneIndex() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)

        _ = chart.priceScale(priceScaleId: "left", paneIndex: 2)

        XCTAssertEqual(bridge.submittedScripts.count, 1)
        let identifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "priceScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(identifier)'] = \(chart.jsName).priceScale(\"left\", 2);"))
    }

    func testChartPriceScaleNilDefaultsToRightScale() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)

        _ = chart.priceScale(priceScaleId: nil)

        XCTAssertEqual(bridge.submittedScripts.count, 1)
        let identifier = try! tryUnwrapCreatedIdentifier(in: bridge.submittedScripts[0], prefix: "priceScale")
        XCTAssertTrue(bridge.submittedScripts[0].contains("window['\(identifier)'] = \(chart.jsName).priceScale(\"right\");"))
    }

    func testTimeScaleSupportsAsyncIndexAndSizeReads() async throws {
        let bridge = MockBridge()
        let timeScale = TimeScale(context: bridge, closureStore: nil)

        bridge.evaluateHandler = { script, _ in
            switch script {
            case "\(timeScale.jsName).timeToIndex(\"2024-01-01\", true);":
                return Optional<Int>.some(12) as Any
            case "\(timeScale.jsName).width();":
                return 320.0
            case "\(timeScale.jsName).height();":
                return 48.0
            default:
                throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected evaluate script")
            }
        }

        let timeIndex = try await timeScale.timeToIndex(time: .string("2024-01-01"), findNearest: true)
        let width = try await timeScale.width()
        let height = try await timeScale.height()

        XCTAssertEqual(timeIndex, 12)
        XCTAssertEqual(width, 320)
        XCTAssertEqual(height, 48)
    }

    func testSeriesSupportsHistoricalUpdateDataReadMoveToPaneAndGetPane() async throws {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let series = chart.addLineSeries(options: nil)

        series.update(bar: LineData(time: .utc(timestamp: 4), value: 13), historicalUpdate: true)
        series.moveToPane(paneIndex: 2)

        XCTAssertTrue(bridge.submittedScripts[1].contains("\(series.jsName).update("))
        XCTAssertTrue(bridge.submittedScripts[1].contains(", true);"))
        XCTAssertTrue(bridge.submittedScripts[2].contains("\(series.jsName).moveToPane(2);"))

        bridge.decodedResultHandler = { script, _ in
            if script == "\(series.jsName).data();" {
                return [
                    LineData(time: .utc(timestamp: 1), value: 11),
                    LineData(time: .utc(timestamp: 2), value: 12)
                ]
            }
            throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected decoded script")
        }
        bridge.evaluateHandler = { script, _ in
            if script == "\(series.jsName).getPane().paneIndex();" {
                return 1
            }
            throw JavaScriptBridgeError.evaluationFailed(script: script, message: "Unexpected evaluate script")
        }

        let data = try await series.data()
        let pane = try await series.getPane()

        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data[0].value, 11)
        XCTAssertEqual(pane.index, 1)
    }

    func testSeriesDataChangedEventsStreamSubscribesAndYields() async {
        let bridge = MockBridge()
        let series = LineSeries(context: bridge, closureStore: nil)
        let stream = series.dataChangedEvents
        var iterator = stream.makeAsyncIterator()

        XCTAssertEqual(bridge.messageHandlerNames.count, 1)
        XCTAssertTrue(bridge.submittedScripts.contains { $0.contains(".subscribeDataChanged(") })

        series.messageHandler(MessageHandler(), didReceiveDataChangedWithScope: .update)
        let received = await iterator.next()

        XCTAssertEqual(received, .update)
    }

    func testTimeScaleOptionsEncodeMaxBarSpacing() {
        let options = TimeScaleOptions(maxBarSpacing: 48)

        XCTAssertTrue(options.jsonString.contains("\"maxBarSpacing\":48"))
    }

    func testAreaAndBaselineOptionsEncodeRelativeGradient() {
        let areaOptions = AreaSeriesOptions(relativeGradient: true)
        let baselineOptions = BaselineSeriesOptions(relativeGradient: true)

        XCTAssertTrue(areaOptions.jsonString.contains("\"relativeGradient\":true"))
        XCTAssertTrue(baselineOptions.jsonString.contains("\"relativeGradient\":true"))
    }

    func testChartOptionsScriptCreatesLocalizationObjectForFormatterOnlyOptions() {
        let options = ChartOptions(
            localization: LocalizationOptions(
                priceFormatter: .javaScript("function(price) { return '$' + price.toFixed(2); }"),
                tickmarksPriceFormatter: .javaScript("function(prices) { return prices.map(function(price) { return '$' + price.toFixed(0); }); }")
            )
        )

        let script = options.optionsScript(for: nil).options

        XCTAssertTrue(script.contains("options.localization = options.localization ?? {};"))
        XCTAssertTrue(script.contains("options.localization.priceFormatter = function(price)"))
        XCTAssertTrue(script.contains("options.localization.tickmarksPriceFormatter = function(prices)"))
    }

    func testChartOptionsScriptCreatesTimeScaleObjectForFormatterOnlyOptions() {
        let options = ChartOptions(
            timeScale: TimeScaleOptions(
                tickMarkFormatter: .javaScript("function(time, tickMarkType, locale) { return 'x'; }")
            )
        )

        let script = options.optionsScript(for: nil).options

        XCTAssertTrue(script.contains("options.timeScale = options.timeScale ?? {};"))
        XCTAssertTrue(script.contains("options.timeScale.tickMarkFormatter = function(time, tickMarkType, locale)"))
    }

    func testTimeScaleOptionsScriptInjectsTickMarkFormatter() {
        let options = TimeScaleOptions(
            tickMarkFormatter: .javaScript("function(time, tickMarkType, locale) { return locale + ':' + tickMarkType; }")
        )

        let script = options.optionsScript(for: nil).options

        XCTAssertTrue(script.contains("var options ="))
        XCTAssertTrue(script.contains("options.tickMarkFormatter = function(time, tickMarkType, locale)"))
    }

    func testSeriesOptionsScriptInjectsCustomPriceFormatFunctions() {
        let options = LineSeriesOptions(
            priceFormat: .custom(
                CustomPriceFormat(
                    minMove: 0.01,
                    formatterJavaScript: "function(price) { return '$' + price.toFixed(2); }",
                    tickmarksFormatterJavaScript: "function(prices) { return prices.map(function(price) { return '$' + price.toFixed(0); }); }"
                )
            )
        )

        let script = options.optionsScript(for: nil).options

        XCTAssertTrue(script.contains("options.priceFormat = options.priceFormat ?? {};"))
        XCTAssertTrue(script.contains("options.priceFormat.formatter = function(price)"))
        XCTAssertTrue(script.contains("options.priceFormat.tickmarksFormatter = function(prices)"))
    }

    func testMessageHandlerRoutesChartDelegateCallbacksOnMainActor() {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let delegate = ChartDelegateSpy()
        let handler = MessageHandler()
        let payload = """
        {"time":1,"logical":2,"point":{"x":3,"y":4},"hoveredObjectId":5,"hoveredSeries":"line"}
        """

        chart.delegate = delegate
        handler.delegate = chart
        handler.handleMessage(name: "\(Subscription.click.rawValue)_\(chart.jsName)", bodyJSONString: payload)

        XCTAssertTrue(delegate.deliveredOnMainThread)
        XCTAssertEqual(delegate.clickParameters?.logical, 2)
        XCTAssertEqual(delegate.clickParameters?.point?.x, 3)
        XCTAssertEqual(delegate.clickParameters?.time, .utc(timestamp: 1))
    }

    func testChartClickEventsStreamSubscribesAndYieldsWithoutManualSubscribe() async {
        let bridge = MockBridge()
        let chart = Chart(context: bridge, closureStore: nil)
        let stream = chart.clickEvents
        var iterator = stream.makeAsyncIterator()
        let parameters = MouseEventParams(
            time: .utc(timestamp: 1),
            logical: 2,
            point: Point(x: 3, y: 4),
            hoveredObjectId: 5,
            sourceEvent: nil,
            hoveredSeries: "line"
        )

        XCTAssertEqual(bridge.messageHandlerNames.count, 1)
        XCTAssertTrue(bridge.submittedScripts.contains { $0.contains(".subscribeClick(") })

        chart.messageHandler(MessageHandler(), didReceiveClickWithParameters: parameters)
        let received = await iterator.next()

        XCTAssertEqual(received?.logical, 2)
        XCTAssertEqual(received?.point?.x, 3)
    }

    func testMessageHandlerRoutesTimeScaleDelegateCallbacksOnMainActor() {
        let bridge = MockBridge()
        let timeScale = TimeScale(context: bridge, closureStore: nil)
        let delegate = TimeScaleDelegateSpy()
        let handler = MessageHandler()

        timeScale.delegate = delegate
        handler.delegate = timeScale
        handler.handleMessage(
            name: "\(Subscription.visibleTimeRangeChange.rawValue)_\(timeScale.jsName)",
            bodyJSONString: "{\"from\":1,\"to\":2}"
        )

        XCTAssertTrue(delegate.deliveredOnMainThread)
        XCTAssertEqual(delegate.visibleTimeRange?.from, .utc(timestamp: 1))
        XCTAssertEqual(delegate.visibleTimeRange?.to, .utc(timestamp: 2))
    }

    private func sampleSeriesMarker() -> SeriesMarker {
        SeriesMarker(
            time: .utc(timestamp: 1),
            position: .aboveBar,
            shape: .circle,
            color: ChartColor(.blue)
        )
    }

    private func tryUnwrapCreatedIdentifier(in script: String, prefix: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let pattern = "window\\['(\(NSRegularExpression.escapedPattern(for: prefix))[^']*)'\\]"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(script.startIndex..<script.endIndex, in: script)
        let match = regex?.firstMatch(in: script, range: range)
        let identifierRange = match.flatMap { Range($0.range(at: 1), in: script) }
        return try XCTUnwrap(identifierRange.map { String(script[$0]) }, file: file, line: line)
    }

    private func tryUnwrapVarAssignedIdentifier(in script: String, prefix: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let pattern = "var\\s+(\(NSRegularExpression.escapedPattern(for: prefix))\\w+)\\s*="
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(script.startIndex..<script.endIndex, in: script)
        let match = regex?.firstMatch(in: script, range: range)
        let identifierRange = match.flatMap { Range($0.range(at: 1), in: script) }
        return try XCTUnwrap(identifierRange.map { String(script[$0]) }, file: file, line: line)
    }
}
