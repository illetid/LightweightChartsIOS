# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [5.1.0] - 2026-03-11

### Added

#### Series Markers
- Price-positioned markers with `atPriceTop`, `atPriceBottom`, `atPriceMiddle` positions
- Optional `price: Double?` property on `SeriesMarker` for price-level positioning
- `SeriesMarkerZOrder` enum for controlling marker z-order (`normal`, `noOverlap`)

#### Series API
- `seriesOrder()` - get current series order
- `setSeriesOrder(_:)` - set series order
- `pop(count:)` - remove last N data points from series
- `lastValueData(_:)` - get series last value data with optional price range
- `setDataValidationEnabled(_:)` - enable/disable Swift-side time/order validation for `setData` and `update`
- `isDataValidationEnabled` - inspect current validation state for a series

#### Price Scale API
- `setVisibleRange(_:)` - set visible price range
- `getVisibleRange()` - get current visible price range
- `setAutoScale(_:)` - enable/disable auto-scaling

#### Pane API
- `getHeight()` - get pane height
- `setHeight(_:)` - set pane height
- `moveTo(_:)` - move pane to new index
- `getStretchFactor()` - get pane stretch factor
- `setStretchFactor(_:)` - set pane stretch factor
- `priceScale(priceScaleId:)` - get price scale by ID
- `currentIndex()` - get the live pane index after pane reorder/removal

#### Pane Plugin API
- `currentPaneIndex()` - get the live pane index for pane-scoped plugins after pane reorder/removal

#### Data Conflation
- `ConflationPriority` enum (`background`, `userVisible`, `userBlocking`)
- TimeScale conflation properties: `conflationWidthThreshold`, `conflationMaxTimeWeight`, `conflationPriority`

### Changed

- **BREAKING**: Migrated to Swift 6 with async/await
- **BREAKING**: Minimum deployment target is now iOS 15.0+
- **BREAKING**: CocoaPods is no longer supported for this release
- **BREAKING**: External conformers of `PaneApi` and `PanePlugin` must implement `currentIndex()` / `currentPaneIndex()`
- All bridge classes marked `@MainActor` for thread safety
- All async methods now use `throws(JavaScriptBridgeError)` for typed error handling
- `AsyncStream` properties for event subscriptions in `ChartApi`
- Plugin creation scripts submitted in call order for immediate usability
- Swift-side series data validation for `setData`/`update` is available as an opt-in compatibility guard via `setDataValidationEnabled(true)`

### Migration Notes

This release requires Swift 6 and iOS 15+. The API has been migrated from completion handlers to async/await:

**Before (v4/v5.0):**
```swift
series.price { price in
    // handle price
}
```

**After (v5.1.0):**
```swift
let price = try await series.price()
```

See [MIGRATION_TO_SWIFT6_ASYNC.md](MIGRATION_TO_SWIFT6_ASYNC.md) for detailed migration guidance.
