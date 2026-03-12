import Foundation
import WebKit
import UIKit

@MainActor
private final class BufferedJavaScriptContext: JavaScriptEvaluator, JavaScriptMessageProducer, JavaScriptCallbackEvaluator {

    private enum BootstrapStatus {
        case loading
        case ready
        case failed(JavaScriptBridgeError)
        case cancelled
    }

    private enum PendingOperation {
        case script(String)
        case callback(script: String, run: (WebView) -> Void, fail: (Error) -> Void)
    }

    private let webView: WebView
    private var bootstrapStatus: BootstrapStatus = .loading
    private var pendingOperations: [PendingOperation] = []
    private var readyContinuations: [CheckedContinuation<Void, Error>] = []

    init(webView: WebView) {
        self.webView = webView
    }

    func submitScript(_ script: String) {
        switch bootstrapStatus {
        case .ready:
            webView.submitScript(script)
        case .loading:
            pendingOperations.append(.script(script))
        case .failed(let bootstrapError):
            webView.errorDelegate?.didFailEvaluateScript(script, withError: bootstrapError)
        case .cancelled:
            break
        }
    }

    func evaluateScript(_ script: String) async throws(JavaScriptBridgeError) -> Any? {
        try JavaScriptBridgeError.checkCancellation()
        try await waitUntilReady()
        try JavaScriptBridgeError.checkCancellation()
        return try await webView.evaluateScript(script)
    }

    func evaluate<T: Decodable>(script: String, resultType: T.Type) async throws(JavaScriptBridgeError) -> T {
        try JavaScriptBridgeError.checkCancellation()
        try await waitUntilReady()
        try JavaScriptBridgeError.checkCancellation()
        return try await webView.evaluate(script: script, resultType: resultType)
    }

    func decodedResult<T: Decodable>(forScript script: String) async throws(JavaScriptBridgeError) -> T {
        try JavaScriptBridgeError.checkCancellation()
        try await waitUntilReady()
        try JavaScriptBridgeError.checkCancellation()
        return try await webView.decodedResult(forScript: script)
    }

    func evaluate<T: Decodable>(
        script: String,
        resultType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        switch bootstrapStatus {
        case .ready:
            webView.evaluate(script: script, resultType: resultType, completion: completion)
        case .loading:
            pendingOperations.append(
                .callback(
                    script: script,
                    run: { webView in
                        webView.evaluate(script: script, resultType: resultType, completion: completion)
                    },
                    fail: { error in
                        completion(.failure(error))
                    }
                )
            )
        case .failed(let bootstrapError):
            completion(.failure(bootstrapError))
        case .cancelled:
            completion(.failure(JavaScriptBridgeError.cancelled))
        }
    }

    func decodedResult<T: Decodable>(
        forScript script: String,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        switch bootstrapStatus {
        case .ready:
            webView.decodedResult(forScript: script, completion: completion)
        case .loading:
            pendingOperations.append(
                .callback(
                    script: script,
                    run: { webView in
                        webView.decodedResult(forScript: script, completion: completion)
                    },
                    fail: { error in
                        completion(.failure(error))
                    }
                )
            )
        case .failed(let bootstrapError):
            completion(.failure(bootstrapError))
        case .cancelled:
            completion(.failure(JavaScriptBridgeError.cancelled))
        }
    }

    func addMessageHandler(_ messageHandler: WKScriptMessageHandler, name: String) {
        webView.addMessageHandler(messageHandler, name: name)
    }

