import Foundation
import WebKit

@MainActor
public protocol ChartDelegate: AnyObject {
    
    func didClick(onChart chart: ChartApi, parameters: MouseEventParams)
    func didDoubleClick(onChart chart: ChartApi, parameters: MouseEventParams)
    func didCrosshairMove(onChart chart: ChartApi, parameters: MouseEventParams)
    
}

// MARK: -
/// Internal implementation of the Chart API.
///
/// This class is the concrete implementation of the chart functionality.
/// Most users should interact with charts through the `LightweightCharts` view
/// or the `ChartApi` protocol.
@MainActor
public class Chart: JavaScriptObject {
    
    enum SubscribeState: CaseIterable {
        case declared
        case active
    }

    /// The context type for chart operations.
    public typealias Context = JavaScriptEvaluator & JavaScriptMessageProducer
    private typealias MouseEventContinuation = AsyncStream<MouseEventParams>.Continuation
    
    public let jsName = "chart" + .uniqueString

    public weak var delegate: ChartDelegate?

    /// The JavaScript evaluator context for this chart.
    internal unowned var _context: Context

    /// The JavaScript evaluator context exposed by the concrete chart type.
    public var context: any JavaScriptEvaluator {
        return _context
    }

    private let messageHandler: MessageHandler
    private weak var closureStore: ClosuresStore?
    private var activeSubscriptions: Dictionary<Subscription,SubscribeState> = [:]
    private var manualSubscriptions: Set<Subscription> = []
    private var clickEventContinuations: [UUID: MouseEventContinuation] = [:]
    private var doubleClickEventContinuations: [UUID: MouseEventContinuation] = [:]
    private var crosshairMoveEventContinuations: [UUID: MouseEventContinuation] = [:]
    private var legacyWatermarkOptions: DeprecatedWatermarkOptions?
    
    init(context: Context, closureStore: ClosuresStore?) {
        self._context = context
        self.closureStore = closureStore
        messageHandler = MessageHandler()
        messageHandler.delegate = self
    }

    private func paneScopedCreationScript(objectName: String, paneIndex: Int, factoryCall: String) -> String {
        """
        (function() {
            var panes = \(jsName).panes();
            if (!panes || !panes[\(paneIndex)]) {
                throw new Error('Invalid pane index: \(paneIndex). Pane does not exist in this chart.');
            }
            window['\(objectName)'] = \(factoryCall);
        })();
        """
    }

    // MARK: - Legacy Watermark Compatibility (task 4.4)

    /// Helper struct to encode v5 text watermark options for legacy compatibility
    private struct LegacyTextWatermarkOptions: Encodable {
        let visible: Bool
        let horzAlign: String
        let vertAlign: String
        let lines: [WatermarkLine]

        struct WatermarkLine: Encodable {
            let text: String
            let color: String
            let fontSize: Int
            let fontFamily: String
            let fontStyle: String
        }
    }

    /// Creates or updates the legacy text watermark from v4 watermark options
    /// This compatibility layer converts v4 watermark options to v5 text watermark primitive
    func applyLegacyWatermark(_ options: DeprecatedWatermarkOptions?) {
        // Store options for later use in applyOptions
        legacyWatermarkOptions = options

        guard let options = options, options.visible ?? true else {
            // If watermark is not visible, remove it
            removeLegacyWatermark()
            return
        }

        // Convert v4 WatermarkOptions to v5 TextWatermarkOptions format
        let color = options.color ?? ChartColor("rgba(171, 71, 188, 0.5)")
        let colorString = color.rawValue
        let text = options.text ?? ""
        let fontSize = options.fontSize ?? 24
        let fontFamily = options.fontFamily ?? "-apple-system"
        let fontStyle = options.fontStyle ?? "normal"
        let horzAlign = options.horizontalAlignment ?? .center
        let vertAlign = options.verticalAlignment ?? .center

        // Build the v5 text watermark options using Encodable helper
        let watermarkOptions = LegacyTextWatermarkOptions(
            visible: true,
            horzAlign: horzAlign.rawValue,
            vertAlign: vertAlign.rawValue,
            lines: [
                LegacyTextWatermarkOptions.WatermarkLine(
                    text: text,
                    color: colorString,
                    fontSize: fontSize,
                    fontFamily: fontFamily,
                    fontStyle: fontStyle
                )
            ]
        )

        // Create or update the legacy watermark
        let script = """
        if (typeof \(jsName)._lwcTextWatermark === 'undefined') {
            var pane = \(jsName).panes()[0];
            if (pane) {
                \(jsName)._lwcTextWatermark = LightweightCharts.createTextWatermark(pane, \(watermarkOptions.jsonString));
            }
        } else {
            \(jsName)._lwcTextWatermark.applyOptions(\(watermarkOptions.jsonString));
        }
        """
        _context.submitScript(script)
    }

