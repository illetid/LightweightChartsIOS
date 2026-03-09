import Foundation

/** Interface to control chart's price scale */
public protocol PriceScaleApi: AnyObject {
    
    /**
     * Applies new options to the price scale
     * - Parameter options: any subset of PriceScaleOptions
     */
    func applyOptions(options: PriceScaleOptions)

    /**
     * Returns currently applied options of the price scale
     * - Parameter completion: full set of currently applied options, including defaults
     */
    func options(completion: @escaping (PriceScaleOptions?) -> Void)
    
    /**
     * Returns a width of the price scale if it's visible or 0 if invisible.
     * - Parameter completion: a width of the price scale if it's visible or 0 if invisible
     */
    func width(completion: @escaping (Double?) -> Void)
    
    /**
     * Sets the visible price range on this price scale.
     * - Parameter from: the lower bound of the price range
     * - Parameter to: the upper bound of the price range
     */
    func setVisibleRange(from: Double, to: Double)
    
    /**
     * Returns the current visible price range on this price scale.
     * - Parameter completion: the visible range, or nil if not available
     */
    func getVisibleRange(completion: @escaping (FromToRange<Double>?) -> Void)
    
    /**
     * Enables or disables auto-scaling on this price scale.
     * - Parameter on: true to enable auto-scale, false to disable
     */
    func setAutoScale(on: Bool)
    
}