    func finishBootstrap() {
        guard case .loading = bootstrapStatus else { return }

        bootstrapStatus = .ready

        while !pendingOperations.isEmpty {
            let operations = pendingOperations
            pendingOperations.removeAll()

            for operation in operations {
                switch operation {
                case .script(let script):
                    webView.submitScript(script)
                case .callback(_, let run, _):
                    run(webView)
                }
            }
        }

        let continuations = readyContinuations
        readyContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func failBootstrap(with error: JavaScriptBridgeError) {
        guard case .loading = bootstrapStatus else { return }

        bootstrapStatus = .failed(error)

        let operations = pendingOperations
        pendingOperations.removeAll()
        for operation in operations {
            switch operation {
            case .script(let script):
                webView.errorDelegate?.didFailEvaluateScript(script, withError: error)
            case .callback(let script, _, let fail):
                webView.errorDelegate?.didFailEvaluateScript(script, withError: error)
                fail(error)
            }
        }

        let continuations = readyContinuations
        readyContinuations.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }

    func cancelBootstrap() {
        guard case .loading = bootstrapStatus else { return }

        bootstrapStatus = .cancelled

        let operations = pendingOperations
        pendingOperations.removeAll()
        for operation in operations {
            switch operation {
            case .script:
                break
            case .callback(_, _, let fail):
                fail(JavaScriptBridgeError.cancelled)
            }
        }

        let continuations = readyContinuations
        readyContinuations.removeAll()
        continuations.forEach { $0.resume(throwing: JavaScriptBridgeError.cancelled) }
    }

    private func waitUntilReady() async throws(JavaScriptBridgeError) {
        try JavaScriptBridgeError.checkCancellation()
        switch bootstrapStatus {
        case .ready:
            return
        case .failed(let bootstrapError):
            throw bootstrapError
        case .cancelled:
            throw .cancelled
        case .loading:
            break
        }

        do {
            try await withCheckedThrowingContinuation { continuation in
                readyContinuations.append(continuation)
            }
        } catch {
            throw JavaScriptBridgeError.wrap(error, script: "<bootstrap>")
        }
    }
}

@MainActor
public protocol LightweightChartsDelegate: AnyObject {
    
    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts)
    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error)
    
}

/// Lightweight Charting Library
public class LightweightCharts: UIView {

    private enum BootstrapState {
        case loading
        case ready
        case failed(Error)
        case cancelled
        case removed
    }

    internal enum BootstrapMode {
        case automatic
        case deferred
    }
    
    /**
     * Loding delegate for chart. Tells the delegate when the chart has loaded or when the load failed. Weak reference.
     */
    public weak var loadDelegate: LightweightChartsDelegate?
    public weak var errorDelegate: JavaScriptErrorDelegate? {
        get { webView.errorDelegate }
        set { webView.errorDelegate = newValue }
    }
    
