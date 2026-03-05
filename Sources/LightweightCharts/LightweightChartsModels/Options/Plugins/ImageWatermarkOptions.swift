import Foundation

/**
 Options for creating an image watermark primitive on a pane.

 Image watermarks are created via `ChartApi.createImageWatermark(paneIndex:options:)`
 and return a handle that can be used to update or remove the watermark.
 */
public struct ImageWatermarkOptions {

    /**
     Transparency (alpha) value for the watermark image.

     Valid range is 0.0 (fully transparent) to 1.0 (fully opaque).
     */
    public var alpha: Double

    /**
     Padding around the watermark image in pixels.
     */
    public var padding: Int

    /**
     Maximum width of the watermark image in pixels.

     When `nil`, no maximum width constraint is applied.
     */
    public var maxWidth: Double?

    /**
     Maximum height of the watermark image in pixels.

     When `nil`, no maximum height constraint is applied.
     */
    public var maxHeight: Double?

    public init(
        alpha: Double = 1.0,
        padding: Int = 0,
        maxWidth: Double? = nil,
        maxHeight: Double? = nil
    ) {
        self.alpha = alpha
        self.padding = padding
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
}

// MARK: - Codable
extension ImageWatermarkOptions: Codable {

    enum CodingKeys: String, CodingKey {
        case alpha
        case padding
        case maxWidth
        case maxHeight
    }

}

// MARK: - Encodable helper
extension ImageWatermarkOptions {
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
