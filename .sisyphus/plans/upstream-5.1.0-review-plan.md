# Upstream 5.1.0 Migration Review Plan

## Goal

Perform a full review of `LightweightChartsIOS` against upstream `lightweight-charts` for the migration from `4.0.0` to `5.1.0`, plus the Swift 6 migration, and record evidence-backed findings. This review is not allowed to rely on prior internal review reports as source of truth.

## Scope

- In scope: public API parity, model/options parity, JS bridge correctness, event/subscription lifecycle, pane/series/price-scale/time-scale behavior, embedded asset/version alignment, Swift 6 concurrency/error semantics, tests/examples/docs/release artifacts.
- Out of scope for this pass: user plugins and plugin feature expansion beyond validating that plugin-related upstream changes were intentionally excluded.
- Constraint: no commit, no push, no speculative claims without file evidence.

## Out of Scope

- User plugin implementation parity beyond documenting that upstream pluginization changed the integration surface.
- New wrapper feature work before the review is complete.
- Any destructive repository action, commit, or push.

## Upstream Sources

- Exact upstream baseline repo: `/Users/aovcharenko/Work/rappers/lightweight-charts`.
- Exact upstream version pin: `5.1.0`, confirmed by `/Users/aovcharenko/Work/rappers/lightweight-charts/package.json`.
- Upstream API source root: `/Users/aovcharenko/Work/rappers/lightweight-charts/src/api/`.
- Upstream docs used for delta verification: `/Users/aovcharenko/Work/rappers/lightweight-charts/website/docs/migrations/from-v4-to-v5.md`, `/Users/aovcharenko/Work/rappers/lightweight-charts/website/docs/release-notes.md`, `/Users/aovcharenko/Work/rappers/lightweight-charts/website/docs/panes.md`, `/Users/aovcharenko/Work/rappers/lightweight-charts/website/docs/time-scale.md`, `/Users/aovcharenko/Work/rappers/lightweight-charts/website/docs/price-scale.md`.

## Local Claims

- iOS wrapper code and tests live under `Sources/`, `Example/Tests/Tests.swift`, and `Example/LightweightCharts/Example/`.
- Local docs that must be treated as claims, not truth: `README.md`, `CHANGELOG.md`, `MIGRATION_V4_TO_V5.md`, `MIGRATION_TO_SWIFT6_ASYNC.md`, `CODE_REVIEW_v5.1.0.md`, `IMPLEMENTATION_PLAN_v5.1.0.md`, `PLATFORM_POLICY.md`.
- Embedded runtime: `Sources/LightweightCharts/Assets/lightweight-charts.js`.

## Verification Commands

- Use `read` for direct evidence capture of named files.
- Use `grep` for claim extraction and contradiction checks across docs, tests, and source.
- Use `glob` only to confirm upstream/local doc or source file presence.
- Use `bash` only for non-destructive verification later if build/test validation is explicitly pulled into the review pass.

## Initial Contradictions

- `CODE_REVIEW_v5.1.0.md` contains stale findings and cannot be used as primary truth source.
- Release/migration/platform docs may drift from the actual shipped source and asset state, so each claim needs source-level verification.

## Binary Acceptance Criteria

The review is only complete when all of the following are true:

1. A parity matrix exists for each reviewed surface with status `match`, `intentional-gap`, `regression-risk`, or `missing`.
2. Every non-match has evidence paths on both wrapper and upstream sides.
3. Every claimed migration delta is classified as one of: API surface, runtime behavior, Swift 6 semantics, tests/examples/docs, or release/distribution.
4. Every gap has a recommended verification method: unit test, integration test, example validation, build check, or docs fix.
5. No area is marked complete based only on existing internal markdown reports.

## Review Order

### 1. Baseline And Trust Boundaries

- Verify embedded JS asset version matches upstream `5.1.0`.
- Verify the wrapper target baseline is Swift tools `6.0`, iOS `15`, and strict concurrency is enabled.
- Verify whether existing internal review docs are still current by spot-checking at least three claims against code.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Assets/lightweight-charts.js` and confirm it identifies `v5.1.0`.
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/package.json` and confirm `"version": "5.1.0"`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Package.swift` and confirm Swift tools `6.0`, iOS `15`, and strict concurrency settings.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/CODE_REVIEW_v5.1.0.md` plus `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/CHANGELOG.md` and record at least one stale claim.

