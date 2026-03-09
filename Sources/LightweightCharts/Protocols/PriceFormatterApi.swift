import Foundation

/** Interface to be implemented by the object in order to be used as a price formatter */
public protocol PriceFormatterApi: AnyObject {
    
    /**
     * Formatting function
     * - Parameter price: original price to be formatted
     * - Parameter completion: formatted price
     */
    func format(price: BarPrice, completion: @escaping (String?) -> Void)

    /**
     * Formats tickmark values using the formatter's tickmark-specific behavior.
     * - Parameter prices: original prices to be formatted
     * - Parameter completion: formatted tickmark labels
     */
    func formatTickmarks(prices: [BarPrice], completion: @escaping ([String]?) -> Void)
    
}