    /// Removes the legacy watermark if it exists
    private func removeLegacyWatermark() {
        let script = """
        if (typeof \(jsName)._lwcTextWatermark !== 'undefined') {
            \(jsName)._lwcTextWatermark.detach();
            delete \(jsName)._lwcTextWatermark;
        }
        """
        _context.submitScript(script)
    }

    private func addSeries<T: SeriesApi & SeriesObject>(options: T.Options, paneIndex: Int = 0) -> T {
        let series = T(context: context, closureStore: closureStore)
        series.chartJSName = jsName
        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        var \(series.jsName) = \(jsName).addSeries(LightweightCharts.\(T.name), \(optionsScript.variableName), \(paneIndex));
        seriesArray.push({name: "\(series.jsName)", series: \(series.jsName)});
        """
        _context.submitScript(script)
        return series
    }
    
    private func subsriberScript(forName name: String, subscription: Subscription) -> String {
        switch subscription {
        case .crosshairMove, .click, .dblClick:
            return "var \(name) = subscriberCrosshairMoveAndClickFunction('\(name)');"
        default:
            return "var \(name) = postMessageFunction('\(name)');"
        }
    }
    
    private func subscriberName(for subsription: Subscription) -> String {
        return "\(subsription.rawValue)_\(jsName)"
    }

    private func continuations(for subscription: Subscription) -> [UUID: MouseEventContinuation] {
        switch subscription {
        case .click:
            return clickEventContinuations
        case .dblClick:
            return doubleClickEventContinuations
        case .crosshairMove:
            return crosshairMoveEventContinuations
        default:
            return [:]
        }
    }

    private func setContinuations(_ continuations: [UUID: MouseEventContinuation], for subscription: Subscription) {
        switch subscription {
        case .click:
            clickEventContinuations = continuations
        case .dblClick:
            doubleClickEventContinuations = continuations
        case .crosshairMove:
            crosshairMoveEventContinuations = continuations
        default:
            break
        }
    }

    private func activateSubscriptionIfNeeded(_ subscription: Subscription) {
        guard activeSubscriptions[subscription] != .active else {
            return
        }

        let name = subscriberName(for: subscription)
        var subscriberScript = ""
        if activeSubscriptions[subscription] != .declared {
            subscriberScript = subsriberScript(forName: name, subscription: subscription)
            _context.addMessageHandler(messageHandler, name: name)
        }
        let script = subscriberScript + "\n\(jsName).subscribe\(subscription.jsRepresentation)(\(name));"
        _context.submitScript(script)
        activeSubscriptions[subscription] = .active
    }

    private func deactivateSubscription(_ subscription: Subscription) {
        guard activeSubscriptions[subscription] == .active else {
            return
        }

        let name = subscriberName(for: subscription)
        let script = "\(jsName).unsubscribe\(subscription.jsRepresentation)(\(name));"
        _context.submitScript(script)
        activeSubscriptions[subscription] = .declared
    }

    private func deactivateSubscriptionIfPossible(_ subscription: Subscription) {
        guard !manualSubscriptions.contains(subscription), continuations(for: subscription).isEmpty else {
            return
        }

        deactivateSubscription(subscription)
    }

    private func makeEventStream(for subscription: Subscription) -> AsyncStream<MouseEventParams> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            var currentContinuations = continuations(for: subscription)
            currentContinuations[id] = continuation
            setContinuations(currentContinuations, for: subscription)
            activateSubscriptionIfNeeded(subscription)

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    var remainingContinuations = self.continuations(for: subscription)
                    remainingContinuations.removeValue(forKey: id)
                    self.setContinuations(remainingContinuations, for: subscription)
                    self.deactivateSubscriptionIfPossible(subscription)
                }
            }
        }
    }

    private func finishEventStreams() {
        clickEventContinuations.values.forEach { $0.finish() }
        doubleClickEventContinuations.values.forEach { $0.finish() }
        crosshairMoveEventContinuations.values.forEach { $0.finish() }
        clickEventContinuations.removeAll()
        doubleClickEventContinuations.removeAll()
        crosshairMoveEventContinuations.removeAll()
    }

    private func yield(_ parameters: MouseEventParams, for subscription: Subscription) {
        continuations(for: subscription).values.forEach { $0.yield(parameters) }
    }
    
    private func subscribe(subscription: Subscription) {
        let inserted = manualSubscriptions.insert(subscription).inserted
        if !inserted && activeSubscriptions[subscription] == .active {
            NSLog("LWChart: double subscribe detected \(subscription)")
            return
        }
        activateSubscriptionIfNeeded(subscription)
    }
    
    private func unsubscribe(subsription: Subscription) {
        let removed = manualSubscriptions.remove(subsription) != nil
        if !removed && activeSubscriptions[subsription] != .active {
            NSLog("LWChart: double unsubscribe detected \(subsription)")
            return
        }
        deactivateSubscriptionIfPossible(subsription)
    }
    
    private func unsubscribeAll() {
        manualSubscriptions.removeAll()
        deactivateSubscription(.click)
        deactivateSubscription(.dblClick)
        deactivateSubscription(.crosshairMove)
    }
    
}

// MARK: - ChartApi
extension Chart: ChartApi {

    public var clickEvents: AsyncStream<MouseEventParams> {
        makeEventStream(for: .click)
    }

    public var doubleClickEvents: AsyncStream<MouseEventParams> {
        makeEventStream(for: .dblClick)
    }

    public var crosshairMoveEvents: AsyncStream<MouseEventParams> {
        makeEventStream(for: .crosshairMove)
    }

    public func remove() {
        removeLegacyWatermark()
        finishEventStreams()
        unsubscribeAll()
        let script = "\(jsName).remove();"
        _context.submitScript(script)
    }
    
    public func resize(width: Double, height: Double, forceRepaint: Bool?) {
        var parameters = "\(width), \(height)"
        if let forceRepaint = forceRepaint {
            parameters += ", \(forceRepaint)"
        }
        let script = "\(jsName).resize(\(parameters));"
        _context.submitScript(script)
    }

    // MARK: Series methods
    
public func addAreaSeries(options: AreaSeries.Options?) -> AreaSeries {
        addSeries(options: options ?? AreaSeries.Options())
    }
    
public func addBarSeries(options: BarSeries.Options?) -> BarSeries {
        addSeries(options: options ?? BarSeries.Options())
    }
    
public func addCandlestickSeries(options: CandlestickSeries.Options?) -> CandlestickSeries {
        addSeries(options: options ?? CandlestickSeries.Options())
    }
    
public func addHistogramSeries(options: HistogramSeries.Options?) -> HistogramSeries {
        addSeries(options: options ?? HistogramSeries.Options())
    }
    
public func addLineSeries(options: LineSeries.Options?) -> LineSeries {
        addSeries(options: options ?? LineSeries.Options())
    }
    
public func addBaselineSeries(options: BaselineSeries.Options?) -> BaselineSeries {
        addSeries(options: options ?? BaselineSeries.Options())
    }

    // MARK: - Series methods with pane index (v5 multi-pane support)

    public func addAreaSeries(options: AreaSeries.Options?, paneIndex: Int) -> AreaSeries {
        addSeries(options: options ?? AreaSeries.Options(), paneIndex: paneIndex)
    }

    public func addBarSeries(options: BarSeries.Options?, paneIndex: Int) -> BarSeries {
        addSeries(options: options ?? BarSeries.Options(), paneIndex: paneIndex)
    }

    public func addCandlestickSeries(options: CandlestickSeries.Options?, paneIndex: Int) -> CandlestickSeries {
        addSeries(options: options ?? CandlestickSeries.Options(), paneIndex: paneIndex)
    }

    public func addHistogramSeries(options: HistogramSeries.Options?, paneIndex: Int) -> HistogramSeries {
        addSeries(options: options ?? HistogramSeries.Options(), paneIndex: paneIndex)
    }

    public func addLineSeries(options: LineSeries.Options?, paneIndex: Int) -> LineSeries {
        addSeries(options: options ?? LineSeries.Options(), paneIndex: paneIndex)
    }

    public func addBaselineSeries(options: BaselineSeries.Options?, paneIndex: Int) -> BaselineSeries {
        addSeries(options: options ?? BaselineSeries.Options(), paneIndex: paneIndex)
    }

    // MARK: - Pane management (v5)

    /// Adds a new pane to the chart.
    ///
    /// - Returns: The index of the newly created pane.
    public func addPane(preserveEmptyPane: Bool? = nil) -> PaneApi {
        let pane = Pane(chartJSName: jsName, context: _context, closureStore: closureStore)
        var parameters = ""
        if let preserveEmptyPane {
            parameters = preserveEmptyPane ? "true" : "false"
        }
        let script = "window['\(pane.jsName)'] = \(jsName).addPane(\(parameters));"
        _context.submitScript(script)
        return pane
    }

    public func panes() async throws(JavaScriptBridgeError) -> [PaneApi] {
        let script = "\(jsName).panes().length;"
        let count = try await _context.evaluate(script: script, resultType: Int.self)
        return (0..<count).map { index in
            Pane(index: index, chartJSName: self.jsName, context: self._context, closureStore: self.closureStore)
        }
    }

    public func removePane(index: Int) {
        let script = "\(jsName).removePane(\(index));"
        _context.submitScript(script)
    }

    public func swapPanes(first: Int, second: Int) {
        let script = "\(jsName).swapPanes(\(first), \(second));"
        _context.submitScript(script)
    }
    
public func removeSeries<T: SeriesApi & SeriesObject>(seriesApi: T) {
        // Clean up compatibility markers plugin if it exists (task 3.4)
        // The _lwcMarkersPlugin is stored on the series object by setMarkers
        let script = """
        if (typeof \(seriesApi.jsName)._lwcMarkersPlugin !== 'undefined') {
            \(seriesApi.jsName)._lwcMarkersPlugin.detach();
            delete \(seriesApi.jsName)._lwcMarkersPlugin;
        }
        \(jsName).removeSeries(\(seriesApi.jsName));
        """
        _context.submitScript(script)
    }
    
    // MARK: Subscriptions
    
public func subscribeClick() {
        subscribe(subscription: .click)
    }
    
public func unsubscribeClick() {
        unsubscribe(subsription: .click)
    }

public func subscribeDblClick() {
        subscribe(subscription: .dblClick)
    }

public func unsubscribeDblClick() {
        unsubscribe(subsription: .dblClick)
    }
    
public func subscribeCrosshairMove() {
        subscribe(subscription: .crosshairMove)
    }
    
public func unsubscribeCrosshairMove() {
        unsubscribe(subsription: .crosshairMove)
    }

public func setCrosshairPosition<T: SeriesApi & SeriesObject>(price: Double, horizontalPosition: Time, seriesApi: T) {
        let script = """
        if (typeof \(jsName).setCrosshairPosition === 'function') {
            try {
                \(jsName).setCrosshairPosition(\(price), \(horizontalPosition.jsonString), \(seriesApi.jsName));
            } catch (e) {
                console.warn('LWChart setCrosshairPosition failed:', e);
            }
        }
        """
        _context.submitScript(script)
    }

public func clearCrosshairPosition() {
        let script = "\(jsName).clearCrosshairPosition();"
    _context.submitScript(script)
    }

    public func paneSize(paneIndex: Int) async throws(JavaScriptBridgeError) -> Rectangle {
        let script = "\(jsName).paneSize(\(paneIndex));"
        return try await _context.decodedResult(forScript: script)
    }

    // MARK: Other APIs and options methods
    
    public func priceScale(priceScaleId: String?, paneIndex: Int? = nil) -> PriceScaleApi {
        let priceScale = PriceScale(context: context)
        let priceScaleId = priceScaleId ?? "right"
        let script: String
        if let paneIndex {
            script = "window['\(priceScale.jsName)'] = \(jsName).priceScale(\(priceScaleId.jsonString()), \(paneIndex));"
        } else {
            script = "window['\(priceScale.jsName)'] = \(jsName).priceScale(\(priceScaleId.jsonString()));"
        }
        _context.submitScript(script)
        return priceScale
    }
    
public func timeScale() -> TimeScaleApi {
        let timeScale = TimeScale(context: _context, closureStore: closureStore)
        let script = "var \(timeScale.jsName) = \(jsName).timeScale();"
    _context.submitScript(script)
        return timeScale
    }
    
public func applyOptions(options: ChartOptions) {
        // Extract watermark before generating options script (task 4.4)
        let watermark = options._watermark

        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        \(jsName).applyOptions(\(optionsScript.variableName));
        """
        _context.submitScript(script)

        // Apply legacy watermark compatibility after chart options (task 4.4)
        if options._watermarkWasExplicitlySet {
            if let watermark = watermark {
                applyLegacyWatermark(watermark)
            } else {
                removeLegacyWatermark()
            }
        }
    }

