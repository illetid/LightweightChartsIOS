# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.1] - 2026-03-03

### Added
- **Attribution/Compliance parity**
  - Added `LayoutOptions.attributionLogo`
  - TradingView attribution link taps are routed to Safari via `WKNavigationDelegate`
- **Crosshair & time-scale parity**
  - `CrosshairMode.hidden`, `CrosshairMode.magnetOHLC`
  - `CrosshairOptions.doNotSnapToHiddenSeriesIndices`
  - `TimeScaleOptions.rightOffsetPixels`
  - `TimeScaleOptions.allowShiftVisibleRangeOnWhitespaceReplacement`
  - `TimeScaleOptions.tickMarkMaxCharacterLength`
  - `TimeScaleOptions.minimumHeight`
- **Price scale / localization / formatting parity**
  - `PriceScaleOptions.minimumWidth`
  - `PriceScaleOptions.ensureEdgeTickMarksVisible`
  - `LocalizationOptions.percentageFormatter`
  - `BuiltInPriceFormat.base`
  - Line-based series marker styling: `pointMarkersVisible`, `pointMarkersRadius`
- **Chart/series API parity**
  - `SeriesApi.priceLines(completion:)`
  - `ChartApi.panes(completion:)`
  - `ChartApi.removePane(index:)`
  - `ChartApi.swapPanes(first:second:)`
  - `ChartApi.subscribeDblClick()` / `unsubscribeDblClick()`
  - `ChartApi.setCrosshairPosition(...)` / `clearCrosshairPosition()`
  - `ChartApi.paneSize(paneIndex:completion:)`
  - `ChartApi.takeScreenshot(addTopLayer:includeCrosshair:completion:)`

### Changed
- Updated example notes to include attribution logo disablement compliance guidance.
- Updated Multiple Panes example with bottom controls for Add Pane, Remove Last Pane, and Swap 0↔1.

### Validation
- Added serialization/runtime tests for all Phase 13 parity fields and APIs in `Example/Tests/Tests.swift`.
- Verified build with `xcodebuild -workspace Example/LightweightCharts.xcworkspace -scheme LightweightCharts-Example -configuration Debug -sdk iphonesimulator build`.

## [5.0.0] - 2026-02-27

### Added
- **Plugin System**: New plugin architecture for extended chart functionality
  - `SeriesMarkersPlugin` - Explicit control over series markers with lifecycle management
  - `UpDownMarkersPlugin` - Directional price movement indicators for LineSeries and AreaSeries
  - `TextWatermarkPlugin` - Multi-line text watermarks with per-line styling
  - `ImageWatermarkPlugin` - Display images as watermarks on any pane
- `Plugin` protocol with `detach()` method for cleanup
- Factory methods on `ChartApi` for creating watermark plugins:
  - `createTextWatermarkPlugin(paneIndex:options:)`
  - `createImageWatermarkPlugin(paneIndex:imageUrl:options:)`
- Factory methods on `SeriesApi` for creating marker plugins:
  - `createMarkersPlugin(data:options:)`
  - `createUpDownMarkersPlugin(data:options:)`
- New option types:
  - `SeriesMarkersOptions` - Control visibility and auto-scaling for markers
  - `UpDownMarkersOptions` - Customize up/down marker colors and size
  - `TextWatermarkOptions` - Multi-line text with per-line styling
  - `ImageWatermarkOptions` - Image opacity and padding configuration
- `WatermarkLine` model with `lineHeight` property
- `SeriesUpDownMarker` and `MarkerSign` models

### Changed
- **Upgraded to TradingView Lightweight Charts v5.1.0** (from v4.0.0)
- Minimum iOS version unified to **13.0** (was 12.0 for CocoaPods, 10.0 for SPM)
- Internal series creation now uses `chart.addSeries(LightweightCharts.LineSeries, ...)` pattern
- Internal marker implementation uses explicit plugin reference

### Deprecated
- `ChartOptions.watermark` - Use `createTextWatermarkPlugin()` instead
- `WatermarkOptions` type - Use `TextWatermarkOptions` instead

### Removed
- None (backward compatibility maintained for all public APIs)

### Fixed
- Markers now properly persist through compatibility layer when using `setMarkers`
- Watermark configuration is now excluded from serialized chart options

### Documentation
- Added `PLUGIN_GUIDE.md` - Complete plugin system documentation
- Added `MIGRATION_V4_TO_V5.md` - Migration guide from v4 to v5
- Updated README with v5.0.0 installation instructions

## [4.0.0] - Previous Release

### Added
- Initial iOS wrapper for TradingView Lightweight Charts v4.0.0
- Support for all series types: Line, Area, Bar, Candlestick, Histogram, Baseline
- Chart options API
- Markers via `setMarkers`
- Watermark via `ChartOptions.watermark`
- Time scale manipulation
- Crosshair and click events
- Screenshot API
- Resize handling
