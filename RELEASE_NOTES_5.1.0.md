# LightweightChartsIOS v5.1.0 Release Notes

**Release Date:** 2026-03-05
**Embedded JS:** lightweight-charts v5.1.0 (unchanged from v5.0.1)

This release adds Swift bindings for 13 JS features shipped in upstream v5.0.3–v5.1.0. No JS asset rebuild is needed — all changes are Swift-side.

---

## New Features

### Series Marker Price Positioning
Place markers at exact Y-axis price levels instead of bar-relative positions.

- New `SeriesMarkerPosition` cases: `atPriceTop`, `atPriceBottom`, `atPriceMiddle`
- New `price: Double?` property on `SeriesMarker` (required for price-positioned markers)
- *Upstream: v5.0.4, PR #1826*

### Series Order Control
Control the rendering order of series within a pane.

- `seriesOrder(completion:)` — query current order
- `setSeriesOrder(order:)` — set rendering order
- *Upstream: v5.0.6, PR #1868*

### Price Scale Visible Range & Auto Scale
Programmatic control over the price scale range.

- `setVisibleRange(from:to:)` — set visible price range
- `getVisibleRange(completion:)` — query visible price range
- `setAutoScale(on:)` — enable/disable auto-scaling
- *Upstream: v5.0.7, PR #1856*

### Series Markers `zOrder`
Control marker rendering order relative to series.

- `SeriesMarkerZOrder` enum: `top`, `aboveSeries`, `normal`
- `zOrder` property on `SeriesMarkersOptions`
- *Upstream: v5.0.7, PR #1876*

### Pane API Enhancements
Extended pane control for multi-pane charts.

- `getHeight(completion:)` / `setHeight(height:)`
- `moveTo(paneIndex:)`
- `setPreserveEmptyPane(preserve:)` / `preserveEmptyPane(completion:)`
- `getStretchFactor(completion:)` / `setStretchFactor(stretchFactor:)`
- `priceScale(priceScaleId:)` on `PaneApi`
- New `addDefaultPane: Bool?` chart option
- *Upstream: v5.0.8, PR #1894*

### `pop(count:completion:)` on SeriesApi
Remove data points from the end of a series.

- *Upstream: v5.0.9, PR #1949*

### `lastValueData(globalLast:completion:)` on SeriesApi
Retrieve last value data including price and color.

- New `LastValueDataResult` model
- *Upstream: v5.0.9, PR #1956*

### Data Conflation
Performance optimization for large datasets.

- `enableConflation`, `conflationThresholdFactor`, `precomputeConflationOnInit`, `precomputeConflationPriority` on `TimeScaleOptions`
- New `ConflationPriority` enum: `background`, `userVisible`, `userBlocking`
- *Upstream: v5.1.0, PR #1945*

---

## New Example ViewControllers

| Example | Feature |
|---------|---------|
| Price-Positioned Markers | Markers at exact price levels |
| Series Order | Toggle rendering order of overlapping series |
| Price Scale Range | Manual price range control with auto-scale |
| Data Conflation | Toggle conflation on 15K-point dataset |
| Pane Sizing | Stretch factor and height control for panes |

---

## Migration

No breaking changes. All new APIs are additive. Existing code continues to work without modification.
