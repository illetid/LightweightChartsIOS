# Plugin Guide

This guide explains the plugin architecture in LightweightChartsIOS and shows how to create and use plugins.

## Overview

Plugins are attachable objects that extend chart functionality. They can be explicitly created, managed, and detached when no longer needed. The plugin system provides:

- **Consistent API** - All plugins conform to the `Plugin` protocol with a `detach()` method
- **Type safety** - Generic constraints ensure plugins are attached to compatible chart elements
- **Lifecycle management** - Explicit creation and removal of plugin functionality
- **Optional runtime updates** - Plugins can support `PluginWithOptions` for dynamic configuration

## Plugin Hierarchy

```
Plugin (base protocol)
├── SeriesPlugin (attached to a series)
│   └── SeriesPluginAdapter (base class)
│       ├── SeriesMarkersPlugin
│       └── UpDownMarkersPlugin
└── PanePlugin (attached to a chart pane)
    └── PanePluginAdapter (base class)
        ├── TextWatermarkPlugin
        └── ImageWatermarkPlugin
```

## Protocols

### `Plugin`

The base protocol for all plugins. All plugins must be detachable:

```swift
public protocol Plugin: AnyObject {
    /// Detaches (removes) the plugin from the chart.
    /// After calling this method, the plugin is removed and should no longer be used.
    func detach()
}
```

### `PluginWithOptions`

Protocol for plugins that support runtime option updates:

```swift
public protocol PluginWithOptions: Plugin {
    associatedtype Options

    /// Applies new options to the plugin.
    /// Any subset of options can be specified; unspecified options retain current values.
    func applyOptions(options: Options)
}
```

### `SeriesPlugin`

Protocol for plugins attached to a specific series:

```swift
public protocol SeriesPlugin: Plugin {
    associatedtype Series: SeriesApi & SeriesObject

    /// The series this plugin is attached to (weak reference)
    var series: Series? { get }
}
```

### `PanePlugin`

Protocol for plugins attached to a specific chart pane:

```swift
public protocol PanePlugin: Plugin {
    /// The index of the pane this plugin is attached to
    var paneIndex: Int { get }
}
```

## Adapter Classes

Adapter classes provide shared functionality for plugins and handle JavaScript bridge communication.

### `SeriesPluginAdapter<Series>`

Base class for series plugins. Provides:

- JavaScript variable naming strategy
- Script evaluation helpers
- Weak series reference to avoid retain cycles
- Detach behavior

```swift
open class SeriesPluginAdapter<Series>: SeriesPlugin
where Series: SeriesApi & SeriesObject {

    public weak var series: Series?
    public let jsName: String
    private(set) public var isDetached: Bool = false

    public init(series: Series) { ... }
    public func detach() { ... }

    // Helper methods
    func evaluateScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil)
    func evaluate<T: Decodable>(script: String, resultType: T.Type, completion: @escaping (Result<T, Error>) -> Void)
    func decodedResult<T: Decodable>(forScript script: String, completion: @escaping (T?) -> Void)
}
```

### `PanePluginAdapter<Chart>`

Base class for pane plugins. Provides:

- JavaScript variable naming strategy
- Script evaluation helpers
- Pane access via `paneExpression()`
- Detach behavior

```swift
open class PanePluginAdapter<Chart>: PanePlugin
where Chart: JavaScriptObject {

    public let paneIndex: Int
    public let jsName: String
    private(set) public var isDetached: Bool = false

    public init(chart: Chart, paneIndex: Int, context: JavaScriptEvaluator) { ... }
    public func detach() { ... }

    // Helper methods
    func paneExpression() -> String  // Returns JavaScript expression for accessing the pane
    func evaluateScript(...)
    func evaluate<T: Decodable>(...)
    func decodedResult<T: Decodable>(...)
}
```

## Built-in Plugins

### Series Markers Plugin

Displays markers on a series at specific data points:

```swift
let series = chart.addLineSeries(options: nil)

let markers: [SeriesMarker] = [
    SeriesMarker(time: .unix(1000), position: .aboveBar, shape: .arrowDown, color: "#ff0000"),
    SeriesMarker(time: .unix(2000), position: .belowBar, shape: .arrowUp, color: "#00ff00")
]

let plugin = series.createMarkersPlugin(
    data: markers,
    options: SeriesMarkersOptions(
        active: true,
        autoScale: true
    )
)

// Update markers
plugin.setMarkers(newMarkers)

// Get current markers
plugin.getMarkers { markers in
    print("Current markers: \(markers)")
}

// Apply new options
plugin.applyOptions(options: SeriesMarkersOptions(active: false))

// Remove when done
plugin.detach()
```

