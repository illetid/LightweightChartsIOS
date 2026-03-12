# iOS LightweightCharts

The iOS LightweightCharts is an iOS wrapper of the [TradingView Lightweight Charts](https://github.com/tradingview/lightweight-charts) library (v5.1.0 embedded).

## Example

The Example workspace is the canonical validation path for this repository.

To run it locally:

```bash
cd Example
pod install
open LightweightCharts.xcworkspace
```

## Requirements

- iOS 15.0+
- Xcode 16+
- Swift 6+

This repository is migrating as a breaking Swift 6 release. Completion-handler compatibility is not a release goal for the next major version.

## Installation

### Swift Package Manager

LightweightCharts is available through [Swift Package Manager](https://swift.org/package-manager/). Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tradingview/LightweightChartsIOS.git", from: "5.1.0")
]
```

Or in Xcode: File > Add Package Dependencies > Enter the repository URL.

### CocoaPods Status

CocoaPods is unsupported for the next major Swift 6 release.

The checked-in [LightweightCharts.podspec](LightweightCharts.podspec) is retained only so the local Example workspace can continue to resolve the library during migration work. It should not be treated as a supported distribution path for release planning.

## Usage

```swift
import LightweightCharts
```

Create instance of LightweightCharts, which is a subclass of UIView, and add it to your view.

```swift
var chart: LightweightCharts!

// ...
chart = LightweightCharts()
view.addSubview(chart)
// ... setup layout
```

Add any series to the chart and store a reference to it.

```swift
var series: BarSeries!

// ...
series = chart.addBarSeries(options: nil)
```

Add data to the series.

```swift
let data = [
    BarData(time: .string("2018-10-19"), open: 180.34, high: 180.99, low: 178.57, close: 179.85),
    BarData(time: .string("2018-10-22"), open: 180.82, high: 181.40, low: 177.56, close: 178.75),
    BarData(time: .string("2018-10-23"), open: 175.77, high: 179.49, low: 175.44, close: 178.53),
    BarData(time: .string("2018-10-24"), open: 178.58, high: 182.37, low: 176.31, close: 176.97),
    BarData(time: .string("2018-10-25"), open: 177.52, high: 180.50, low: 176.83, close: 179.07)
]

// ...
series.setData(data: data)
```

## Plugin System

Version 5.0 introduces a new plugin system for extended chart functionality:

- **Series Markers Plugin** - Explicit control over series markers with lifecycle management
- **Up/Down Markers Plugin** - Directional price movement indicators (LineSeries and AreaSeries)
- **Text Watermark Plugin** - Multi-line text watermarks with per-line styling
- **Image Watermark Plugin** - Display images as watermarks on any pane

### Text Watermark Example

```swift
// Create a text watermark plugin
let watermark = chart.createTextWatermarkPlugin(
    paneIndex: 0,
    options: TextWatermarkOptions(
        text: "Loading data...",
        color: "rgba(171, 71, 188, 0.5)",
        fontSize: 24
    )
)

// Update or detach when done
watermark.applyOptions(options: TextWatermarkOptions(visible: false))
watermark.detach()
```

### Series Markers Example

```swift
let markers = [
    SeriesMarker(time: .string("2018-10-19"), position: .aboveBar, shape: .arrowDown, color: "#ff0000"),
    SeriesMarker(time: .string("2018-10-22"), position: .belowBar, shape: .arrowUp, color: "#00ff00")
]

let plugin = series.createMarkersPlugin(
    data: markers,
    options: SeriesMarkersOptions(
        active: true,
        autoScale: true
    )
)

// Update markers later
plugin.setMarkers(newMarkers)
plugin.detach()
```

See [PLUGIN_GUIDE.md](PLUGIN_GUIDE.md) for complete plugin documentation.

## Migration Status

The repository is in an async/await-first migration for the next major release. Expect source-breaking changes while the public API is converted away from completion handlers and aligned with Swift 6 strict concurrency.

See [MIGRATION_TO_SWIFT6_ASYNC.md](MIGRATION_TO_SWIFT6_ASYNC.md) for the focused API migration guide.

Current migration constraints:

- Swift 6 and iOS 15 are required for the target release.
- The Example workspace is the authoritative build and test target.
- CocoaPods is not a supported installation path for the target release.
- Public async APIs throw real bridge errors. Expect underlying WebKit evaluation failures or `JavaScriptBridgeError` when the JS context is unavailable, the returned value has the wrong shape, or decoding fails.

Plugin factory semantics during the migration:

- Plugin creation scripts and immediate follow-up plugin mutations are submitted on the same main-actor bridge in call order.
- That means sequential code such as `let plugin = series.createMarkersPlugin(...); plugin.applyOptions(...)` is expected to be safe without extra waiting.

## Migration from v4

The existing v5 wrapper changes remain relevant for users migrating older code. Key changes from v4:

- Minimum iOS version is now **15.0** for the Swift 6 release
- Embedded Lightweight Charts upgraded from v4.0.0 to v5.1.0
- `ChartOptions.watermark` is deprecated - use `createTextWatermarkPlugin()` instead
- New explicit plugin APIs for markers and watermarks
- `LayoutOptions.attributionLogo` is supported for explicit attribution logo visibility control
- Attribution logo links to TradingView are opened in Safari (external browser)
- New pane APIs: `await chart.panes()`, `removePane(index:)`, `swapPanes(first:second:)`
- New parity APIs: `subscribeDblClick`, `setCrosshairPosition`, `clearCrosshairPosition`, `await chart.paneSize(paneIndex:)`, `await series.priceLines()`, and async screenshot flags (`addTopLayer`, `includeCrosshair`)

## Panes API

```swift
// Query existing panes
Task {
    let panes = try await chart.panes()
    print("Pane count:", panes.count)
}

// Add/remove/reorder panes
chart.addPane()
chart.removePane(index: 2)
chart.swapPanes(first: 0, second: 1)
```

The Example app's Multiple Panes screen now includes bottom controls for Add Pane, Remove Last Pane, and Swap 0↔1.

## Attribution & Compliance

```swift
var layout = LayoutOptions()
layout.attributionLogo = false

let options = ChartOptions(layout: layout)
let chart = LightweightCharts(options: options)
```

When users tap the built-in TradingView attribution link, the wrapper routes that navigation to Safari.
If you disable `attributionLogo`, ensure your app still satisfies NOTICE and licensing obligations.

See [MIGRATION_TO_SWIFT6_ASYNC.md](MIGRATION_TO_SWIFT6_ASYNC.md) for detailed migration guidance for the Swift 6 async release.

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this software except in compliance with the License. You may obtain a copy of the License at LICENSE file. Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

This software incorporates several parts of [tslib](https://github.com/Microsoft/tslib), (c) Microsoft Corporation, that are covered by the Apache License, Version 2.0.

This license requires specifying TradingView as the product creator. You shall add the "attribution notice" from the NOTICE file and a link to [tradingview.com](https://www.tradingview.com/) to the page of your website or mobile application that is available to your users. As thanks for creating this product, we'd be grateful if you add it in a prominent place.
