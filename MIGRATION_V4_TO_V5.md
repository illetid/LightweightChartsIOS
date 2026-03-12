# Lightweight Charts iOS Migration Guide: v4 to v5

## Overview of Changes

Lightweight Charts v5 removes some legacy chart-level options and introduces explicit plugin APIs.

**Before (v4):**
```swift
let chart = LightweightCharts(frame: frame, options: ChartOptions(
    watermark: WatermarkOptions(text: "Demo")
))
series.setMarkers(data: markers)
```

**After (v5):**
```swift
let chart = LightweightCharts(frame: frame, options: ChartOptions())
let watermark = chart.createTextWatermarkPlugin(
    paneIndex: 0,
    options: TextWatermarkOptions(text: "Demo", color: "rgba(171, 71, 188, 0.5)")
)
let markersPlugin = series.createMarkersPlugin(data: markers, options: SeriesMarkersOptions())
```

## Platform Changes

- iOS wrapper now targets the upstream v5 plugin model.
- Watermarks are pane plugins, not chart options.
- Marker behavior is plugin-backed for full control.

## Watermark Migration

`ChartOptions.watermark` remains available as a compatibility path, but it is deprecated.
Prefer plugin-based configuration:

- `createTextWatermarkPlugin`
- `createImageWatermarkPlugin`

## New Plugin APIs

New plugin-first APIs provide explicit lifecycle control (`applyOptions`, `detach`) and better parity with upstream JS.

## Series Markers Plugin

Use `createMarkersPlugin(data:options:)` for marker management.
Legacy `setMarkers` remains available for compatibility.

## Up/Down Markers Plugin

Use `createUpDownMarkersPlugin(data:options:)` on supported series (line/area).
Use `UpDownMarkersOptions` to style positive/negative markers.

## Text Watermark Plugin

Use `createTextWatermarkPlugin(paneIndex:options:)` with `TextWatermarkOptions` and one or more `WatermarkLine` entries.

## Image Watermark Plugin

Use `createImageWatermarkPlugin(paneIndex:imageUrl:options:)` with `ImageWatermarkOptions`.

## Breaking Changes

- `ChartOptions.watermark` is deprecated in favor of plugins.
- Direct chart-level watermark encoding is excluded from the v5 chart options JSON payload.
- Plugin lifecycle (`detach`) must be respected to avoid stale references.

## Testing Your Migration

1. Verify chart creation and series rendering still work.
2. Verify marker behavior using both legacy `setMarkers` and plugin APIs.
3. Verify watermark rendering with plugin APIs.
4. Run unit and integration tests.

Relevant APIs and option types:

- `createMarkersPlugin`
- `createUpDownMarkersPlugin`
- `createTextWatermarkPlugin`
- `createImageWatermarkPlugin`
- `setMarkers`
- `ChartOptions.watermark`
- `TextWatermarkOptions`
- `ImageWatermarkOptions`
- `SeriesMarkersOptions`
- `UpDownMarkersOptions`
