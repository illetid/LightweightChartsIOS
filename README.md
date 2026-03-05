# iOS LightweightCharts

[![Version](https://img.shields.io/cocoapods/v/LightweightCharts.svg?style=flat)](https://cocoapods.org/pods/LightweightCharts)
[![License](https://img.shields.io/cocoapods/l/LightweightCharts.svg?style=flat)](https://cocoapods.org/pods/LightweightCharts)
[![Platform](https://img.shields.io/cocoapods/p/LightweightCharts.svg?style=flat)](https://cocoapods.org/pods/LightweightCharts)

The iOS LightweightCharts is an iOS wrapper of the [TradingView Lightweight Charts](https://github.com/tradingview/lightweight-charts) library (v5.1.0 embedded).

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

- iOS 13.0+ (CocoaPods and Swift Package Manager)
- Xcode 12.0+
- Swift 5.0+

## Installation

### CocoaPods

LightweightCharts is available through [CocoaPods](https://cocoapods.org). To install it, add the following line to your Podfile:

```ruby
pod 'LightweightCharts', '~> 5.0.0'
```

### Swift Package Manager

LightweightCharts is also available through [Swift Package Manager](https://swift.org/package-manager/). Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tradingview/LightweightChartsIOS.git", from: "5.0.0")
]
```

Or in Xcode: File > Add Package Dependencies > Enter the repository URL.

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

## Migration from v4

Most existing code works without changes. Key changes:

- Minimum iOS version is now **13.0** for both CocoaPods and Swift Package Manager (was 12.0 for CocoaPods, 10.0 for SPM)
- Embedded Lightweight Charts upgraded from v4.0.0 to v5.1.0
- `ChartOptions.watermark` is deprecated - use `createTextWatermarkPlugin()` instead
- New explicit plugin APIs for markers and watermarks
- `LayoutOptions.attributionLogo` is supported for explicit attribution logo visibility control
- Attribution logo links to TradingView are opened in Safari (external browser)
- New pane APIs: `panes(completion:)`, `removePane(index:)`, `swapPanes(first:second:)`
- New parity APIs: `subscribeDblClick`, `setCrosshairPosition`, `clearCrosshairPosition`, `paneSize`, `SeriesApi.priceLines(completion:)`, and screenshot flags (`addTopLayer`, `includeCrosshair`)

## Panes API

```swift
// Query existing panes
chart.panes { panes in
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

See [MIGRATION_V4_TO_V5.md](MIGRATION_V4_TO_V5.md) for detailed migration guidance.

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this software except in compliance with the License. You may obtain a copy of the License at LICENSE file. Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

This software incorporates several parts of tslib (https://github.com/Microsoft/tslib, (c) Microsoft Corporation) that are covered by the Apache License, Version 2.0.

This license requires specifying TradingView as the product creator. You shall add the "attribution notice" from the NOTICE file and a link to https://www.tradingview.com/ to the page of your website or mobile application that is available to your users. As thanks for creating this product, we'd be grateful if you add it in a prominent place.
