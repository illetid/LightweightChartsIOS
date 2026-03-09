import Foundation

public extension SeriesApi where Self: SeriesObject {
    
    func priceFormatter() -> PriceFormatterApi {
        let priceFormatter = PriceFormatter(context: context)
        let script = "window['\(priceFormatter.jsName)'] = \(jsName).priceFormatter();"
        context.evaluateScript(script) { _, _ in
        }
        return priceFormatter
    }
    
    func coordinateToPrice(coordinate: Double, completion: @escaping (BarPrice?) -> Void) {
        let script = "\(jsName).coordinateToPrice(\(coordinate));"
        context.evaluateScript(script) { (result, _) in
            completion(result as? BarPrice)
        }
    }
    
    func priceToCoordinate(price: Double, completion: @escaping (Coordinate?) -> Void) {
        let script = "\(jsName).priceToCoordinate(\(price));"
        context.evaluateScript(script) { (result, _) in
            completion(result as? Coordinate)
        }
    }
    
    func barsInLogicalRange(range: FromToRange<Double>, completion: @escaping (BarsInfo?) -> Void) {
        let script = "\(jsName).barsInLogicalRange(\(range.jsonString));"
        context.decodedResult(forScript: script, completion: completion)
    }
    
    func applyOptions(options: Options) {
        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        \(jsName).applyOptions(\(optionsScript.variableName));
        """
        context.evaluateScript(script, completion: nil)
    }
    
    func options(completion: @escaping (Options?) -> Void) {
        let script = "\(jsName).options();"
        context.decodedResult(forScript: script, completion: completion)
    }
    
    func priceScale() -> PriceScaleApi {
        let priceScale = PriceScale(context: context)
        let script = "window['\(priceScale.jsName)'] = \(jsName).priceScale();"
        context.evaluateScript(script) { _, _ in
        }
        return priceScale
    }
    
    func setData(data: [TickValue]) {
        setSeriesData(data)
    }

    func setData(data: [WhitespaceData]) {
        setSeriesData(data)
    }

    func setData(data: [SeriesDataType<TickValue>]) {
        setSeriesData(data)
    }

    func update(bar: TickValue) {
        updateSeriesBar(bar)
    }

    func update(bar: WhitespaceData) {
        updateSeriesBar(bar)
    }

    func update(bar: SeriesDataType<TickValue>) {
        updateSeriesBar(bar)
    }
    
    func dataByIndex(logicalIndex: Int, mismatchDirection: MismatchDirection? = nil, completion: @escaping (TickValue?) -> Void) {
        let direction = mismatchDirection?.rawValue ?? 0
        let script = "\(jsName).dataByIndex(\(logicalIndex), \(direction));"
        context.decodedResult(forScript: script, completion: completion)
    }
    
    func setMarkers(data: [SeriesMarker]) {
        // v5 compatibility: use createSeriesMarkers primitive
        // Store plugin reference on series object as _lwcMarkersPlugin
        let script = """
        if (typeof \(jsName)._lwcMarkersPlugin === 'undefined') {
            \(jsName)._lwcMarkersPlugin = LightweightCharts.createSeriesMarkers(\(jsName), \(data.jsonString));
        } else {
            if (typeof \(jsName)._lwcMarkersPlugin.setMarkers === 'function') {
                \(jsName)._lwcMarkersPlugin.setMarkers(\(data.jsonString));
            } else if (typeof \(jsName)._lwcMarkersPlugin.setData === 'function') {
                \(jsName)._lwcMarkersPlugin.setData(\(data.jsonString));
            }
        }
        """
        context.evaluateScript(script, completion: nil)
    }

    func markers(completion: @escaping ([SeriesMarker]?) -> Void) {
        // v5 compatibility: query markers from internal plugin if it exists
        let script = """
        (typeof \(jsName)._lwcMarkersPlugin !== 'undefined') ? \(jsName)._lwcMarkersPlugin.markers() : null;
        """
        context.decodedResult(forScript: script, completion: completion)
    }
    
    func createPriceLine(options: PriceLineOptions?) -> PriceLine {
        let priceLine = PriceLine(context: context)
        let options = options ?? PriceLineOptions()
        let script = "window['\(priceLine.jsName)'] = \(jsName).createPriceLine(\(options.jsonString));"
        context.evaluateScript(script, completion: nil)
        return priceLine
    }
    
    func removePriceLine(line: PriceLine) {
        let script = "\(jsName).removePriceLine(\(line.jsName));"
        context.evaluateScript(script, completion: nil)
    }

    func priceLines(completion: @escaping ([PriceLine]?) -> Void) {
        let countScript = "\(jsName).priceLines().length;"
        context.evaluateScript(countScript) { [self] result, _ in
            guard let count = (result as? NSNumber)?.intValue else {
                completion(nil)
                return
            }

            var lines: [PriceLine] = []
            for index in 0..<count {
                let priceLine = PriceLine(context: self.context)
                let createScript = "window['\(priceLine.jsName)'] = \(self.jsName).priceLines()[\(index)];"
                self.context.evaluateScript(createScript, completion: nil)
                lines.append(priceLine)
            }

            completion(lines)
        }
    }
    
    func seriesType(completion: @escaping (SeriesType?) -> Void) {
        let script = "\(jsName).seriesType();"
        context.decodedResult(forScript: script, completion: completion)
    }
    
    func seriesOrder(completion: @escaping (Int?) -> Void) {
        let script = "\(jsName).seriesOrder();"
        context.evaluateScript(script) { result, _ in
            completion((result as? NSNumber)?.intValue)
        }
    }
    
    func setSeriesOrder(order: Int) {
        let script = "\(jsName).setSeriesOrder(\(order));"
        context.evaluateScript(script, completion: nil)
    }
    
    func pop(count: Int, completion: @escaping ([TickValue]?) -> Void) {
        let script = "JSON.stringify(\(jsName).pop(\(count)));"
        context.decodedResult(forScript: script, completion: completion)
    }
    
    func lastValueData(globalLast: Bool, completion: @escaping (LastValueDataResult?) -> Void) {
        let script = "JSON.stringify(\(jsName).lastValueData(\(globalLast ? "true" : "false")));"
        context.decodedResult(forScript: script, completion: completion)
    }
    
    private func setSeriesData<T: SeriesData>(_ data: [T]) {
        // Update last data time tracking
        if let last = data.last {
            _lastDataTime = last.time
        } else {
            _lastDataTime = nil
        }

        let script = "\(jsName).setData(\(data.jsonString));"
        context.evaluateScript(script, completion: nil)
    }

    private func updateSeriesBar<T: SeriesData>(_ bar: T) {
        // Update last data time tracking
        _lastDataTime = bar.time

        let script = "\(jsName).update(\(bar.jsonString));"
        context.evaluateScript(script, completion: nil)
    }

    // MARK: - Plugin Factories

    /// Creates a new series markers plugin attached to this series.
    ///
    /// The plugin provides explicit control over markers, including setting/getting markers
    /// and applying options at runtime. Use the plugin's `detach()` method to remove it
    /// when no longer needed.
    ///
    /// - Parameters:
    ///   - data: Initial marker data to display.
    ///   - options: Optional initial plugin options.
    /// - Returns: A new `SeriesMarkersPlugin` instance attached to this series.
    func createMarkersPlugin(
        data: [SeriesMarker],
        options: SeriesMarkersOptions = SeriesMarkersOptions()
    ) -> SeriesMarkersPlugin<Self> {
        return SeriesMarkersPlugin(series: self, data: data, options: options)
    }
}

public extension SeriesApi where Self: UpDownMarkersSupported {

    /// Creates a new up-down markers plugin attached to this series.
    ///
    /// The plugin provides visual indicators for directional price movements.
    /// Use the plugin's `detach()` method to remove it when no longer needed.
    ///
    /// - Parameters:
    ///   - data: Initial marker data to display.
    ///   - options: Optional initial plugin options.
    /// - Returns: A new `UpDownMarkersPlugin` instance attached to this series.
    func createUpDownMarkersPlugin(
        data: [SeriesUpDownMarker]? = nil,
        options: UpDownMarkersOptions = UpDownMarkersOptions()
    ) -> UpDownMarkersPlugin<Self> {
        return UpDownMarkersPlugin(series: self, data: data, options: options)
    }

}