### 2. Chart API Parity Matrix

- Compare upstream `IChartApiBase` to wrapper `ChartApi` plus `LightweightCharts` forwarding and `Chart` implementation.
- Review each current upstream chart method and classify it:
  - fully wrapped
  - wrapped with narrower signature
  - intentionally excluded
  - missing / regression candidate
- Explicitly check multi-pane additions, scale access, screenshot flags, crosshair APIs, chart element access, and horizontal behavior access.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/src/api/ichart-api.ts`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Protocols/ChartApi.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/Chart.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/LightweightCharts.swift`.
  - For every upstream chart method, record one wrapper location or an explicit absence.

### 3. Series API Parity Matrix

- Compare upstream `ISeriesApi` to wrapper `SeriesApi` and `SeriesApi+Extension.swift`.
- Check data mutation signatures, read APIs, subscriptions, pane movement, pane access, price lines, ordering, last-value methods, and update semantics.
- Explicitly verify whether upstream optional parameters are preserved or narrowed in Swift.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/src/api/iseries-api.ts`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Protocols/SeriesApi.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/Series/SeriesApi+Extension.swift`.
  - `grep` `Example/Tests/Tests.swift` for each wrapped high-risk method to mark whether there is test evidence.

### 4. Pane, Time Scale, And Price Scale Parity Matrix

- Compare upstream `IPaneApi`, `ITimeScaleApi`, and `IPriceScaleApi` to wrapper protocols and implementations.
- Check pane creation/return semantics, pane inspection methods, pane-scoped price scale access, time conversion methods, size methods, and visible-range APIs.
- Check whether pane-scoped behavior is available from both chart-level and pane-level wrapper surfaces where upstream supports it.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/src/api/ipane-api.ts`.
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/src/api/itime-scale-api.ts`.
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/src/api/iprice-scale-api.ts`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Protocols/TimeScaleApi.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Protocols/PriceScaleApi.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/TimeScale.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/PriceScale.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/Chart.swift` section containing `Pane`.

### 5. Model And Options Parity

- Audit Swift option/data models for fields added or changed between upstream `4.0.0` and `5.1.0`.
- Verify coding keys, enum raw values, optionality, and JSON encoding shape against upstream option names.
- Check especially panes, attribution/logo, markers, marker price positioning, z-order, last-value data, and conflation/time-scale additions.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/lightweight-charts/website/docs/release-notes.md` sections `5.0.0` through `5.1.0`.
  - `grep` wrapper `Sources/**/*.swift` for named options from those release notes such as `maxBarSpacing`, `rightOffsetPixels`, `enableConflation`, `doNotSnapToHiddenSeriesIndices`, `ensureEdgeTickMarksVisible`, `zOrder`, `autoScale`, `base`, `tickmarksPriceFormatter`, `tickmarksPercentageFormatter`, and `attributionLogo`.
  - `read` the matching wrapper option model files for every found or missing symbol.

### 6. Bridge Script Correctness

- Review JS string generation in `Chart.swift`, `SeriesApi+Extension.swift`, `TimeScale.swift`, `PriceScale.swift`, and related bridge helpers.
- Check string escaping, optional parameter handling, `typeof` guards, return-value decoding paths, and object lifetime assumptions.
- Verify that wrapper scripts call the correct upstream runtime methods with correct arity and object context.
- QA procedure:
  - `read` each bridge implementation file named in this section.
  - For every parity-sensitive API marked `present` or `narrowed`, capture the literal JS call string and compare it against the upstream method signature from `src/api/*.ts`.
  - Record whether the gap is protocol-only, script-only, or both.

### 7. Event And Subscription Lifecycle

- Review chart and time-scale subscriptions, handler installation/removal, AsyncStream lifecycle, and delegate delivery.
- Check for retained handlers, duplicate subscriptions, missing unsubscription cleanup, and ordering assumptions during bootstrap/removal.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/Chart.swift` subscription sections.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Sources/LightweightCharts/Implementations/API/TimeScale.swift` subscription sections.
  - `grep` `Example/Tests/Tests.swift` for click, dblClick, crosshair, visible range, logical range, and size change coverage.

### 8. Swift 6 Concurrency And Error Semantics

- Review `@MainActor` boundaries, typed throws usage, continuation handling, cancellation behavior, weak/unowned references, and any `@unchecked Sendable` usage.
- Confirm bridge entry points that touch WebKit stay main-actor isolated.
- Confirm off-main work is limited to safe post-processing, not bridge calls.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Package.swift`.
  - `grep` `Sources/**/*.swift` for `@MainActor`, `async throws`, `withCheckedThrowingContinuation`, `DispatchQueue.global`, `unowned`, `weak`, and `@unchecked Sendable`.
  - `read` each bridge file that matches concurrency-sensitive patterns and record a verdict.

### 9. Tests, Examples, And Documentation

- Map wrapper tests to reviewed capabilities and note untested surface.
- Check example coverage for newly introduced or migrated upstream features.
- Verify README, migration guides, changelog, and platform policy against actual shipped surface.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Example/Tests/Tests.swift`.
  - `grep` `Example/LightweightCharts/Example/**/*.swift` for representative migrated features such as panes, series order, price scale range, markers, and conflation.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/README.md`, `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/MIGRATION_TO_SWIFT6_ASYNC.md`, `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/MIGRATION_V4_TO_V5.md`, `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/PLATFORM_POLICY.md`, and `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/CHANGELOG.md`.

### 10. Release/Distribution Readiness

- Check `Package.swift`, podspec posture, platform floor, resource embedding, and release-facing version references.
- Verify distribution claims match the stated Swift 6 migration posture.
- QA procedure:
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Package.swift`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/LightweightCharts.podspec`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/README.md`.
  - `read` `/Users/aovcharenko/Work/rappers/LightweightChartsIOS/PLATFORM_POLICY.md`.

