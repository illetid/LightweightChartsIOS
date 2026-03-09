import Foundation
import WebKit
import UIKit

public protocol LightweightChartsDelegate: AnyObject {
    
    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts)
    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error)
    
}

/// Lightweight Charting Library
public class LightweightCharts: UIView {
    
    /**
     * Loding delegate for chart. Tells the delegate when the chart has loaded or when the load failed. Weak reference.
     */
    public weak var loadDelegate: LightweightChartsDelegate?
    public weak var errorDelegate: JavaScriptErrorDelegate? {
        get { webView.errorDelegate }
        set { webView.errorDelegate = newValue }
    }
    
    private let webView: WebView = WebView()
    private let promptHandler: PromptHandler = PromptHandler()
    private var chart: ChartApi!
    private var initialOptions: ChartOptions?
    internal var openExternalURL: ((URL) -> Void)? = { url in
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    public required init(
        frame: CGRect = .zero,
        options: ChartOptions = ChartOptions(),
        loadDelegate: LightweightChartsDelegate? = nil
    ) {
        super.init(frame: frame)

        self.loadDelegate = loadDelegate
        self.initialOptions = options
        setupChart(options: options)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        self.initialOptions = ChartOptions()
        setupChart(options: initialOptions!)
    }
    
    /// This function is the main entry point of the Lightweight Charting Library
    /// - Parameter options: This function is the main entry point of the Lightweight Charting Library
    /// - Returns: an interface to the created chart
    private func createChart(options: ChartOptions?) -> ChartApi {
        let chart = Chart(context: webView, closureStore: promptHandler)
        let options = options ?? ChartOptions()

        // Store watermark for legacy compatibility (task 4.4)
        let watermark = options._watermark

        let optionsScript = options.optionsScript(for: promptHandler)
        let script = """
        \(optionsScript.options)
        var \(chart.jsName) = LightweightCharts.createChart(document.body, \(optionsScript.variableName));
        var seriesArray = [];
        """
        webView.evaluateScript(script) { [weak self] (_, error) in
            guard let self = self else { return }
            if let error = error {
                self.loadDelegate?.lightweightCharts(self, didFailLoadWithError: error)
            } else {
                // Apply legacy watermark after chart creation (task 4.4)
                if let watermark = watermark {
                    (self.chart as? Chart)?.applyLegacyWatermark(watermark)
                }
                self.loadDelegate?.lightweightChartsDidLoad(self)
            }
        }
        self.chart = chart
        return chart
    }
    
    public func clearWebViewBackground() {
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        webView.frame = bounds
        let width = bounds.width
        let height = bounds.height
        chart.resize(width: width, height: height, forceRepaint: nil)
    }
    
    private func setupChart(options: ChartOptions) {
        setupWebView()
        loadLibrary()
        loadWrapperFunctions()
        chart = createChart(options: options)
    }
    
    private func setupWebView() {
        webView.uiDelegate = promptHandler
        webView.navigationDelegate = self
        
        let scrollView = webView.scrollView
        if #available(iOS 11, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        scrollView.isScrollEnabled = false
        
        addSubview(webView)
        
        evaluateScriptFromFile(withFileName: "content-setup")
    }
    
    private func loadLibrary() {
        evaluateScriptFromFile(withFileName: "lightweight-charts")
    }
    
    private func loadWrapperFunctions() {
        evaluateScriptFromFile(withFileName: "wrapper_functions")
    }
    
    private func loadScript(withName fileName: String) throws -> String {
        let bundle = Bundle.module
        let pathForJSRuntime = bundle.path(forResource: fileName, ofType: "js")
        guard let path = pathForJSRuntime else {
            return ""
        }
        return try String(contentsOfFile: path, encoding: .utf8)
    }
    
    private func evaluateScriptFromFile(withFileName fileName: String) {
        do {
            let script = try loadScript(withName: fileName)
            webView.evaluateJavaScript(script) { [weak self] (_, error) in
                guard let self = self else { return }
                if let error = error {
                    self.loadDelegate?.lightweightCharts(self, didFailLoadWithError: error)
                }
            }
        } catch {
            loadDelegate?.lightweightCharts(self, didFailLoadWithError: error)
        }
    }
    
}

// MARK: - Attribution link routing
extension LightweightCharts: WKNavigationDelegate {

    internal func shouldOpenInExternalBrowser(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else {
            return false
        }
        return host.contains("tradingview.com")
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }

        guard shouldOpenInExternalBrowser(navigationAction.request.url),
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        openExternalURL?(url)
        decisionHandler(.cancel)
    }
}

// MARK: - ChartApi
extension LightweightCharts: ChartApi {
    
    public var delegate: ChartDelegate? {
        get {
            chart.delegate
        }
        set {
            chart.delegate = newValue
        }
    }
    
    public func remove() {
        chart.remove()
    }
    
    public func resize(width: Double, height: Double, forceRepaint: Bool?) {
        chart.resize(width: width, height: height, forceRepaint: forceRepaint)
    }
    
    public func addAreaSeries(options: AreaSeries.Options?) -> AreaSeries {
        chart.addAreaSeries(options: options)
    }
    
    public func addBarSeries(options: BarSeries.Options?) -> BarSeries {
        chart.addBarSeries(options: options)
    }
    
    public func addCandlestickSeries(options: CandlestickSeries.Options?) -> CandlestickSeries {
        chart.addCandlestickSeries(options: options)
    }
    
