import UIKit

public protocol PaneApi: AnyObject {

    var index: Int { get }

    func size(completion: @escaping (Rectangle?) -> Void)

}

 /**
 The main interface of a single chart
 */
public protocol ChartApi: AnyObject {
    
    /**
     * Subsription delegate for chart events. Weak reference.
     */
    var delegate: ChartDelegate? { get set }
    
    /**
     * Removes the chart object including all DOM elements.
     * This is an irreversible operation, you cannot do anything with the chart after removing it.
     */
    func remove()

    /**
     * Sets fixed size of the chart. By default chart takes up 100% of its container
     * - Parameter height: target height of the chart
     * - Parameter width: target width of the chart
     * - Parameter forceRepaint: true to initiate resize immediately.
     * One could need this to get screenshot immediately after resize
     */
    func resize(width: Double, height: Double, forceRepaint: Bool?)

    // MARK: - Series methods
    /**
     * Creates an area series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addAreaSeries(options: AreaSeries.Options?) -> AreaSeries
    
    /**
     * Creates a bar series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addBarSeries(options: BarSeries.Options?) -> BarSeries
    
    /**
     * Creates a candlestick series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addCandlestickSeries(options: CandlestickSeries.Options?) -> CandlestickSeries
    
    /**
     * Creates a histogram series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addHistogramSeries(options: HistogramSeries.Options?) -> HistogramSeries

    /**
     * Creates a line series with specified parameters
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addLineSeries(options: LineSeries.Options?) -> LineSeries
    
    /**
     * Creates a baseline series with specified parameters.
     * - Parameter options: customization parameters of the series being created
     * - Returns: an interface of the created series
     */
    func addBaselineSeries(options: BaselineSeries.Options?) -> BaselineSeries

    // MARK: - Series methods with pane index (v5 multi-pane support)

    /**
     * Creates an area series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addAreaSeries(options: AreaSeries.Options?, paneIndex: Int) -> AreaSeries

    /**
     * Creates a bar series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addBarSeries(options: BarSeries.Options?, paneIndex: Int) -> BarSeries

    /**
     * Creates a candlestick series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addCandlestickSeries(options: CandlestickSeries.Options?, paneIndex: Int) -> CandlestickSeries

    /**
     * Creates a histogram series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addHistogramSeries(options: HistogramSeries.Options?, paneIndex: Int) -> HistogramSeries

    /**
     * Creates a line series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addLineSeries(options: LineSeries.Options?, paneIndex: Int) -> LineSeries

    /**
     * Creates a baseline series on the specified pane
     * - Parameter options: customization parameters of the series being created
     * - Parameter paneIndex: Index of the pane to attach the series to
     * - Returns: an interface of the created series
     */
    func addBaselineSeries(options: BaselineSeries.Options?, paneIndex: Int) -> BaselineSeries

    // MARK: - Pane management (v5)

    /**
     * Adds a new pane to the chart.
     */
    func addPane()

    /**
     * Returns all pane APIs currently attached to the chart.
     */
    func panes(completion: @escaping ([PaneApi]) -> Void)

    /**
     * Removes pane at a given index.
     */
    func removePane(index: Int)

    /**
     * Swaps positions of two panes.
     */
    func swapPanes(first: Int, second: Int)

    /**
     * Removes a series of any type.
     * This is an irreversible operation, you cannot do anything with the series after removing it
     * - Parameter seriesApi: Series to remove
     */
    func removeSeries<T: SeriesApi & SeriesObject>(seriesApi: T)
    
    // MARK: - Subsriptions methods
    /**
     * Adds a subscription to mouse click event
     * - Parameter handler: handler (function) to be called on mouse click
     */
    func subscribeClick()
    
    /**
     * Removes mouse click subscription
     * - Parameter handler: previously subscribed handler
     */
    func unsubscribeClick()

    /**
     * Adds a subscription to mouse double-click event
     */
    func subscribeDblClick()

    /**
     * Removes mouse double-click subscription
     */
    func unsubscribeDblClick()