## TDD-Oriented Execution Rule

This review is read-only unless the user later asks for fixes. If fixes are requested after review:

1. Add or extend the smallest failing test that demonstrates the exact parity gap.
2. Make the minimal bridge/model/docs change.
3. Re-run only the relevant tests first, then the broader suite if needed.
4. Keep one fix per gap unless two gaps share the same root cause.

## Atomic Commit Strategy

No commits will be created during this review. If the user later requests implementation and commits, use one commit per review theme:

1. chart/pane API parity
2. series parity
3. scale/time-scale parity
4. Swift 6 concurrency/error semantics
5. tests/examples/docs

## Execution Log

### Started Findings

#### Baseline

- Embedded JS asset reports `TradingView Lightweight Charts v5.1.0` in `Sources/LightweightCharts/Assets/lightweight-charts.js`.
- Swift package baseline is `swift-tools-version:6.0`, iOS `15`, with `StrictConcurrency` enabled in `Package.swift`.
- Existing internal review docs are not trustworthy as sole source: `CODE_REVIEW_v5.1.0.md` still claims `CHANGELOG.md` lacks a `5.1.0` entry, but `CHANGELOG.md` now contains one.

#### Initial API Parity Gaps To Validate Fully

- Chart surface appears narrower than upstream: wrapper `addPane()` returns `Void`, while upstream `addPane(preserveEmptyPane?)` returns a pane handle.
- Chart surface appears narrower than upstream: wrapper `priceScale(priceScaleId:)` does not expose upstream optional `paneIndex`.
- Time-scale surface appears narrower than upstream: wrapper does not expose `timeToIndex`, `width`, or `height`.
- Series surface appears narrower than upstream: wrapper does not currently expose `update(... historicalUpdate?)`, `data()`, `subscribeDataChanged`, `unsubscribeDataChanged`, `moveToPane`, or `getPane`.
- Pane surface appears partial versus upstream: wrapper currently lacks upstream methods such as `paneIndex()`, `getSeries()`, `getHTMLElement()`, `addSeries`, `addCustomSeries`, and primitive attach/detach methods.

#### Test Coverage Signal

- `Example/Tests/Tests.swift` contains coverage for many newly added v5 paths such as pane operations, series order, pop, last value data, visible range, and crosshair APIs.
- Current direct test search did not find coverage for the apparently missing surfaces listed above, which makes them high-priority audit targets rather than assumed intentional omissions.

## Next Execution Steps