### Up-Down Markers Plugin

Displays directional indicators for price movements on Line or Area series:

```swift
let series = chart.addLineSeries(options: nil)

let markers: [SeriesUpDownMarker] = [
    SeriesUpDownMarker(time: .unix(1000), value: 100.5, sign: .positive),
    SeriesUpDownMarker(time: .unix(2000), value: 98.2, sign: .negative)
]

let plugin = series.createUpDownMarkersPlugin(
    data: markers,
    options: UpDownMarkersOptions(
        positiveColor: "#00ff00",
        negativeColor: "#ff0000"
    )
)

// Update data
plugin.setData(newMarkers)
// or
plugin.update(singleMarker)

// Remove when done
plugin.detach()
```

### Text Watermark Plugin

Displays a text watermark on a chart pane:

```swift
let options = TextWatermarkOptions(
    lines: [
        WatermarkLine(text: "Confidential", color: "rgba(255, 0, 0, 0.3)", fontSize: 48)
    ],
    horizontalAlignment: .center,
    verticalAlignment: .center
)

let plugin = chart.createTextWatermarkPlugin(
    paneIndex: 0,
    options: options
)

// Update text
plugin.setText("Draft")

// Toggle visibility
plugin.setVisible(false)

// Apply new options
plugin.applyOptions(options: TextWatermarkOptions(visible: true))

// Remove when done
plugin.detach()
```

### Image Watermark Plugin

Displays an image watermark on a chart pane:

```swift
let options = ImageWatermarkOptions(
    alpha: 0.5,
    padding: 10,
    maxWidth: 200,
    maxHeight: 200
)

let plugin = chart.createImageWatermarkPlugin(
    paneIndex: 0,
    imageUrl: "https://example.com/watermark.png",
    options: options
)

// Update transparency
plugin.setAlpha(0.3)

// Replace the image
plugin.updateImage(url: "https://example.com/new-watermark.png")

// Remove when done
plugin.detach()
```

## Creating Custom Plugins

### Creating a Series Plugin

To create a custom series plugin:

1. Subclass `SeriesPluginAdapter<Series>` where `Series` conforms to both `SeriesApi` and `SeriesObject`
2. Add `PluginWithOptions` conformance if you want runtime option updates
3. Initialize by calling `super.init(series:)` and creating the JavaScript plugin
4. Implement `detach()` to clean up JavaScript resources
5. Add plugin-specific methods

Example:

```swift
public class MySeriesPlugin<Series>: SeriesPluginAdapter<Series>, PluginWithOptions
where Series: SeriesApi & SeriesObject {

    public typealias Options = MySeriesPluginOptions

    private(set) public var options: MySeriesPluginOptions

    public init(series: Series, options: MySeriesPluginOptions = MySeriesPluginOptions()) {
        self.options = options
        super.init(series: series)

        // Create the plugin in JavaScript
        let script = "var \(jsName) = LightweightCharts.createMyPlugin(\(series.jsName), \(options.jsonString()));"
        evaluateScript(script, completion: nil)
    }

    public override func detach() {
        guard !isDetached else { return }

        // Detach the JavaScript plugin
        let script = "\(jsName).detach();"
        evaluateScript(script, completion: nil)

        super.detach()
    }

    public func applyOptions(options: MySeriesPluginOptions) {
        guard !isDetached else { return }

        self.options = options
        let script = "\(jsName).applyOptions(\(options.jsonString()));"
        evaluateScript(script, completion: nil)
    }

    // Add your plugin-specific methods here
}
```

Add a factory method in `SeriesApi+Extension.swift`:

```swift
public extension SeriesApi where Self: SeriesObject {

    func createMySeriesPlugin(
        options: MySeriesPluginOptions = MySeriesPluginOptions()
    ) -> MySeriesPlugin<Self> {
        return MySeriesPlugin(series: self, options: options)
    }
}
```

### Creating a Pane Plugin

To create a custom pane plugin:

1. Subclass `PanePluginAdapter<Chart>` where `Chart` conforms to `JavaScriptObject`
2. Add `PluginWithOptions` conformance if you want runtime option updates
3. Initialize by calling `super.init(chart:paneIndex:context:)` and creating the JavaScript plugin
4. Implement `detach()` to clean up JavaScript resources
5. Add plugin-specific methods

Example:

