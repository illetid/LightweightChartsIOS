# Lightweight Charts iOS — v5.1.0 Feature Parity Implementation Plan

## Overview

| Item | Value |
|------|-------|
| **Current iOS wrapper** | v5.0.1 (podspec 5.0.0) |
| **Embedded JS** | `lightweight-charts` **v5.1.0** (already latest) |
| **Target upstream** | v5.1.0 — **no JS asset rebuild needed** |
| **Gap** | 13 JS features lack Swift bindings |
| **Proposed wrapper version** | **5.1.0** |

The JS artifact is already up-to-date. The work is **100% Swift-side**: adding missing model types, protocol methods, and implementation bridging code to expose features shipped in upstream v5.0.3 – v5.1.0.

---

## Changed APIs / Models

### 1. Series Marker Price Positioning (upstream v5.0.4, PR #1826)

**JS types (TypeScript)**

```typescript
type SeriesMarkerPricePosition = 'atPriceTop' | 'atPriceBottom' | 'atPriceMiddle';
type SeriesMarkerBarPosition  = 'aboveBar' | 'belowBar' | 'inBar';
type SeriesMarkerPosition     = SeriesMarkerBarPosition | SeriesMarkerPricePosition;

interface SeriesMarkerPrice<T> {
    position: SeriesMarkerPricePosition;
    price: number;     // required for price-positioned markers
}
```

**Swift changes required** in `Sources/LightweightCharts/LightweightChartsModels/SeriesMarker/SeriesMarker.swift`:

| What | Change |
|------|--------|
| `SeriesMarkerPosition` enum | Add `case atPriceTop`, `case atPriceBottom`, `case atPriceMiddle` |
| `SeriesMarker` struct | Add `public var price: Double?` (required when position is an `atPrice*` variant) |

---

### 2. Series Order (upstream v5.0.6, PR #1868)

**JS types**

```typescript
seriesOrder(): number;
setSeriesOrder(order: number): void;
```

**Swift changes required:**

| File | Change |
|------|--------|
| `Protocols/SeriesApi.swift` | Add `func seriesOrder(completion: @escaping (Int?) -> Void)` |
| Same | Add `func setSeriesOrder(order: Int)` |
| Series implementation (`SeriesObject.swift` or extension) | `let script = "\(jsName).seriesOrder();"` → cast `result as? NSNumber` → `.intValue` |
| Same | `let script = "\(jsName).setSeriesOrder(\(order));"` → `evaluateScript` |

---

### 3. Price Scale Visible Range & Auto Scale (upstream v5.0.7, PR #1856)

**JS types**

```typescript
interface IPriceScaleApi {
    setVisibleRange(from: number, to: number): void;
    getVisibleRange(): IRange<number> | null;  // { from: number, to: number }
    setAutoScale(on: boolean): void;
}
```

**Swift changes required:**

| File | Change |
|------|--------|
| `Protocols/PriceScaleApi.swift` | Add `func setVisibleRange(from: Double, to: Double)` |
| Same | Add `func getVisibleRange(completion: @escaping (FromToRange<Double>?) -> Void)` |
| Same | Add `func setAutoScale(on: Bool)` |
| PriceScale implementation | `"\(jsName).setVisibleRange(\(from), \(to));"` |
| Same | `"\(jsName).getVisibleRange();"` → `decodedResult` |
| Same | `"\(jsName).setAutoScale(\(on ? "true" : "false"));"` |

---

### 4. Series Markers `zOrder` (upstream v5.0.7, PR #1876)

**JS types**

```typescript
type SeriesMarkerZOrder = 'top' | 'aboveSeries' | 'normal';

interface SeriesMarkersOptions {
    autoScale: boolean;
    zOrder: SeriesMarkerZOrder;
}
```

**Swift changes required:**

| File | Change |
|------|--------|
| New enum or add to `SeriesMarkersOptions.swift` | Add `public enum SeriesMarkerZOrder: String, Codable { case top, aboveSeries, normal }` |
| `SeriesMarkersOptions` struct | Add `public var zOrder: SeriesMarkerZOrder?` |
| Update `init` and `CodingKeys` | Include `zOrder` |

---

### 5. Pane API Enhancements (upstream v5.0.8, PR #1894)