    public func addHistogramSeries(options: HistogramSeries.Options?) -> HistogramSeries {
        chart.addHistogramSeries(options: options)
    }
    
    public func addLineSeries(options: LineSeries.Options?) -> LineSeries {
        chart.addLineSeries(options: options)
    }
    
    public func addBaselineSeries(options: BaselineSeries.Options?) -> BaselineSeries {
        chart.addBaselineSeries(options: options)
    }
    
    public func removeSeries<T: SeriesObject & SeriesApi>(seriesApi: T) {
        chart.removeSeries(seriesApi: seriesApi)
    }

    // MARK: - Series methods with pane index (v5 multi-pane support)

    public func addAreaSeries(options: AreaSeries.Options?, paneIndex: Int) -> AreaSeries {
        chart.addAreaSeries(options: options, paneIndex: paneIndex)
    }

    public func addBarSeries(options: BarSeries.Options?, paneIndex: Int) -> BarSeries {
        chart.addBarSeries(options: options, paneIndex: paneIndex)
    }

    public func addCandlestickSeries(options: CandlestickSeries.Options?, paneIndex: Int) -> CandlestickSeries {
        chart.addCandlestickSeries(options: options, paneIndex: paneIndex)
    }

    public func addHistogramSeries(options: HistogramSeries.Options?, paneIndex: Int) -> HistogramSeries {
        chart.addHistogramSeries(options: options, paneIndex: paneIndex)
    }

    public func addLineSeries(options: LineSeries.Options?, paneIndex: Int) -> LineSeries {
        chart.addLineSeries(options: options, paneIndex: paneIndex)
    }

    public func addBaselineSeries(options: BaselineSeries.Options?, paneIndex: Int) -> BaselineSeries {
        chart.addBaselineSeries(options: options, paneIndex: paneIndex)
    }

    // MARK: - Pane management (v5)

    /// Adds a new pane to the chart.
    public func addPane() {
        chart.addPane()
    }

    public func panes(completion: @escaping ([PaneApi]) -> Void) {
        chart.panes(completion: completion)
    }

    public func removePane(index: Int) {
        chart.removePane(index: index)
    }

    public func swapPanes(first: Int, second: Int) {
        chart.swapPanes(first: first, second: second)
    }
    
    public func subscribeClick() {
        chart.subscribeClick()
    }
    
    public func unsubscribeClick() {
        chart.unsubscribeClick()
    }

    public func subscribeDblClick() {
        chart.subscribeDblClick()
    }

    public func unsubscribeDblClick() {
        chart.unsubscribeDblClick()
    }
    
    public func subscribeCrosshairMove() {
        chart.subscribeCrosshairMove()
    }
    
    public func unsubscribeCrosshairMove() {
        chart.unsubscribeCrosshairMove()
    }

    public func setCrosshairPosition<T: SeriesApi & SeriesObject>(price: Double, horizontalPosition: Time, seriesApi: T) {
        chart.setCrosshairPosition(price: price, horizontalPosition: horizontalPosition, seriesApi: seriesApi)
    }

    public func clearCrosshairPosition() {
        chart.clearCrosshairPosition()
    }

    public func paneSize(paneIndex: Int, completion: @escaping (Rectangle?) -> Void) {
        chart.paneSize(paneIndex: paneIndex, completion: completion)
    }
    
    public func priceScale(priceScaleId: String?) -> PriceScaleApi {
        chart.priceScale(priceScaleId: priceScaleId)
    }
    
    public func timeScale() -> TimeScaleApi {
        chart.timeScale()
    }
    
    public func applyOptions(options: ChartOptions) {
        chart.applyOptions(options: options)
    }
    
    public func options(completion: @escaping (ChartOptions?) -> Void) {
        chart.options(completion: completion)
    }

    public func autoSizeActive(completion: @escaping (Bool?) -> Void) {
        chart.autoSizeActive(completion: completion)
    }
    
    public func takeScreenshot(addTopLayer: Bool?, includeCrosshair: Bool?, completion: @escaping (UIImage?) -> Void) {
        chart.takeScreenshot(addTopLayer: addTopLayer, includeCrosshair: includeCrosshair, completion: completion)
    }

    public func createTextWatermark(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermark {
        chart.createTextWatermark(paneIndex: paneIndex, options: options)
    }

    public func createImageWatermark(paneIndex: Int, imageUrl: String, options: ImageWatermarkOptions) -> ImageWatermark {
        chart.createImageWatermark(paneIndex: paneIndex, imageUrl: imageUrl, options: options)
    }

    /// Creates a text watermark plugin on the specified pane.
    ///
    /// - Parameters:
    ///   - paneIndex: The index of the pane to attach the plugin to (0 is the main pane).
    ///   - options: Initial options for the text watermark.
    /// - Returns: A new text watermark plugin instance.
    public func createTextWatermarkPlugin(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermarkPlugin<Chart> {
        guard let chart = chart as? Chart else {
            fatalError("Internal chart is not of expected type Chart")
        }
        return chart.createTextWatermarkPlugin(paneIndex: paneIndex, options: options)
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
        guard let chart = chart as? Chart else {
            fatalError("Internal chart is not of expected type Chart")
        }
        return chart.createImageWatermarkPlugin(paneIndex: paneIndex, imageUrl: imageUrl, options: options)
    }

}
