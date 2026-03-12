# Migration To Swift 6 Async API

This document covers the breaking migration to the Swift 6, iOS 15+, async/await-first wrapper API.

## Scope

This migration guide is for users moving from the older completion-handler-based wrapper surface to the current Swift 6 API.

Key release constraints:

- Swift 6 is required.
- iOS 15.0 or newer is required.
- Value-returning wrapper APIs are now `async throws`.
- Chart events can be consumed through `AsyncStream` properties.
- CocoaPods is not a supported distribution path for the target release.

## Breaking Changes

### Toolchain

- Update your app target to Swift 6.
- Raise your deployment target to iOS 15.0 or newer.

### Protocol Conformers

If your code provides custom mocks, adapters, or test doubles that conform to `PaneApi`
or `PanePlugin`, you must implement the new live-index requirements:

- `PaneApi.currentIndex() async throws(JavaScriptBridgeError) -> Int`
- `PanePlugin.currentPaneIndex() async throws(JavaScriptBridgeError) -> Int`

These APIs expose the current pane position after pane reorder/remove operations.

### Async Reads

Previously, JavaScript-backed reads were exposed through completion handlers.
They are now expressed as `async throws(JavaScriptBridgeError)` APIs.

Before:

```swift
chart.panes { panes in
    print("Pane count:", panes.count)
}

chart.timeScale().getVisibleRange { range in
    print(range?.from as Any)
}

series.priceFormatter().format(price: 42) { formatted in
    print(formatted as Any)
}
```

After:

```swift
Task { @MainActor in
    let panes = try await chart.panes()
    let visibleRange = try await chart.timeScale().getVisibleRange()
    let formatted = try await series.priceFormatter().format(price: 42)

    print("Pane count:", panes.count)
    print(visibleRange.from)
    print(formatted)
}
```

### Honest Failures

Read APIs no longer return fabricated fallback values when the WebKit bridge fails.
Instead, they throw `JavaScriptBridgeError`.

Common cases:

- `contextUnavailable`
- `cancelled`
- `evaluationFailed`
- `invalidResult`
- `decodingFailed`

Recommended pattern:

```swift
Task { @MainActor in
    do {
        let options = try await chart.options()
        print(options)
    } catch let error as JavaScriptBridgeError {
        print("Bridge error:", error)
    } catch {
        print("Unexpected error:", error)
    }
}
```

### Event Consumption

Chart events can still be consumed through delegate-based subscriptions, but the idiomatic Swift 6 path is now `AsyncStream`.

Before:

```swift
chart.delegate = self
chart.subscribeCrosshairMove()
```

After:

```swift
private var crosshairTask: Task<Void, Never>?

crosshairTask = Task { @MainActor [weak self] in
    guard let self else { return }

    for await event in self.chart.crosshairMoveEvents {
        self.handleCrosshairMove(event)
    }
}
```

The same pattern applies to:

- `clickEvents`
- `doubleClickEvents`
- `crosshairMoveEvents`

## API Mapping

### Chart Reads

- `chart.panes(completion:)` -> `try await chart.panes()`
- `chart.paneSize(paneIndex:completion:)` -> `try await chart.paneSize(paneIndex:)`
- `chart.options(completion:)` -> `try await chart.options()`
- `chart.autoSizeActive(completion:)` -> `try await chart.autoSizeActive()`
- `chart.takeScreenshot(completion:)` -> `try await chart.takeScreenshot()`

### Time Scale Reads

- `scrollPosition(completion:)` -> `try await scrollPosition()`
- `getVisibleRange(completion:)` -> `try await getVisibleRange()`
- `getVisibleLogicalRange(completion:)` -> `try await getVisibleLogicalRange()`
- `logicalToCoordinate(_:completion:)` -> `try await logicalToCoordinate(logical:)`
- `coordinateToLogical(_:completion:)` -> `try await coordinateToLogical(x:)`
- `timeToCoordinate(_:completion:)` -> `try await timeToCoordinate(time:)`
- `coordinateToTime(_:completion:)` -> `try await coordinateToTime(x:)`
- `options(completion:)` -> `try await options()`

### Price Scale Reads

- `options(completion:)` -> `try await options()`
- `width(completion:)` -> `try await width()`
- `getVisibleRange(completion:)` -> `try await getVisibleRange()`

### Series Reads

- `priceToCoordinate(price:completion:)` -> `try await priceToCoordinate(price:)`
- `coordinateToPrice(coordinate:completion:)` -> `try await coordinateToPrice(coordinate:)`
- `barsInLogicalRange(range:completion:)` -> `try await barsInLogicalRange(range:)`
- `options(completion:)` -> `try await options()`
- `dataByIndex(logicalIndex:mismatchDirection:completion:)` -> `try await dataByIndex(logicalIndex:mismatchDirection:)`
- `markers(completion:)` -> `try await markers()`
- `priceLines(completion:)` -> `try await priceLines()`
- `seriesType(completion:)` -> `try await seriesType()`
- `seriesOrder(completion:)` -> `try await seriesOrder()`
- `pop(count:completion:)` -> `try await pop(count:)`
- `lastValueData(globalLast:completion:)` -> `try await lastValueData(globalLast:)`

### Price Line And Formatter Reads

- `priceLine.options(completion:)` -> `try await priceLine.options()`
- `formatter.format(price:completion:)` -> `try await formatter.format(price:)`
- `formatter.formatTickmarks(prices:completion:)` -> `try await formatter.formatTickmarks(prices:)`

## Mutating Calls

Most mutating wrapper APIs remain synchronous from the caller's perspective.
Internally, they are submitted to the main-actor JavaScript bridge in call order.

That means code like this is expected to be safe:

```swift
let plugin = series.createMarkersPlugin(data: markers)
plugin.applyOptions(options: SeriesMarkersOptions(active: false))
series.setSeriesOrder(order: 2)
```

You do not need to add artificial delays between those calls.

## UI Integration Pattern

Use `Task { @MainActor in ... }` from view controllers when the result will immediately update UI state.

```swift
Task { @MainActor [weak self] in
    guard let self else { return }

    do {
        let range = try await self.chart.priceScale(priceScaleId: "right").getVisibleRange()
        self.statusLabel.text = "\(range.from) - \(range.to)"
    } catch {
        self.statusLabel.text = "Unavailable"
    }
}
```

## Examples

For an end-to-end example of async reads plus `AsyncStream` event handling, see:

- [Example/LightweightCharts/Example/AsyncAPIViewController.swift](Example/LightweightCharts/Example/AsyncAPIViewController.swift)

## Validation

The canonical validation path for this repository is the Example workspace:

```bash
cd Example
xcodebuild -workspace LightweightCharts.xcworkspace \
  -scheme LightweightCharts-Example \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  test
```
