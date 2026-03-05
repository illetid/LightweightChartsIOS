import Foundation

/**
 * Structure describing options of the chart. Series options are to be set separately
 */
public struct ChartOptions: Codable {
    
    /**
     Width of the chart
     */
    public var width: Double?
    
    /**
     Height of the chart
     */
    public var height: Double?
    
    /**
     Structure with watermark options

     - Deprecated: Watermark is no longer a chart option in v5. Use the new watermark plugin API:
       `chart.createTextWatermark(paneIndex:options:)` instead. See MIGRATION_V4_TO_V5.md for details.
     */
    @available(*, deprecated, message: "Watermark is no longer a chart option in v5. Use chart.createTextWatermark(paneIndex:options:) instead. See MIGRATION_V4_TO_V5.md for details.")
    public var watermark: DeprecatedWatermarkOptions? {
        get { return _watermark }
        set {
            _watermark = newValue
            _watermarkWasExplicitlySet = true
        }
    }
    
    internal var _watermark: DeprecatedWatermarkOptions?
    internal var _watermarkWasExplicitlySet: Bool = false
    
    /**
     Structure with layout options
     */
    public var layout: LayoutOptions?
    
    /**
     Structure with price scale option for left price scale
     */
    public var leftPriceScale: VisiblePriceScaleOptions?
    
    /**
     Structure with price scale option for right price scale
     */
    public var rightPriceScale: VisiblePriceScaleOptions?
    
    /**
     Structure describing default price scale options for overlays
     */
    public var overlayPriceScales: OverlayPriceScaleOptions?
    
    /**
     Structure with time scale options
     */
    public var timeScale: TimeScaleOptions?
    
    /**
     Structure with crosshair options
     */
    public var crosshair: CrosshairOptions?
    
    /**
     Structure with grid options
     */
    public var grid: GridOptions?
    
    /**
     Structure with localization options
     */
    public var localization: LocalizationOptions?
    
    /**
     Structure that describes scrolling behavior or boolean flag that disables/enables all kinds of scrolls
     */
    public var handleScroll: HandleScrollOptions?
    
    /**
     Structure that describes scaling behavior or boolean flag that disables/enables all kinds of scales
     */
    public var handleScale: TogglableOptions<HandleScaleOptions>?
    
    /**
     Structure that describes kinetic scroll behavior
     */
    public var kineticScroll: KineticScrollOptions?
    
    /**
     Represent options for the tracking mode's behavior.
     */
    public var trackingMode: TrackingModeOptions?
        
    public init(width: Double? = nil,
                height: Double? = nil,
                watermark: DeprecatedWatermarkOptions? = nil,
                layout: LayoutOptions? = nil,
                leftPriceScale: VisiblePriceScaleOptions? = nil,
                rightPriceScale: VisiblePriceScaleOptions? = nil,
                overlayPriceScales: OverlayPriceScaleOptions? = nil,
                timeScale: TimeScaleOptions? = nil,
                crosshair: CrosshairOptions? = nil,
                grid: GridOptions? = nil,
                localization: LocalizationOptions? = nil,
                handleScroll: HandleScrollOptions? = nil,
                handleScale: TogglableOptions<HandleScaleOptions>? = nil,
                kineticScroll: KineticScrollOptions? = nil,
                trackingMode: TrackingModeOptions? = nil) {
        self.width = width
        self.height = height
        self._watermark = watermark
        self._watermarkWasExplicitlySet = watermark != nil
        self.layout = layout
        self.leftPriceScale = leftPriceScale
        self.rightPriceScale = rightPriceScale
        self.overlayPriceScales = overlayPriceScales
        self.timeScale = timeScale
        self.crosshair = crosshair
        self.grid = grid
        self.localization = localization
        self.handleScroll = handleScroll
        self.handleScale = handleScale
        self.kineticScroll = kineticScroll
        self.trackingMode = trackingMode
    }
    
    enum CodingKeys: String, CodingKey {
        case width, height, layout, leftPriceScale, rightPriceScale, overlayPriceScales, timeScale, crosshair, grid, localization, handleScroll, handleScale, kineticScroll, trackingMode
        case _watermark = "watermark"
    }
    
}

// MARK: -
extension ChartOptions {

    /// Options struct for JS serialization that excludes deprecated properties
    private struct JSChartOptions: Encodable {
        var width: Double?
        var height: Double?
        var layout: LayoutOptions?
        var leftPriceScale: VisiblePriceScaleOptions?
        var rightPriceScale: VisiblePriceScaleOptions?
        var overlayPriceScales: OverlayPriceScaleOptions?
        var timeScale: TimeScaleOptions?
        var crosshair: CrosshairOptions?
        var grid: GridOptions?
        var localization: LocalizationOptions?
        var handleScroll: HandleScrollOptions?
        var handleScale: TogglableOptions<HandleScaleOptions>?
        var kineticScroll: KineticScrollOptions?
        var trackingMode: TrackingModeOptions?

        init(_ options: ChartOptions) {
            self.width = options.width
            self.height = options.height
            self.layout = options.layout
            self.leftPriceScale = options.leftPriceScale
            self.rightPriceScale = options.rightPriceScale
            self.overlayPriceScales = options.overlayPriceScales
            self.timeScale = options.timeScale
            self.crosshair = options.crosshair
            self.grid = options.grid
            self.localization = options.localization
            self.handleScroll = options.handleScroll
            self.handleScale = options.handleScale
            self.kineticScroll = options.kineticScroll
            self.trackingMode = options.trackingMode
        }
    }

    func optionsScript(for closuresStore: ClosuresStore?) -> (options: String, variableName: String) {
        let variableName = "options"
        // Use JSChartOptions which excludes the deprecated watermark property (task 4.3)
        let jsOptions = JSChartOptions(self)
        var optionsScript = "var \(variableName) = \(jsOptions.jsonString);"
        if let formatter = localization?.priceFormatterJSFunction {
            closuresStore?.addMethod(formatter.function, forName: formatter.name)
            optionsScript.append("\(variableName).localization.priceFormatter = \(formatter.script());")
        }
        if let formatter = localization?.timeFormatterJSFunction {
            closuresStore?.addMethod(formatter.function, forName: formatter.name)
            optionsScript.append("\(variableName).localization.timeFormatter = \(formatter.script());")
        }
        if let formatter = localization?.percentageFormatterJSFunction {
            closuresStore?.addMethod(formatter.function, forName: formatter.name)
            optionsScript.append("\(variableName).localization.percentageFormatter = \(formatter.script());")
        }
        if let formatter = timeScale?.tickMarkFormatterJSFunction {
            closuresStore?.addMethod(formatter.function, forName: formatter.name)
            optionsScript.append("\(variableName).timeScale.tickMarkFormatter = \(formatter.script());")
        }
        return (optionsScript, variableName)
    }

}