    public func options() async throws(JavaScriptBridgeError) -> ChartOptions {
        let script = "\(jsName).options();"
        return try await _context.decodedResult(forScript: script)
    }

    public func autoSizeActive() async throws(JavaScriptBridgeError) -> Bool {
        let script = "\(jsName).autoSizeActive();"
        return try await _context.evaluate(script: script, resultType: Bool.self)
    }

    public func takeScreenshot(addTopLayer: Bool?, includeCrosshair: Bool?) async throws(JavaScriptBridgeError) -> UIImage {
        let imageFormat = "image/jpeg"
        let screenshotCall: String
        switch (addTopLayer, includeCrosshair) {
        case let (.some(addTopLayer), .some(includeCrosshair)):
            screenshotCall = "\(jsName).takeScreenshot(\(addTopLayer), \(includeCrosshair))"
        case let (.some(addTopLayer), .none):
            screenshotCall = "\(jsName).takeScreenshot(\(addTopLayer))"
        case let (.none, .some(includeCrosshair)):
            screenshotCall = "\(jsName).takeScreenshot(undefined, \(includeCrosshair))"
        case (.none, .none):
            screenshotCall = "\(jsName).takeScreenshot()"
        }
        let script = "\(screenshotCall).toDataURL('\(imageFormat)', 1.0);"
        let decodedString = try await _context.evaluate(script: script, resultType: String.self)
        let dataString = decodedString.isEmpty ? nil : decodedString
        do {
            return try await withCheckedThrowingContinuation { continuation in
            // Only the base64-to-UIImage conversion is offloaded; WebKit evaluation
            // stays on the main actor so the JS bridge ordering and executor contract remain intact.
                DispatchQueue.global().async {
                var image: UIImage?
                if let dataString = dataString {
                    let prefix = "data:\(imageFormat);base64,"
                    let base64String: String?
                    if let range = dataString.range(of: prefix) {
                        base64String = String(dataString[range.upperBound...])
                    } else {
                        base64String = nil
                    }
                    if let base64String = base64String,
                       let data = Data(base64Encoded: base64String) {
                        image = UIImage(data: data)
                    }
                }
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: JavaScriptBridgeError.invalidResult(expected: "non-empty image data URL", actual: dataString ?? "nil"))
                }
            }
            }
        } catch {
            throw JavaScriptBridgeError.wrap(error, script: "\(jsName).takeScreenshot")
        }
    }

    // MARK: - Watermark plugin methods