```swift
public class MyPanePlugin<Chart>: PanePluginAdapter<Chart>, PluginWithOptions
where Chart: JavaScriptObject {

    public typealias Options = MyPanePluginOptions

    private(set) public var options: MyPanePluginOptions

    public init(
        chart: Chart,
        paneIndex: Int,
        context: JavaScriptEvaluator,
        options: MyPanePluginOptions = MyPanePluginOptions()
    ) {
        self.options = options
        super.init(chart: chart, paneIndex: paneIndex, context: context)

        // Create the plugin in JavaScript
        let script = """
        (function() {
            var pane = \(paneExpression());
            if (!pane) {
                throw new Error('Invalid pane index: \(paneIndex). Pane does not exist.');
            }
            pane.createMyPlugin(\(options.jsonString()));
        })();
        """
        evaluateScript(script, completion: nil)
    }

    public override func detach() {
        guard !isDetached else { return }

        // Clean up the JavaScript plugin
        // (implementation depends on the JavaScript API)

        super.detach()
    }

    public func applyOptions(options: MyPanePluginOptions) {
        guard !isDetached else { return }

        self.options = options
        // Apply options to JavaScript
    }

    // Add your plugin-specific methods here
}
```

Add a factory method in `ChartApi+Extension.swift`:

```swift
public extension ChartApi where Self: ChartObject {

    func createMyPanePlugin(
        paneIndex: Int = 0,
        options: MyPanePluginOptions = MyPanePluginOptions()
    ) -> MyPanePlugin<Self> {
        return MyPanePlugin(
            chart: self,
            paneIndex: paneIndex,
            context: context,
            options: options
        )
    }
}
```

## Testing Plugins

### Basic Plugin Test Pattern

```swift
final class MyPluginTests: XCTestCase {

    var charts: LightweightCharts!
    var errorCatcher: JSErrorCatcher!
    var loadExpectation: XCTestExpectation!

    override func setUp() {
        super.setUp()

        loadExpectation = expectation(description: "Chart loads")

        charts = LightweightCharts(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        errorCatcher = JSErrorCatcher()

        charts.errorDelegate = errorCatcher
        charts.loadDelegate = self

        wait(for: [loadExpectation], timeout: 5.0)
    }

    override func tearDown() {
        charts = nil
        errorCatcher = nil
        super.tearDown()
    }

    func testPluginCreation() {
        errorCatcher.clear()

        let plugin = charts.createMyPanePlugin(paneIndex: 0, options: MyPanePluginOptions())

        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin.paneIndex, 0)

        waitForAsyncOperations()
        errorCatcher.assertNoErrors()
    }

    func testPluginDetach() {
        let plugin = charts.createMyPanePlugin(paneIndex: 0, options: MyPanePluginOptions())

        plugin.detach()

        XCTAssertTrue(plugin.isDetached)
    }

    func testPluginApplyOptions() {
        let plugin = charts.createMyPanePlugin(paneIndex: 0, options: MyPanePluginOptions())

        let newOptions = MyPanePluginOptions(visible: false)
        plugin.applyOptions(options: newOptions)

        waitForAsyncOperations()
        // Verify options were applied
    }
}

extension MyPluginTests: LightweightChartsDelegate {

    func lightweightChartsDidLoad(_ lightweightCharts: LightweightCharts) {
        loadExpectation?.fulfill()
    }

    func lightweightCharts(_ lightweightCharts: LightweightCharts, didFailLoadWithError error: Error) {
        XCTFail("Chart failed to load: \(error.localizedDescription)")
        loadExpectation?.fulfill()
    }
}
```

## Best Practices

1. **Always call `super.detach()`** when overriding `detach()` in custom plugins

2. **Guard against detached state** - Check `isDetached` before performing operations

3. **Use weak references** for series/chart references to avoid retain cycles

4. **Validate pane indices** - Provide clear error messages when invalid indices are used

5. **Implement `PluginWithOptions`** when runtime configuration changes are needed

6. **Generate unique JavaScript variable names** - Use `String.uniqueString` for uniqueness

7. **Clean up JavaScript resources** - Ensure JavaScript plugin objects are properly detached

8. **Document the lifecycle** - Make it clear when plugins should be detached

## Migration from v4 to v5

The plugin system in v5 provides explicit control that wasn't available in v4:

- **v4**: Markers were managed implicitly via `series.setMarkers()`
- **v5**: Use `series.createMarkersPlugin()` for explicit lifecycle management

See `MIGRATION_V4_TO_V5.md` for details on migrating existing code.