**JS types (IPaneApi)**

```typescript
interface IPaneApi<HorzScaleItem> {
    getHeight(): number;
    setHeight(height: number): void;
    moveTo(paneIndex: number): void;
    paneIndex(): number;
    getSeries(): ISeriesApi<...>[];
    setPreserveEmptyPane(preserve: boolean): void;
    preserveEmptyPane(): boolean;
    getStretchFactor(): number;
    setStretchFactor(stretchFactor: number): void;
    priceScale(priceScaleId: string): IPriceScaleApi;
    // addSeries, addCustomSeries also available
}
```

**Swift changes required:**

| File | Change |
|------|--------|
| `Protocols/ChartApi.swift` — `PaneApi` protocol | Expand with 8 new methods (see below) |
| Pane implementation class (in `Implementations/API/`) | Implement each via JS bridge calls |

New `PaneApi` protocol members:

```swift
func getHeight(completion: @escaping (Double?) -> Void)
func setHeight(height: Double)
func moveTo(paneIndex: Int)
func setPreserveEmptyPane(preserve: Bool)
func preserveEmptyPane(completion: @escaping (Bool?) -> Void)
func getStretchFactor(completion: @escaping (Double?) -> Void)
func setStretchFactor(stretchFactor: Double)
func priceScale(priceScaleId: String) -> PriceScaleApi
```

Each maps directly to `\(chartJSName).panes()[\(index)].<method>(...)` calls.

**`addDefaultPane` chart option:**

| File | Change |
|------|--------|
| `ChartOptions.swift` | Add `public var addDefaultPane: Bool?` |
| `JSChartOptions` inner struct | Mirror the property |
| `init(...)` and `CodingKeys` | Include it |

---

### 6. `pop()` on Series API (upstream v5.0.9, PR #1949)

**JS type**

```typescript
pop(count?: number): TData[];
```

**Swift changes required:**

| File | Change |
|------|--------|
| `Protocols/SeriesApi.swift` | Add `func pop(count: Int, completion: @escaping ([TickValue]?) -> Void)` |
| Series implementation | `"\(jsName).pop(\(count));"` → `decodedResult` |

> Note: The return type in JS is an array of the series' data type. The Swift side should decode to the associated `TickValue` type.

---

### 7. `lastValueData()` on Series API (upstream v5.0.9, PR #1956)

**JS type**

```typescript
interface LastValueDataResultNoData { noData: true }
interface LastValueDataResultWithData { noData: false; price: number; color: string }
type LastValueDataResult = LastValueDataResultNoData | LastValueDataResultWithData;

lastValueData(globalLast: boolean): LastValueDataResult;
```

**Swift changes required:**

| File | Change |
|------|--------|
| New file or inline in existing models | Add `LastValueDataResult` struct |
| `Protocols/SeriesApi.swift` | Add `func lastValueData(globalLast: Bool, completion: @escaping (LastValueDataResult?) -> Void)` |
| Series implementation | `"JSON.stringify(\(jsName).lastValueData(\(globalLast ? "true" : "false")));"` → `decodedResult` |

Model:

```swift
public struct LastValueDataResult: Codable {
    public var noData: Bool
    public var price: Double?
    public var color: String?
}
```

---

### 8. Data Conflation Options (upstream v5.1.0, PR #1945)

**JS types (on `HorzScaleOptions` = `TimeScaleOptions` in Swift)**

```typescript
enableConflation: boolean;                       // default: false
conflationThresholdFactor?: number;              // default: 1.0
precomputeConflationOnInit: boolean;             // default: false
precomputeConflationPriority: 'background' | 'user-visible' | 'user-blocking';
```

**Swift changes required:**

| File | Change |
|------|--------|
| `TimeScaleOptions.swift` | Add 4 new properties |
| `CodingKeys` enum | Add 4 new keys |
| `init(...)` | Add 4 new parameters |

Properties to add:

```swift
public var enableConflation: Bool?
public var conflationThresholdFactor: Double?
public var precomputeConflationOnInit: Bool?
public var precomputeConflationPriority: ConflationPriority?
```

New enum:

```swift
public enum ConflationPriority: String, Codable {
    case background
    case userVisible = "user-visible"
    case userBlocking = "user-blocking"
}
```