public func createTextWatermark(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermark {
        let watermark = TextWatermark(context: context, jsName: "textWatermark" + .uniqueString)
        let script = paneScopedCreationScript(
            objectName: watermark.jsName,
            paneIndex: paneIndex,
            factoryCall: "LightweightCharts.createTextWatermark(panes[\(paneIndex)], \(options.jsonString()))"
        )
        _context.submitScript(script)
        return watermark
    }

public func createImageWatermark(paneIndex: Int, imageUrl: String, options: ImageWatermarkOptions) -> ImageWatermark {
        let watermark = ImageWatermark(context: context, jsName: "imageWatermark" + .uniqueString)
        let script = paneScopedCreationScript(
            objectName: watermark.jsName,
            paneIndex: paneIndex,
            factoryCall: "LightweightCharts.createImageWatermark(panes[\(paneIndex)], \(imageUrl.jsonString()), \(options.jsonString()))"
        )
        _context.submitScript(script)
        return watermark
    }

    // MARK: - Plugin Factories

    /// Creates a text watermark plugin on the specified pane.
    ///
    /// Immediate follow-up plugin calls are safe because creation and later mutations are
    /// submitted to the same main-actor bridge in call order.
    ///
    /// - Parameters:
    ///   - paneIndex: The index of the pane to attach the plugin to (0 is the main pane).
    ///   - options: Initial options for the text watermark.
    /// - Returns: A new text watermark plugin instance.
    public func createTextWatermarkPlugin(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermarkPlugin<Chart> {
        return TextWatermarkPlugin(chart: self, paneIndex: paneIndex, context: _context, options: options)
    }

    /// Creates an image watermark plugin on the specified pane.
    ///
    /// Immediate follow-up plugin calls are safe because creation and later mutations are
    /// submitted to the same main-actor bridge in call order.
    ///
    /// - Parameters:
    ///   - paneIndex: The index of the pane to attach the plugin to (0 is the main pane).
    ///   - imageUrl: The URL of the image to use as a watermark.
    ///   - options: Initial options for the image watermark.
    /// - Returns: A new image watermark plugin instance.
    public func createImageWatermarkPlugin(
        paneIndex: Int,
        imageUrl: String,
        options: ImageWatermarkOptions = ImageWatermarkOptions()
    ) -> ImageWatermarkPlugin<Chart> {
        return ImageWatermarkPlugin(chart: self, paneIndex: paneIndex, imageUrl: imageUrl, context: _context, options: options)
    }

}

// MARK: - MessageHandlerDelegate
extension Chart: MessageHandlerDelegate {
    
    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveClickWithParameters parameters: MouseEventParams) {
        delegate?.didClick(onChart: self, parameters: parameters)
        yield(parameters, for: .click)
    }

    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveDblClickWithParameters parameters: MouseEventParams) {
        delegate?.didDoubleClick(onChart: self, parameters: parameters)
        yield(parameters, for: .dblClick)
    }
    
    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveCrosshairMoveWithParameters parameters: MouseEventParams) {
        delegate?.didCrosshairMove(onChart: self, parameters: parameters)
        yield(parameters, for: .crosshairMove)
    }

    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveDataChangedWithScope scope: DataChangedScope) {
    }
    
    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveVisibleTimeRangeChangeWithParameters parameters: TimeRange?) {
    }
    
    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveVisibleLogicalRangeChangeWithParameters parameters: LogicalRange?) {
    }
    
    
    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveTimeScaleSizeChangeWithParameters parameters: Rectangle?) {
    }
}

