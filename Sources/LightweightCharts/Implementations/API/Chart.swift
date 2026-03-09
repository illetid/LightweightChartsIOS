import Foundation
import WebKit

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
public class Chart: JavaScriptObject {
    
    enum SubscribeState: CaseIterable {
        case declared
        case active
    }

    /// The context type for chart operations.
    public typealias Context = JavaScriptEvaluator & JavaScriptMessageProducer
    
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
    private var legacyWatermarkOptions: DeprecatedWatermarkOptions?
    
    init(context: Context, closureStore: ClosuresStore?) {
        self._context = context
        self.closureStore = closureStore
        messageHandler = MessageHandler()
        messageHandler.delegate = self
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
        _context.evaluateScript(script, completion: nil)
    }

    /// Removes the legacy watermark if it exists
    private func removeLegacyWatermark() {
        let script = """
        if (typeof \(jsName)._lwcTextWatermark !== 'undefined') {
            \(jsName)._lwcTextWatermark.detach();
            delete \(jsName)._lwcTextWatermark;
        }
        """
        _context.evaluateScript(script, completion: nil)
    }

    private func addSeries<T: SeriesApi & SeriesObject>(options: T.Options, paneIndex: Int = 0) -> T {
        let series = T(context: context, closureStore: closureStore)
        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        var \(series.jsName) = \(jsName).addSeries(LightweightCharts.\(T.name), \(optionsScript.variableName), \(paneIndex));
        seriesArray.push({name: "\(series.jsName)", series: \(series.jsName)});
        """
        _context.evaluateScript(script, completion: nil)
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
    
    private func subscribe(subscription: Subscription) {
        if (activeSubscriptions[subscription] == .active) {
            NSLog("LWChart: double subscribe detected \(subscription)")
            return
        }
        let name = subscriberName(for: subscription)
        var subscriberScript = ""
        if (activeSubscriptions[subscription] != .declared) {
            subscriberScript = subsriberScript(forName: name, subscription: subscription)
            _context.addMessageHandler(messageHandler, name: name)
        }
        let script = subscriberScript + "\n\(jsName).subscribe\(subscription.jsRepresentation)(\(name));"
        _context.evaluateScript(script, completion: nil)
        activeSubscriptions[subscription] = .active
    }
    
    private func unsubscribe(subsription: Subscription) {
        if (activeSubscriptions[subsription] != .active) {
            NSLog("LWChart: double unsubscribe detected \(subsription)")
            return
        }
        let name = subscriberName(for: subsription)
        let script = "\(jsName).unsubscribe\(subsription.jsRepresentation)(\(name));"
        _context.evaluateScript(script, completion: nil)
        activeSubscriptions[subsription] = .declared
    }
    
    private func unsubscribeAll() {
        unsubscribeClick()
        unsubscribeDblClick()
        unsubscribeCrosshairMove()
    }
    
}

// MARK: - ChartApi
extension Chart: ChartApi {

    public func remove() {
        removeLegacyWatermark()
        unsubscribeAll()
        let script = "\(jsName).remove();"
        _context.evaluateScript(script, completion: nil)
    }
    
    public func resize(width: Double, height: Double, forceRepaint: Bool?) {
        var parameters = "\(width), \(height)"
        if let forceRepaint = forceRepaint {
            parameters += ", \(forceRepaint)"
        }
        let script = "\(jsName).resize(\(parameters));"
        _context.evaluateScript(script, completion: nil)
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
    public func addPane() {
        let script = "\(jsName).addPane();"
        _context.evaluateScript(script, completion: nil)
    }

    public func panes(completion: @escaping ([PaneApi]) -> Void) {
        let script = "\(jsName).panes().length;"
        _context.evaluateScript(script) { [self] result, _ in
            let count = (result as? NSNumber)?.intValue ?? 0
            let paneApis: [PaneApi] = (0..<count).map { index in
                Pane(index: index, chartJSName: self.jsName, context: self._context)
            }
            completion(paneApis)
        }
    }

    public func removePane(index: Int) {
        let script = "\(jsName).removePane(\(index));"
        _context.evaluateScript(script, completion: nil)
    }

    public func swapPanes(first: Int, second: Int) {
        let script = "\(jsName).swapPanes(\(first), \(second));"
        _context.evaluateScript(script, completion: nil)
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
        _context.evaluateScript(script, completion: nil)
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
        _context.evaluateScript(script, completion: nil)
    }

public func clearCrosshairPosition() {
        let script = "\(jsName).clearCrosshairPosition();"
        _context.evaluateScript(script, completion: nil)
    }

public func paneSize(paneIndex: Int, completion: @escaping (Rectangle?) -> Void) {
        let script = "\(jsName).paneSize(\(paneIndex));"
        _context.decodedResult(forScript: script, completion: completion)
    }
    
    // MARK: Other APIs and options methods
    
public func priceScale(priceScaleId: String?) -> PriceScaleApi {
        let priceScale = PriceScale(context: context)
    let priceScaleId = priceScaleId ?? ""
    let script = "window['\(priceScale.jsName)'] = \(jsName).priceScale(\(priceScaleId.jsonString()));"
        _context.evaluateScript(script) { _, _ in
        }
        return priceScale
    }
    
public func timeScale() -> TimeScaleApi {
        let timeScale = TimeScale(context: _context, closureStore: closureStore)
        let script = "var \(timeScale.jsName) = \(jsName).timeScale();"
        _context.evaluateScript(script) { _, _ in
        }
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
        _context.evaluateScript(script, completion: nil)

        // Apply legacy watermark compatibility after chart options (task 4.4)
        if options._watermarkWasExplicitlySet {
            if let watermark = watermark {
                applyLegacyWatermark(watermark)
            } else {
                removeLegacyWatermark()
            }
        }
    }
    
public func options(completion: @escaping (ChartOptions?) -> Void) {
        let script = "\(jsName).options();"
        _context.decodedResult(forScript: script, completion: completion)
    }

public func autoSizeActive(completion: @escaping (Bool?) -> Void) {
        let script = "\(jsName).autoSizeActive();"
        _context.evaluateScript(script) { result, _ in
            completion(result as? Bool)
        }
    }
    
public func takeScreenshot(addTopLayer: Bool?, includeCrosshair: Bool?, completion: @escaping (UIImage?) -> Void) {
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
        _context.evaluateScript(script) { (result, error) in
            // Extract String on main thread to avoid capturing bridged WebKit
            // objects into background queue (causes ProcessThrottler crash).
            let dataString: String?
            if error == nil, let str = result as? String, !str.isEmpty {
                dataString = str
            } else {
                dataString = nil
            }
            DispatchQueue.global().async {
                var image: UIImage?
                if let dataString = dataString {
                    // format:
                    // data:[<mediatype>][;base64],<data>
                    // example
                    // (data:image/jpeg;base64,/9j/4AAQSkZJRgA
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
                completion(image)
            }
        }
    }

    // MARK: - Watermark plugin methods

public func createTextWatermark(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermark {
        let watermark = TextWatermark(context: context, jsName: "textWatermark" + .uniqueString)
        let script = """
        var panes = \(jsName).panes();
        if (panes && panes[\(paneIndex)]) {
            var \(watermark.jsName) = LightweightCharts.createTextWatermark(panes[\(paneIndex)], \(options.jsonString()));
        } else {
            console.error('Invalid pane index: \(paneIndex)');
        }
        """
        _context.evaluateScript(script, completion: nil)
        return watermark
    }

public func createImageWatermark(paneIndex: Int, imageUrl: String, options: ImageWatermarkOptions) -> ImageWatermark {
        let watermark = ImageWatermark(context: context, jsName: "imageWatermark" + .uniqueString)
        let script = """
        var panes = \(jsName).panes();
        if (panes && panes[\(paneIndex)]) {
            var \(watermark.jsName) = LightweightCharts.createImageWatermark(panes[\(paneIndex)], \(imageUrl.jsonString()), \(options.jsonString()));
        } else {
            console.error('Invalid pane index: \(paneIndex)');
        }
        """
        _context.evaluateScript(script, completion: nil)
        return watermark
    }

    // MARK: - Plugin Factories

    /// Creates a text watermark plugin on the specified pane.
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
    }

    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveDblClickWithParameters parameters: MouseEventParams) {
        delegate?.didDoubleClick(onChart: self, parameters: parameters)
    }
    
    func messageHandler(_ messageHandler: MessageHandler,
                        didReceiveCrosshairMoveWithParameters parameters: MouseEventParams) {
        delegate?.didCrosshairMove(onChart: self, parameters: parameters)
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

final class Pane: PaneApi {

    let index: Int

    private let chartJSName: String
    private unowned let context: JavaScriptEvaluator

    init(index: Int, chartJSName: String, context: JavaScriptEvaluator) {
        self.index = index
        self.chartJSName = chartJSName
        self.context = context
    }

    func size(completion: @escaping (Rectangle?) -> Void) {
        let script = "\(chartJSName).paneSize(\(index));"
        context.decodedResult(forScript: script, completion: completion)
    }

    func getHeight(completion: @escaping (Double?) -> Void) {
        let script = "\(chartJSName).panes()[\(index)].getHeight();"
        context.evaluateScript(script) { result, _ in
            completion(result as? Double)
        }
    }

    func setHeight(height: Double) {
        let script = "\(chartJSName).panes()[\(index)].setHeight(\(height));"
        context.evaluateScript(script, completion: nil)
    }

    func moveTo(paneIndex: Int) {
        let script = "\(chartJSName).panes()[\(index)].moveTo(\(paneIndex));"
        context.evaluateScript(script, completion: nil)
    }

    func setPreserveEmptyPane(preserve: Bool) {
        let script = "\(chartJSName).panes()[\(index)].setPreserveEmptyPane(\(preserve ? "true" : "false"));"
        context.evaluateScript(script, completion: nil)
    }

    func preserveEmptyPane(completion: @escaping (Bool?) -> Void) {
        let script = "\(chartJSName).panes()[\(index)].preserveEmptyPane();"
        context.evaluateScript(script) { result, _ in
            completion(result as? Bool)
        }
    }

    func getStretchFactor(completion: @escaping (Double?) -> Void) {
        let script = "\(chartJSName).panes()[\(index)].getStretchFactor();"
        context.evaluateScript(script) { result, _ in
            completion(result as? Double)
        }
    }

    func setStretchFactor(stretchFactor: Double) {
        let script = "\(chartJSName).panes()[\(index)].setStretchFactor(\(stretchFactor));"
        context.evaluateScript(script, completion: nil)
    }

    func priceScale(priceScaleId: String) -> PriceScaleApi {
        let priceScale = PriceScale(context: context)
        let script = "window['\(priceScale.jsName)'] = \(chartJSName).panes()[\(index)].priceScale(\(priceScaleId.jsonString()));"
        context.evaluateScript(script, completion: nil)
        return priceScale
    }

}