1. Build the chart API parity matrix from `src/api/ichart-api.ts` against `Protocols/ChartApi.swift`, `Implementations/API/Chart.swift`, and `Implementations/API/LightweightCharts.swift`.
2. Build the series/time-scale/price-scale/pane parity matrices from upstream API files against wrapper protocols and implementations.
3. Spot-check bridge scripts for every non-match to separate API omission from script-level bug.
4. Expand the execution log with severity, evidence, and recommended verification per finding.

## Initial Parity Audit Snapshot

### Chart Surface

| Upstream surface | Wrapper surface | Current status | Notes |
|---|---|---|---|
| `addPane(preserveEmptyPane?) -> IPaneApi` | `addPane()` | missing parity | Wrapper submits `chart.addPane();` but does not expose preserve flag or return pane handle. |
| `priceScale(priceScaleId, paneIndex?)` | `priceScale(priceScaleId:)` | narrowed | Wrapper supports chart-level scale lookup by id only. Pane-level lookup exists separately on `PaneApi`. |
| `chartElement()` | none | intentional-gap candidate | Upstream exposes DOM element; wrapper may intentionally hide DOM/WebView internals, but this must be documented as a non-parity decision. |
| `horzBehaviour()` | none | intentional-gap candidate | Upstream exposes horizontal behavior object; no wrapper equivalent found yet. |
| `setCrosshairPosition`, `clearCrosshairPosition`, `paneSize`, `autoSizeActive`, `swapPanes`, `removePane` | present | match candidate | These are exposed in wrapper protocols/implementations and have direct test coverage. |

### Time Scale Surface

| Upstream surface | Wrapper surface | Current status | Notes |
|---|---|---|---|
| `timeToIndex(time, findNearest?)` | none | missing parity | No direct wrapper method found in `Protocols/TimeScaleApi.swift` or `Implementations/API/TimeScale.swift`. |
| `width()` | none | missing parity | No wrapper method found. |
| `height()` | none | missing parity | No wrapper method found. |
| visible range/logical range conversions, options, coordinate conversions | present | match candidate | Present in current wrapper surface; still requires script-level validation. |

### Series Surface

| Upstream surface | Wrapper surface | Current status | Notes |
|---|---|---|---|
| `update(bar, historicalUpdate?)` | `update(bar)` | narrowed | Wrapper does not expose historical update flag. |
| `data()` | none | missing parity | No full-series data read API found. |
| `subscribeDataChanged`, `unsubscribeDataChanged` | none | missing parity | No data-changed subscription surface found. |
| `moveToPane(paneIndex)` | none | missing parity | No pane migration API found on wrapper series. |
| `getPane()` | none | missing parity | No pane handle retrieval found on wrapper series. |
| `priceLines`, `seriesOrder`, `pop`, `lastValueData` | present | match candidate | Exposed and covered in current tests. |

### Pane Surface

| Upstream surface | Wrapper surface | Current status | Notes |
|---|---|---|---|
| `paneIndex()` | `index` snapshot + `currentIndex()` async | narrowed | Wrapper exposes creation-time snapshot and live lookup, but not the exact upstream sync method. |
| `getSeries()` | none | missing parity | No wrapper API found. |
| `getHTMLElement()` | none | intentional-gap candidate | DOM element access may be intentionally hidden in iOS wrapper. |
| `attachPrimitive`, `detachPrimitive` | none | out-of-scope candidate | Primitive/plugin-related surface may be intentionally excluded for this pass, but omission still needs explicit disposition. |
| `addSeries`, `addCustomSeries` | none | missing parity | No pane-scoped series factory API found. |
| `getHeight`, `setHeight`, `moveTo`, `priceScale`, `preserveEmptyPane`, `stretchFactor` | present | match candidate | Present in current pane wrapper. |

### Confidence Notes

- This snapshot is based on direct source comparison, not on prior review markdown.
- `match candidate` means the method exists in the wrapper and has not yet been fully bridge-validated.
- `intentional-gap candidate` means the omission may be deliberate for an iOS wrapper, but that decision still needs to be documented and justified.

## Reviewed Areas - Round 1

### Verified Baseline