---

## Example App Additions

These new features are "worthy items" that should be demonstrated:

| # | Proposed ViewController | Feature Showcased |
|---|-------------------------|-------------------|
| 1 | **PricePositionedMarkersViewController** | `atPriceTop` / `atPriceBottom` / `atPriceMiddle` marker positions with `price` field |
| 2 | **SeriesOrderViewController** | `seriesOrder()` / `setSeriesOrder()` — show two overlapping series with user-togglable order |
| 3 | **PriceScaleRangeViewController** | `setVisibleRange` / `getVisibleRange` / `setAutoScale` — manual price range control |
| 4 | **DataConflationViewController** | `enableConflation` with a large dataset (10K+ points), toggle conflation on/off, adjust `conflationThresholdFactor` |
| 5 | **PaneSizingViewController** | `setStretchFactor` / `setHeight` / `getHeight` on panes — interactive pane resizing |

---

## Step-by-Step Implementation Checklist

### Phase 1: Model & Option Changes (no protocol/impl changes)

- [x] **1.1** `SeriesMarker.swift` — Add `atPriceTop`, `atPriceBottom`, `atPriceMiddle` to `SeriesMarkerPosition` enum; add `price: Double?` to `SeriesMarker`
- [x] **1.2** `SeriesMarkersOptions.swift` — Add `SeriesMarkerZOrder` enum and `zOrder` property
- [x] **1.3** `TimeScaleOptions.swift` — Add `ConflationPriority` enum and 4 conflation properties (`enableConflation`, `conflationThresholdFactor`, `precomputeConflationOnInit`, `precomputeConflationPriority`); update `init`, `CodingKeys`, and `optionsScript`
- [x] **1.4** `ChartOptions.swift` — Add `addDefaultPane: Bool?` property; update `init`, `CodingKeys`, and `JSChartOptions`
- [x] **1.5** Create `LastValueDataResult` model (new file or inline) with `noData: Bool`, `price: Double?`, `color: String?`

### Phase 2: Protocol Changes

- [x] **2.1** `Protocols/SeriesApi.swift` — Add `seriesOrder(completion:)`, `setSeriesOrder(order:)`, `pop(count:completion:)`, `lastValueData(globalLast:completion:)`
- [x] **2.2** `Protocols/PriceScaleApi.swift` — Add `setVisibleRange(from:to:)`, `getVisibleRange(completion:)`, `setAutoScale(on:)`
- [x] **2.3** `Protocols/ChartApi.swift` — Expand `PaneApi` protocol with `getHeight(completion:)`, `setHeight(height:)`, `moveTo(paneIndex:)`, `setPreserveEmptyPane(preserve:)`, `preserveEmptyPane(completion:)`, `getStretchFactor(completion:)`, `setStretchFactor(stretchFactor:)`, `priceScale(priceScaleId:)`

### Phase 3: Implementation (JS Bridge)

- [x] **3.1** Series implementation — Implement `seriesOrder`, `setSeriesOrder`, `pop`, `lastValueData` using `evaluateScript`/`decodedResult` patterns
- [x] **3.2** PriceScale implementation — Implement `setVisibleRange`, `getVisibleRange`, `setAutoScale`
- [x] **3.3** Pane implementation — Implement all new `PaneApi` methods. JS bridge pattern: `\(chartJSName).panes()[\(index)].<method>(...)`

### Phase 4: Version Bumps

- [x] **4.1** `LightweightCharts.podspec` — Bump `s.version` from `'5.0.0'` to `'5.1.0'`
- [x] **4.2** `README.md` — Update version references, add new features section
- [x] **4.3** `CHANGELOG.md` — Add `[5.1.0]` section with all changes listed below

### Phase 5: Example App

- [x] **5.1** Add `PricePositionedMarkersViewController.swift`
- [x] **5.2** Add `SeriesOrderViewController.swift`
- [x] **5.3** Add `PriceScaleRangeViewController.swift`
- [x] **5.4** Add `DataConflationViewController.swift`
- [x] **5.5** Add `PaneSizingViewController.swift`
- [x] **5.6** Register new VCs in `TableViewController.swift`
- [x] **5.7** Add new VCs to the Xcode project file