public extension ChartDelegate {

    func didDoubleClick(onChart chart: ChartApi, parameters: MouseEventParams) {
    }

}

@MainActor
final class Pane: PaneApi {

    /// Initial pane index hint for this handle.
    ///
    /// Use `currentIndex()` for authoritative index reads.
    let index: Int

    private let chartJSName: String
    let jsName: String
    private unowned let context: JavaScriptEvaluator
    private weak var closureStore: ClosuresStore?

    init(index: Int, chartJSName: String, context: JavaScriptEvaluator, closureStore: ClosuresStore?) {
        self.index = index
        self.chartJSName = chartJSName
        self.jsName = "pane" + .uniqueString
        self.context = context
        self.closureStore = closureStore

        let script = """
        (function() {
            var panes = \(chartJSName).panes();
            if (!panes || !panes[\(index)]) {
                throw new Error('Invalid pane index: \(index). Pane does not exist in this chart.');
            }
            window['\(jsName)'] = panes[\(index)];
        })();
        """
        context.submitScript(script)
    }

    init(chartJSName: String, context: JavaScriptEvaluator, closureStore: ClosuresStore?) {
        self.index = 0
        self.chartJSName = chartJSName
        self.jsName = "pane" + .uniqueString
        self.context = context
        self.closureStore = closureStore
    }