    private let webView: WebView
    private lazy var chartContext = BufferedJavaScriptContext(webView: webView)
    private let promptHandler: PromptHandler = PromptHandler()
    private let scriptLoader: (String) throws -> String
    private let bootstrapMode: BootstrapMode
    private var chart: ChartApi!
    private var initialOptions: ChartOptions?
    private var pendingBootstrapPlan: BootstrapPlan?
    private var bootstrapState: BootstrapState = .loading
    private var bootstrapTask: Task<Void, Never>?
    private var didCreateJavaScriptChart = false
    private var readyHandlers: [(LightweightCharts) -> Void] = []
    private var loadFailureHandlers: [(LightweightCharts, Error) -> Void] = []
    internal var openExternalURL: ((URL) -> Void)? = { url in
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    internal var bootstrapScriptEvaluatorOverride: ((String) async throws(JavaScriptBridgeError) -> Any?)?
    internal var afterCreateChartScriptHook: (() async -> Void)?
    internal var rawScriptSubmitterOverride: ((String) -> Void)?
    
    public required init(
        frame: CGRect = .zero,
        options: ChartOptions = ChartOptions(),
        loadDelegate: LightweightChartsDelegate? = nil
    ) {
        self.webView = WebView()
        self.scriptLoader = { try Self.defaultLoadScript(named: $0) }
        self.bootstrapMode = .automatic
        super.init(frame: frame)

        self.loadDelegate = loadDelegate
        self.initialOptions = options
        setupChart(options: options)
    }

    internal init(
        frame: CGRect = .zero,
        options: ChartOptions = ChartOptions(),
        loadDelegate: LightweightChartsDelegate? = nil,
        webView: WebView = WebView(),
        scriptLoader: ((String) throws -> String)? = nil,
        bootstrapMode: BootstrapMode = .automatic
    ) {
        self.webView = webView
        self.scriptLoader = scriptLoader ?? { try LightweightCharts.defaultLoadScript(named: $0) }
        self.bootstrapMode = bootstrapMode
        super.init(frame: frame)

        self.loadDelegate = loadDelegate
        self.initialOptions = options
        setupChart(options: options)
    }
    
    required init?(coder: NSCoder) {
        self.webView = WebView()
        self.scriptLoader = { try Self.defaultLoadScript(named: $0) }
        self.bootstrapMode = .automatic
        super.init(coder: coder)

        self.initialOptions = ChartOptions()
        setupChart(options: initialOptions!)
    }
    
    private struct BootstrapPlan {
        let chart: ChartApi
        let createChartScript: String
        let legacyWatermark: DeprecatedWatermarkOptions?
    }

    /// This function is the main entry point of the Lightweight Charting Library
    /// - Parameter options: This function is the main entry point of the Lightweight Charting Library
    /// - Returns: chart wrapper plus the bootstrap script that creates the underlying JS chart.
    private func makeBootstrapPlan(options: ChartOptions?) -> BootstrapPlan {
        let chart = Chart(context: chartContext, closureStore: promptHandler)
        let options = options ?? ChartOptions()
        let optionsScript = options.optionsScript(for: promptHandler)
        let createChartScript = """
        \(optionsScript.options)
        var \(chart.jsName) = LightweightCharts.createChart(document.body, \(optionsScript.variableName));
        var seriesArray = [];
        """
        return BootstrapPlan(chart: chart, createChartScript: createChartScript, legacyWatermark: options._watermark)
    }
    
    public func clearWebViewBackground() {
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
    }

    /// Returns true once the JavaScript runtime, wrapper helpers, and chart instance are ready.
    public var isReady: Bool {
        if case .ready = bootstrapState {
            return true
        }
        return false
    }

    /// Queues work until the chart bootstrap finishes, or runs it immediately if already ready.
    public func whenReady(_ handler: @escaping (LightweightCharts) -> Void) {
        switch bootstrapState {
        case .ready:
            handler(self)
        case .failed:
            break
        case .cancelled:
            break
        case .removed:
            break
        case .loading:
            readyHandlers.append(handler)
        }
    }

    /// Registers a handler for bootstrap failures, or runs it immediately if the chart has already failed to load.
    public func onLoadError(_ handler: @escaping (LightweightCharts, Error) -> Void) {
        switch bootstrapState {
        case .failed(let error):
            handler(self, error)
        case .ready:
            break
        case .cancelled:
            break
        case .removed:
            break
        case .loading:
            loadFailureHandlers.append(handler)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        webView.frame = bounds
        switch bootstrapState {
        case .loading, .ready:
            break
        case .failed, .cancelled, .removed:
            return
        }
        let width = bounds.width
        let height = bounds.height
        chart.resize(width: width, height: height, forceRepaint: nil)
    }
    
    private func setupChart(options: ChartOptions) {
        setupWebView()
        let bootstrapPlan = makeBootstrapPlan(options: options)
        pendingBootstrapPlan = bootstrapPlan
        chart = bootstrapPlan.chart
        if case .automatic = bootstrapMode {
            startBootstrapIfNeeded()
        }
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
        
    }
    
    private static func defaultLoadScript(named fileName: String) throws -> String {
        let bundle = Bundle.module
        let pathForJSRuntime = bundle.path(forResource: fileName, ofType: "js")
        guard let path = pathForJSRuntime else {
            return ""
        }
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    internal func startBootstrapIfNeeded() {
        guard case .loading = bootstrapState,
              bootstrapTask == nil,
              let bootstrapPlan = pendingBootstrapPlan else {
            return
        }

        pendingBootstrapPlan = nil
        bootstrap(plan: bootstrapPlan)
    }

    private func evaluateBootstrapScript(_ script: String) async throws(JavaScriptBridgeError) -> Any? {
        if let bootstrapScriptEvaluatorOverride {
            return try await bootstrapScriptEvaluatorOverride(script)
        }
        return try await webView.evaluateScript(script)
    }

    private func submitRawScript(_ script: String) {
        if let rawScriptSubmitterOverride {
            rawScriptSubmitterOverride(script)
            return
        }
        webView.submitScript(script)
    }

    private func directChartCleanupScript() -> String? {
        guard let chart = chart as? Chart else {
            return nil
        }

        return """
        (function() {
            if (typeof \(chart.jsName) !== 'undefined' && \(chart.jsName) && typeof \(chart.jsName).remove === 'function') {
                \(chart.jsName).remove();
            }
        })();
        """
    }

    private func performDirectChartCleanupIfNeeded() {
        guard didCreateJavaScriptChart, let script = directChartCleanupScript() else {
            return
        }

        submitRawScript(script)
        didCreateJavaScriptChart = false
    }
    
    private func bootstrap(plan: BootstrapPlan) {
        bootstrapTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer { self.bootstrapTask = nil }
            do {
                let contentSetupScript = try self.scriptLoader("content-setup")
                let libraryScript = try self.scriptLoader("lightweight-charts")
                let wrapperScript = try self.scriptLoader("wrapper_functions")

                _ = try await self.evaluateBootstrapScript(contentSetupScript)
                _ = try await self.evaluateBootstrapScript(libraryScript)
                _ = try await self.evaluateBootstrapScript(wrapperScript)
                _ = try await self.evaluateBootstrapScript(plan.createChartScript)
                self.didCreateJavaScriptChart = true

                if let afterCreateChartScriptHook {
                    await afterCreateChartScriptHook()
                }

                guard case .loading = self.bootstrapState else {
                    return
                }

                self.chartContext.finishBootstrap()

                if let watermark = plan.legacyWatermark {
                    (self.chart as? Chart)?.applyLegacyWatermark(watermark)
                }

                guard case .loading = self.bootstrapState else {
                    return
                }

                self.bootstrapState = .ready
                let readyHandlers = self.readyHandlers
                self.readyHandlers.removeAll()
                self.loadFailureHandlers.removeAll()
                readyHandlers.forEach { $0(self) }
                self.loadDelegate?.lightweightChartsDidLoad(self)
            } catch {
                guard case .loading = self.bootstrapState else {
                    return
                }

                let bridgeError = JavaScriptBridgeError.wrap(error, script: "<bootstrap>")
                self.chartContext.failBootstrap(with: bridgeError)
                self.bootstrapState = .failed(bridgeError)
                self.readyHandlers.removeAll()
                let loadFailureHandlers = self.loadFailureHandlers
                self.loadFailureHandlers.removeAll()
                loadFailureHandlers.forEach { $0(self, bridgeError) }
                self.loadDelegate?.lightweightCharts(self, didFailLoadWithError: bridgeError)
            }
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
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
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

    public var clickEvents: AsyncStream<MouseEventParams> {
        chart.clickEvents
    }

    public var doubleClickEvents: AsyncStream<MouseEventParams> {
        chart.doubleClickEvents
    }

    public var crosshairMoveEvents: AsyncStream<MouseEventParams> {
        chart.crosshairMoveEvents
    }
    
    public var delegate: ChartDelegate? {
        get {
            chart.delegate
        }
        set {
            chart.delegate = newValue
        }
    }
    
    public func remove() {
        switch bootstrapState {
        case .loading:
            chart.remove()
            chartContext.cancelBootstrap()
            bootstrapState = .cancelled
            readyHandlers.removeAll()
            loadFailureHandlers.removeAll()
            bootstrapTask?.cancel()
            bootstrapTask = nil
            pendingBootstrapPlan = nil
            performDirectChartCleanupIfNeeded()
        case .ready:
            chart.remove()
            bootstrapState = .removed
            didCreateJavaScriptChart = false
            pendingBootstrapPlan = nil
            readyHandlers.removeAll()
            loadFailureHandlers.removeAll()
        case .failed, .cancelled, .removed:
            break
        }
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
    public func addPane(preserveEmptyPane: Bool? = nil) -> PaneApi {
        chart.addPane(preserveEmptyPane: preserveEmptyPane)
    }

    public func panes() async throws(JavaScriptBridgeError) -> [PaneApi] {
        try await chart.panes()
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

    public func paneSize(paneIndex: Int) async throws(JavaScriptBridgeError) -> Rectangle {
        try await chart.paneSize(paneIndex: paneIndex)
    }

    public func priceScale(priceScaleId: String?, paneIndex: Int? = nil) -> PriceScaleApi {
        chart.priceScale(priceScaleId: priceScaleId, paneIndex: paneIndex)
    }

    public func timeScale() -> TimeScaleApi {
        chart.timeScale()
    }

    public func applyOptions(options: ChartOptions) {
        chart.applyOptions(options: options)
    }

    public func options() async throws(JavaScriptBridgeError) -> ChartOptions {
        try await chart.options()
    }

    public func autoSizeActive() async throws(JavaScriptBridgeError) -> Bool {
        try await chart.autoSizeActive()
    }

    public func takeScreenshot(addTopLayer: Bool?, includeCrosshair: Bool?) async throws(JavaScriptBridgeError) -> UIImage {
        try await chart.takeScreenshot(addTopLayer: addTopLayer, includeCrosshair: includeCrosshair)
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