    /**
     * Adds a subscription to crosshair movement to receive notifications on crosshair movements
     * - Parameter handler: handler (function) to be called on crosshair move
     */
    func subscribeCrosshairMove()

    /**
     * Removes a subscription on crosshair movement
     * - Parameter handler: previously subscribed handler
     */
    func unsubscribeCrosshairMove()

    /**
     * Sets crosshair position programmatically.
     */
    func setCrosshairPosition<T: SeriesApi & SeriesObject>(price: Double, horizontalPosition: Time, seriesApi: T)

    /**
     * Clears crosshair position previously set programmatically.
     */
    func clearCrosshairPosition()

    /**
     * Returns pane size for the specified pane index.
     */
    func paneSize(paneIndex: Int, completion: @escaping (Rectangle?) -> Void)

    // MARK: - Other APIs and options methods
    /**
     * Returns API to manipulate the price scale
     * - Parameter priceScaleID: id of scale to access to
     * - Returns: target API
     */
    func priceScale(priceScaleId: String?) -> PriceScaleApi

    /**
     * Returns API to manipulate the time scale
     * - Returns: target API
     */
    func timeScale() -> TimeScaleApi

    /**
     * Applies new options to the chart
     * - Parameter options: any subset of chart options
     */
    func applyOptions(options: ChartOptions)

    /**
     * Returns currently applied options
     * - Parameter completion: full set of currently applied options, including defaults
     */
    func options(completion: @escaping (ChartOptions?) -> Void)

    /**
     * Make a screenshot of the chart with all the elements excluding crosshair.
     * - Parameter completion: a canvas with the chart drawn on
     */
    func takeScreenshot(completion: @escaping (UIImage?) -> Void)

    /**
     * Make a screenshot of the chart with optional rendering flags.
     */
    func takeScreenshot(addTopLayer: Bool?, includeCrosshair: Bool?, completion: @escaping (UIImage?) -> Void)

    // MARK: - Watermark plugin methods

    /**
     * Creates a text watermark primitive on the specified pane.
     * - Parameter paneIndex: Index of the pane to attach the watermark to (default: 0 for the main pane).
     * - Parameter options: Watermark options including text, color, alignment, and font settings.
     * - Returns: A handle to the created text watermark for further operations (update/detach).
     */
    func createTextWatermark(paneIndex: Int, options: TextWatermarkOptions) -> TextWatermark

    /**
     * Creates an image watermark primitive on the specified pane.
     * - Parameter paneIndex: Index of the pane to attach the watermark to (default: 0 for the main pane).
     * - Parameter imageUrl: URL of the image to use as a watermark.
     * - Parameter options: Watermark options including alpha, padding, and size constraints.
     * - Returns: A handle to the created image watermark for further operations (update/detach).
     */
    func createImageWatermark(paneIndex: Int, imageUrl: String, options: ImageWatermarkOptions) -> ImageWatermark

}

// MARK: -
public extension ChartApi {

    func takeScreenshot(completion: @escaping (UIImage?) -> Void) {
        takeScreenshot(addTopLayer: nil, includeCrosshair: nil, completion: completion)
    }
    
    /**
     * Sets fixed size of the chart. By default chart takes up 100% of its container
     * - Parameter height: target height of the chart
     * - Parameter width: target width of the chart
     * - Parameter forceRepaint: true to initiate resize immediately.
     * One could need this to get screenshot immediately after resize
     */
    func resize(width: CGFloat, height: CGFloat, forceRepaint: Bool?) {
        self.resize(width: Double(width), height: Double(height), forceRepaint: forceRepaint)
    }
    
    /**
     * Sets fixed size of the chart. By default chart takes up 100% of its container
     * - Parameter height: target height of the chart
     * - Parameter width: target width of the chart
     * - Parameter forceRepaint: true to initiate resize immediately.
     * One could need this to get screenshot immediately after resize
     */
    func resize(width: Int, height: Int, forceRepaint: Bool?) {
        self.resize(width: Double(width), height: Double(height), forceRepaint: forceRepaint)
    }
    
}