    private func paneExpression() -> String {
        "window['\(jsName)']"
    }

    private func paneIndexLookupExpression() -> String {
        """
        (function() {
            var panes = \(chartJSName).panes();
            return panes.findIndex(function(pane) { return pane === \(paneExpression()); });
        })()
        """
    }

    private func addSeries<T: SeriesApi & SeriesObject>(options: T.Options) -> T {
        let series = T(context: context, closureStore: closureStore)
        series.chartJSName = chartJSName
        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        window['\(series.jsName)'] = \(paneExpression()).addSeries(LightweightCharts.\(T.name), \(optionsScript.variableName));
        seriesArray.push({name: "\(series.jsName)", series: window['\(series.jsName)']});
        """
        context.submitScript(script)
        return series
    }

    // MARK: - Async methods (Swift 6)

    func size() async throws(JavaScriptBridgeError) -> Rectangle {
        let script = """
        (function() {
            var paneIndex = \(paneIndexLookupExpression());
            if (paneIndex === -1) {
                throw new Error('Pane is no longer attached to this chart.');
            }
            return \(chartJSName).paneSize(paneIndex);
        })();
        """
        return try await context.decodedResult(forScript: script)
    }

    func getHeight() async throws(JavaScriptBridgeError) -> Double {
        let script = "\(paneExpression()).getHeight();"
        return try await context.evaluate(script: script, resultType: Double.self)
    }

    func preserveEmptyPane() async throws(JavaScriptBridgeError) -> Bool {
        let script = "\(paneExpression()).preserveEmptyPane();"
        return try await context.evaluate(script: script, resultType: Bool.self)
    }

    func getStretchFactor() async throws(JavaScriptBridgeError) -> Double {
        let script = "\(paneExpression()).getStretchFactor();"
        return try await context.evaluate(script: script, resultType: Double.self)
    }

    func currentIndex() async throws(JavaScriptBridgeError) -> Int {
        let paneIndex = try await context.evaluate(script: paneIndexLookupExpression(), resultType: Int.self)
        if paneIndex == -1 {
            throw JavaScriptBridgeError.evaluationFailed(
                script: paneIndexLookupExpression(),
                message: "Pane is no longer attached to this chart."
            )
        }
        return paneIndex
    }

    func paneIndex() async throws(JavaScriptBridgeError) -> Int {
        try await currentIndex()
    }

    // MARK: - Synchronous methods

    func setHeight(height: Double) {
        let script = "\(paneExpression()).setHeight(\(height));"
        context.submitScript(script)
    }

    func moveTo(paneIndex: Int) {
        let script = "\(paneExpression()).moveTo(\(paneIndex));"
        context.submitScript(script)
    }

    func setPreserveEmptyPane(preserve: Bool) {
        let script = "\(paneExpression()).setPreserveEmptyPane(\(preserve ? "true" : "false"));"
        context.submitScript(script)
    }

    func setStretchFactor(stretchFactor: Double) {
        let script = "\(paneExpression()).setStretchFactor(\(stretchFactor));"
        context.submitScript(script)
    }

    func addAreaSeries(options: AreaSeries.Options?) -> AreaSeries {
        addSeries(options: options ?? AreaSeries.Options())
    }

    func addBarSeries(options: BarSeries.Options?) -> BarSeries {
        addSeries(options: options ?? BarSeries.Options())
    }

    func addCandlestickSeries(options: CandlestickSeries.Options?) -> CandlestickSeries {
        addSeries(options: options ?? CandlestickSeries.Options())
    }

    func addHistogramSeries(options: HistogramSeries.Options?) -> HistogramSeries {
        addSeries(options: options ?? HistogramSeries.Options())
    }

    func addLineSeries(options: LineSeries.Options?) -> LineSeries {
        addSeries(options: options ?? LineSeries.Options())
    }

    func addBaselineSeries(options: BaselineSeries.Options?) -> BaselineSeries {
        addSeries(options: options ?? BaselineSeries.Options())
    }

    func priceScale(priceScaleId: String) -> PriceScaleApi {
        let priceScale = PriceScale(context: context)
        let script = "window['\(priceScale.jsName)'] = \(paneExpression()).priceScale(\(priceScaleId.jsonString()));"
        context.submitScript(script)
        return priceScale
    }

}