### Phase 6: Documentation & Release

- [x] **6.1** Create `RELEASE_NOTES_5.1.0.md`
- [x] **6.2** Update `CHANGELOG.md` with `[5.1.0]` entry
- [x] **6.3** Run tests: `xcodebuild -workspace Example/LightweightCharts.xcworkspace -scheme LightweightCharts-Example -configuration Debug -sdk iphonesimulator build`

---

## CHANGELOG Entry (for `[5.1.0]`)

```markdown
## [5.1.0] - YYYY-MM-DD

### Added
- **Series Marker Price Positioning**: New `atPriceTop`, `atPriceBottom`, `atPriceMiddle`
  positions on `SeriesMarkerPosition` and `price` field on `SeriesMarker` for exact Y-axis
  marker placement (upstream v5.0.4, PR #1826)
- **Series Order Control**: `seriesOrder(completion:)` and `setSeriesOrder(order:)` on
  `SeriesApi` to control rendering order of series within a pane (upstream v5.0.6, PR #1868)
- **Price Scale Visible Range**: `setVisibleRange(from:to:)`, `getVisibleRange(completion:)`,
  and `setAutoScale(on:)` on `PriceScaleApi` for programmatic price range control
  (upstream v5.0.7, PR #1856)
- **Series Markers `zOrder`**: `SeriesMarkerZOrder` enum (`top`, `aboveSeries`, `normal`) and
  `zOrder` property on `SeriesMarkersOptions` (upstream v5.0.7, PR #1876)
- **Pane API Enhancements**: `getHeight`, `setHeight`, `moveTo`, `setPreserveEmptyPane`,
  `preserveEmptyPane`, `getStretchFactor`, `setStretchFactor`, `priceScale(priceScaleId:)`
  on `PaneApi` (upstream v5.0.8, PR #1894)
- **`addDefaultPane` chart option**: Control whether the chart creates an initial pane
  (upstream v5.0.8, PR #1894)
- **`pop(count:completion:)` on SeriesApi**: Remove data points from end of series
  (upstream v5.0.9, PR #1949)
- **`lastValueData(globalLast:completion:)` on SeriesApi**: Retrieve last value data
  including price and color (upstream v5.0.9, PR #1956)
- **Data Conflation**: `enableConflation`, `conflationThresholdFactor`,
  `precomputeConflationOnInit`, `precomputeConflationPriority` on `TimeScaleOptions`
  for performance optimization with large datasets (upstream v5.1.0, PR #1945)
- **New Example VCs**: PricePositionedMarkers, SeriesOrder, PriceScaleRange,
  DataConflation, PaneSizing

### Changed
- Bumped podspec version to 5.1.0
```

---

## Potential Gotchas

1. **Price-positioned markers are a TypeScript union type** — In JS, `SeriesMarker` is a discriminated union: if `position` is `atPriceTop|atPriceBottom|atPriceMiddle`, then `price` is required. Swift can't enforce this at the type level with a simple struct. Consider a doc comment warning or a `precondition` in the setter.

2. **`pop()` return type is generic** — It returns `TData[]` which is the series-specific data type. The Swift `SeriesApi` uses associated types (`TickValue`). The implementation must decode the JSON response to the correct associated type, which may require a generic `decodedResult` call.

3. **Pane API JS bridging** — The current `Pane` class accesses panes via `\(chartJSName).panes()[\(index)]`. If a pane is removed or reordered, the stored index becomes stale. The implementation should either re-query the index or cache the JS pane reference as a variable name.

4. **`lastValueData` synchronous in JS, async in Swift** — The JS method is synchronous but the WKWebView bridge is always async. The Swift completion handler pattern used elsewhere handles this correctly.

5. **`ConflationPriority` raw value** — The enum cases `userVisible` and `userBlocking` need explicit raw values `"user-visible"` and `"user-blocking"` to match the JS string literals (hyphenated).

6. **`addDefaultPane`** — This option only matters at chart creation time. It cannot be toggled later. Worth adding a doc comment noting this.

7. **`SeriesMarkerZOrder` default** — The JS default is `'normal'`. Since the Swift property is `Optional`, `nil` will correctly fall back to the JS default.
