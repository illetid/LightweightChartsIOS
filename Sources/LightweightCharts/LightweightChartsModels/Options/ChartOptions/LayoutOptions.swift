import Foundation

/**
 Structure describing layout options
 */
public struct LayoutOptions: Codable, Sendable {
    
    public var background: SurfaceColor?
    
    /**
     Color of a text on the scales
     */
    public var textColor: ChartColor?
    
    /**
     Font size of a text on the scales in pixels
     */
    public var fontSize: Double?
    
    /**
     Font family of a text on the scales
     */
    public var fontFamily: String?

    /**
     Whether to show the TradingView attribution logo.
     If not set, upstream default behavior is preserved.
     */
    public var attributionLogo: Bool?
    
    public init(background: SurfaceColor? = nil,
                textColor: ChartColor? = nil,
                fontSize: Double? = nil,
                fontFamily: String? = nil,
                attributionLogo: Bool? = nil) {
        self.background = background
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.attributionLogo = attributionLogo
    }
}
