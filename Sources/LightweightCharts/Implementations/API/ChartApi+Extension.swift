import Foundation

public extension ChartApi where Self: ChartObject {

    // MARK: - Plugin Factories

    /// Creates a new text watermark plugin attached to this chart.
    ///
    /// The plugin provides explicit control over the text watermark, including setting/getting options
    /// and updating text and visibility at runtime. Use the plugin's `detach()` method to remove it
    /// when no longer needed.
    ///
    /// - Parameters:
    ///   - paneIndex: The index of the pane to attach the watermark to (0 is the main pane).
    ///   - options: Initial options for the text watermark.
    /// - Returns: A new `TextWatermarkPlugin<Self>` instance attached to this chart.
    func createTextWatermarkPlugin(
        paneIndex: Int = 0,
        options: TextWatermarkOptions
    ) -> TextWatermarkPlugin<Self> {
        return TextWatermarkPlugin(
            chart: self,
            paneIndex: paneIndex,
            context: context,
            options: options
        )
    }

    /// Creates a new image watermark plugin attached to this chart.
    ///
    /// The plugin provides explicit control over the image watermark, including applying options
    /// and updating the image URL at runtime. Use the plugin's `detach()` method to remove it
    /// when no longer needed.
    ///
    /// - Parameters:
    ///   - paneIndex: The index of the pane to attach the watermark to (0 is the main pane).
    ///   - imageUrl: The URL of the image to use as a watermark.
    ///   - options: Initial options for the image watermark.
    /// - Returns: A new `ImageWatermarkPlugin<Self>` instance attached to this chart.
    func createImageWatermarkPlugin(
        paneIndex: Int = 0,
        imageUrl: String,
        options: ImageWatermarkOptions = ImageWatermarkOptions()
    ) -> ImageWatermarkPlugin<Self> {
        return ImageWatermarkPlugin(
            chart: self,
            paneIndex: paneIndex,
            imageUrl: imageUrl,
            context: context,
            options: options
        )
    }

}
