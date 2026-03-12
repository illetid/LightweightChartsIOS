import Foundation


public enum SeriesType: String, Decodable, Sendable {
    case line = "Line"
    case area = "Area"
    case candlestick = "Candlestick"
    case bar = "Bar"
    case histogram = "Histogram"
}