- Upstream source root is pinned to `/Users/aovcharenko/Work/rappers/lightweight-charts`, and upstream version `5.1.0` is confirmed by `/Users/aovcharenko/Work/rappers/lightweight-charts/package.json`.
- Embedded runtime alignment is confirmed because `Sources/LightweightCharts/Assets/lightweight-charts.js` identifies itself as `TradingView Lightweight Charts v5.1.0`.
- The wrapper is genuinely on the Swift 6 migration path: `Package.swift` uses `swift-tools-version: 6.0` and enables strict concurrency.

### Confirmed API Gaps After Source Recheck

- `ChartApi.addPane()` is still a real parity gap. Upstream `IChartApiBase.addPane(preserveEmptyPane?)` returns `IPaneApi`, while wrapper `Protocols/ChartApi.swift` and forwarding `Implementations/API/LightweightCharts.swift` expose only `func addPane()` with no preserve flag and no returned pane handle.
- Chart-level price scale access is still narrower than upstream. Upstream `priceScale(priceScaleId, paneIndex?)` supports pane-specific lookup from the chart API, but wrapper `ChartApi.priceScale(priceScaleId:)` has no `paneIndex`; the wrapper instead requires pane-scoped access through `PaneApi.priceScale(priceScaleId:)`.
- `TimeScaleApi` is still missing upstream `timeToIndex(time, findNearest?)`, `width()`, and `height()` after direct inspection of `Protocols/TimeScaleApi.swift` and `Implementations/API/TimeScale.swift`.
- `SeriesApi` is still missing upstream `data()`, `subscribeDataChanged`, `unsubscribeDataChanged`, `moveToPane`, and `getPane`, and narrows `update(bar, historicalUpdate?)` to `update(bar)` only.
- `PaneApi` remains partial. The wrapper exposes size/height/preserve/stretch/current index/price-scale access, but no upstream equivalents for `getSeries()`, `getHTMLElement()`, `addSeries`, `addCustomSeries`, or primitive attach/detach methods.

### Earlier Suspicions Downgraded By Direct Evidence

- `PriceScaleApi.width()` is not missing; it exists in both `Protocols/PriceScaleApi.swift` and `Implementations/API/PriceScale.swift`.
- Upstream `ensureEdgeTickMarksVisible` is already modeled in `LightweightChartsModels/Options/Basics/PriceScaleOptions.swift`.
- Upstream price-format `base` support is already present in `LightweightChartsModels/PriceFormat.swift` and histogram options.
- Upstream localization tickmark formatters are already present in `LightweightChartsModels/Options/ChartOptions/LocalizationOptions.swift` and wired in `ChartOptions.swift`.
- Upstream `doNotSnapToHiddenSeriesIndices` is already present in `LightweightChartsModels/Options/ChartOptions/CrosshairOptions.swift`.
- Upstream conflation support is already present in `LightweightChartsModels/Options/Basics/TimeScaleOptions.swift` via `enableConflation`, `conflationThresholdFactor`, `precomputeConflationOnInit`, and `precomputeConflationPriority`.
- Upstream `addDefaultPane` is already present in `LightweightChartsModels/Options/ChartOptions/ChartOptions.swift`.
- Upstream `autoscaleInfoProvider` support is already present across series option models and `SeriesOptionsCommon.swift`.
- Upstream `MagnetOHLC` crosshair mode is already present as `CrosshairMode.magnetOHLC`.
- Upstream `attributionLogo` is already present in `LightweightChartsModels/Options/ChartOptions/LayoutOptions.swift`.

### Confirmed Option/Model Gaps After Delta Check

- Upstream `maxBarSpacing` from `5.0.0` release notes is not present in wrapper `TimeScaleOptions`.
- Upstream enhanced layout fields `colorSpace` and `colorParsers` from `5.0.0` are not present in wrapper `LayoutOptions`.
- Upstream `relativeGradient` support for area/baseline series from `5.0.0` was not found in wrapper series option models.

### Severity Notes For Next Pass

- High: chart/pane/time-scale/series API omissions that remove upstream callable behavior.
- Medium: missing option/model fields that limit parity but may not block core chart usage.
- Medium: chart-level `priceScale(..., paneIndex?)` narrowing because it matters specifically in multi-pane setups and upstream fixed related pane-index correctness in `5.0.3`.
