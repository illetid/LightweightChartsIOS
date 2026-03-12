# Swift 6 Async/Await Migration Checklist

**Repository:** LightweightChartsIOS
**Migration Type:** Breaking change
**Target State:** Swift 6, iOS 15+, async/await-first API, strict concurrency
**Validation Authority:** Example workspace build and tests
**Out of Scope:** CocoaPods support, dual-surface compatibility layer

## Decisions Locked In

- This migration is a clean break, not a gradual compatibility rollout.
- Completion-handler APIs do not need to remain in the public surface.
- CocoaPods is no longer supported and should not drive design or validation decisions.
- The Example workspace is the authoritative validation path, not SwiftPM alone.

## Success Criteria

- The Example workspace builds in Swift 6 language mode.
- The Example workspace targets iOS 15.0 or newer.
- The JS bridge is main-actor-safe and preserves operation ordering.
- Public async APIs surface real failures with `throws` instead of fabricated defaults.
- Strict concurrency warnings are either fixed or consciously isolated with narrow justification.
- Async behavior is covered by real tests, not only editor diagnostics or successful compilation.

---

## Phase 0: Migration Contract

### Goal

Freeze the architectural rules before changing more code.

### Checklist

- [x] Remove the assumption that completion-handler APIs must remain for backwards compatibility.
- [x] Remove gradual-migration guidance from planning docs and release notes drafts.
- [x] State explicitly that Swift 6 and iOS 15 are required for the next major release.
- [x] State explicitly that CocoaPods is unsupported for this release.
- [x] Treat the Example workspace as the canonical build and test target for migration sign-off.

### Exit Criteria

- The plan, README, release notes draft, and migration docs all describe the same release model.

### Risk

Low. This phase is mostly decision alignment, but it prevents wasted implementation work.

---

## Phase 1: Toolchain and Runtime Baseline

### Goal

Make the actual shipping build path compile with the intended Swift and deployment settings.

### Why This Is First

The current Example workspace still builds as Swift 5 with iOS 13 settings. Any migration validated only through SwiftPM is incomplete.

### Checklist

- [x] Update the Example Xcode project to Swift 6 language mode.
- [x] Ensure `Strict Concurrency Checking` build setting is explicitly set to `Complete` across all targets.
- [x] Raise the Example app, framework, and test targets to iOS 15.0+.
- [x] Remove or clearly deprecate unsupported CocoaPods packaging artifacts from release planning.
- [x] Decide whether `LightweightCharts.podspec` is deleted, left in place but unsupported, or replaced with an explicit unsupported note in docs.
- [x] Keep `Package.swift` aligned with the Xcode project so the repo does not advertise conflicting platform or toolchain requirements.
- [x] Re-run `xcodebuild -workspace Example/LightweightCharts.xcworkspace -scheme LightweightCharts-Example -configuration Debug -sdk iphonesimulator build` and confirm the effective build is Swift 6 and iOS 15.

### Exit Criteria

- The Example workspace, not just SwiftPM, builds with Swift 6 and iOS 15+.

### Risk

Blocker. Nothing after this phase is trustworthy until the real build path is aligned.

---

## Phase 2: Bridge Execution Model and Ordering Correctness

### Goal

Fix the most dangerous runtime regressions before expanding the API migration.

### Why This Is High Risk

Several fire-and-forget bridge calls were changed from immediate script submission into unstructured `Task` dispatch. That changes ordering and can return wrapper objects before the corresponding JavaScript object exists.

### Required Design Rules

- `WKWebView` interaction must be main-actor-bound.
- JS evaluation should preserve call order for a single chart or web view.
- Fire-and-forget APIs should still submit work deterministically; they should not silently race through unrelated tasks.
- Async wrappers must model the existing runtime correctly before they expand the surface.

### Checklist

- [x] Choose one bridge model and document it: `@MainActor` WebView-backed evaluator, not a free-floating actor that implies detached parallelism.
- [x] Remove unstructured `Task { try? await ... }` wrappers from synchronous mutation and factory methods that rely on immediate JS object creation.
- [x] Audit all methods that create JS-backed wrappers and ensure the JS object exists before the Swift wrapper is returned or used.
- [x] Audit all methods that mutate chart or series state and ensure call ordering remains deterministic.
- [x] Keep the screenshot path safe for WebKit bridging, but document exactly which part is offloaded and why.
- [x] Do not use `withThrowingTaskGroup` or parallel fan-out for per-index WebView evaluations unless ordering and executor safety are proven.

### Hotspots To Fix First

- [x] `SeriesApi.priceFormatter()`
- [x] `SeriesApi.priceScale()`
- [x] `SeriesApi.createPriceLine(options:)`
- [x] `SeriesApi.setData(...)`
- [x] `SeriesApi.update(...)`
- [x] Pane mutation methods in `Chart.swift`
- [x] Any plugin factory that returns a JS-backed object immediately after script submission

### Exit Criteria

- Wrapper creation and mutation methods behave deterministically under sequential use.
- No critical bridge path relies on unstructured `Task { try? await ... }` to preserve semantics.

### Risk

Blocker. This is the main runtime-correctness risk in the current branch.

---

## Phase 3: Public API Surface Conversion

### Goal

Convert the public API to async/await cleanly for the breaking release.

### Design Rules

- Async-returning APIs should be the only public value-returning access pattern unless there is a strong reason otherwise.
- Since this is a breaking release, deprecated completion-handler overloads are not required.
- Synchronous APIs should stay synchronous only if they do not need an asynchronous result from WebKit.

### Checklist

- [x] Remove completion-handler requirements from `JavaScriptEvaluator`.
- [x] Remove completion-handler requirements from `ChartApi`.
- [x] Remove completion-handler requirements from `PaneApi`.
- [x] Remove completion-handler requirements from `SeriesApi`.
- [x] Remove completion-handler requirements from `PriceScaleApi`.
- [x] Remove completion-handler requirements from `TimeScaleApi`.
- [x] Remove completion-handler requirements from `PriceLineApi`.
- [x] Remove completion-handler requirements from `PriceFormatterApi`.
- [x] Update concrete implementations to match the simplified protocol surface.
- [x] Update the Example app to use async/await end to end for value-returning operations.
- [x] Update any test mocks or protocol conformers in the Example test target.

### API Correctness Rules

- [x] Value-returning JS calls should become `async throws` Swift APIs.
- [x] Event listener callbacks (e.g., `subscribeClick`) should be exposed as `AsyncStream` properties for idiomatic Swift Concurrency usage.
- [x] Fire-and-forget JS calls should remain synchronous from the caller's perspective only if ordering is preserved internally.
- [x] Do not expose fabricated placeholder results on failure.

### Exit Criteria

- The public API surface reflects a real breaking Swift 6 release instead of a hybrid compatibility release.

### Risk

High. This is source-breaking work and must follow Phase 2 so behavior does not regress behind the new API surface.

---

## Phase 4: Error Semantics and Result Integrity

### Goal

Make async APIs fail honestly.

### Why This Matters

Several current async methods return empty options, zero ranges, or sentinel values when the JS context is missing. That hides bridge failures and makes debugging much harder.

### Checklist

- [x] Remove nil-coalescing fallback values from async APIs where bridge evaluation is required.
- [x] Throw a meaningful error when the JS evaluator or context is unavailable.
- [x] Throw when WebKit returns a result of the wrong type instead of substituting defaults.
- [x] Introduce a focused error type for bridge failures and invalid JS result decoding.
- [x] Utilize Swift 6 Typed Throws (`throws(YourErrorType)`) for bridge APIs instead of generic `throws`.
- [x] Add `try Task.checkCancellation()` checks in asynchronous bridge work to respect caller cancellation.
- [x] Normalize decoding behavior between primitive and JSON-decoded paths.
- [x] Document which APIs can throw due to JS evaluation, decoding failure, or unavailable chart state.

### Hotspots To Fix First

- [x] `PriceLine.options()`
- [x] `PriceScale.options()`
- [x] `PriceScale.getVisibleRange()`
- [x] `TimeScale.getVisibleRange()`
- [x] `TimeScale.coordinateToTime(x:)`
- [x] `TimeScale.options()`

### Exit Criteria

- Async API consumers can trust that success means a real bridge result and failure means an actual error.

### Risk

High. Silent fallback values create false positives in both app code and tests.

---

## Phase 5: Concurrency Isolation and Shared State

### Goal

Resolve actual data-race concerns instead of only adding `Sendable` annotations.

### Why This Comes After Behavior Fixes

The branch has started adding `Sendable`, but the meaningful shared mutable state is still unmanaged. Isolation should follow the final bridge model, not precede it.

### Checklist

- [x] Mark UI-bound entry points and bridge owners with `@MainActor` where appropriate.
- [x] Decide whether `LightweightCharts`, `Chart`, `TimeScale`, and related bridge classes should be `@MainActor` or have narrower isolated methods.
- [ ] Use `nonisolated` on purely computational properties or methods to prevent unnecessary actor hopping from background threads.
- [x] Replace mutable per-series state with a deliberate isolation model if it crosses executors.
- [x] Revisit the need for `AsyncJavaScriptEvaluator`; remove it if `WebView` already provides the canonical async interface.
- [x] Add `Sendable` only where the type is truly safe to send across concurrency domains.
- [ ] Migrate deeply nested configuration classes to pure value types (structs/enums) to implicitly conform to `Sendable`.
- [x] Revisit every `@unchecked Sendable` conformance and justify it narrowly.
- [x] Add `@MainActor` to delegate protocols that are expected to update UI.
- [x] Audit message delivery from `WKScriptMessageHandler` into delegates and ensure the executor contract is explicit.

### Specific Review Items

- [x] `SeriesObject` mutable state: `_lastDataTime`, `_validationEnabled`
- [x] `ChartDelegate` delivery thread or actor
- [x] `TimeScaleDelegate` delivery thread or actor
- [x] `MessageHandler` executor assumptions
- [x] `ChartColor`, formatter wrappers, and option types currently marked `@unchecked Sendable`

### Exit Criteria

- Strict concurrency diagnostics are resolved through actor isolation, main-actor isolation, or narrowly justified unchecked sendability.

### Risk

Medium-High. This is where the Swift 6 migration becomes real rather than cosmetic.

---

## Phase 6: Example App Migration

### Goal

Use the Example app as both documentation and integration coverage.

### Checklist

- [x] Update examples that read values from the chart to use `Task` and `await` explicitly from view-controller code.
- [x] Update examples that listen to events to use `AsyncStream` subscriptions.
- [x] Ensure UI updates from async results happen on the main actor.
- [x] Add at least one example for each major migrated value-returning API family:
- [x] Chart APIs
- [x] Time scale APIs
- [x] Price scale APIs
- [x] Series APIs
- [x] Price line and formatter APIs
- [x] Remove references in examples or comments that imply legacy completion handlers remain the preferred surface.

### Exit Criteria

- The Example app demonstrates the actual intended public API for the major release.

### Risk

Medium. This is integration work, but it will expose API ergonomics and actor-boundary mistakes.

---

## Phase 7: Test Coverage and Validation

### Goal

Add real automated signal for the migration.

### Current Gap

The current test target executes 0 tests, so build success provides almost no behavioral confidence.

### Checklist

- [x] Add unit tests for the async JS evaluation bridge.
- [x] Add tests that verify wrapper creation is usable immediately after factory methods return.
- [x] Add tests that verify sequential mutation ordering for `setData`, `update`, and similar bridge operations.
- [x] Add tests for async result decoding of primitives versus JSON objects.
- [x] Add tests for failure propagation when script evaluation fails.
- [x] Add tests for delegate delivery semantics if delegate isolation changes.
- [x] Add tests for the reviewed v5 API areas that still lack coverage.
- [x] `seriesOrder`
- [x] `pop`
- [x] `lastValueData`
- [x] `setVisibleRange`
- [x] `getVisibleRange`
- [x] `setAutoScale`
- [x] pane APIs
- [x] Run `xcodebuild -workspace Example/LightweightCharts.xcworkspace -scheme LightweightCharts-Example -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' test`.

### Exit Criteria

- The test target executes meaningful tests and covers the migration's main runtime risks.

### Risk

High. Without this phase, the migration remains largely unverified.

---

## Phase 8: Release Hardening

### Goal

Prepare the major release once the migration is technically complete.

### Checklist

- [x] Update `README.md` to reflect Swift 6 and iOS 15 requirements.
- [x] Add a focused migration guide from the previous API surface to async/await.
- [x] Document that CocoaPods is unsupported.
- [ ] Update `CHANGELOG.md` with breaking-change notes.
- [ ] Bump the library version for a major release.
- [x] Document removed APIs, actor assumptions, and error semantics.

### Exit Criteria

- Release notes and docs match the shipped API and supported installation story.

### Risk

Medium. This phase is not technically complex, but it is user-facing and must be accurate.

---

## Recommended Execution Order

1. Phase 0: Migration Contract
2. Phase 1: Toolchain and Runtime Baseline
3. Phase 2: Bridge Execution Model and Ordering Correctness
4. Phase 3: Public API Surface Conversion
5. Phase 4: Error Semantics and Result Integrity
6. Phase 5: Concurrency Isolation and Shared State
7. Phase 6: Example App Migration
8. Phase 7: Test Coverage and Validation
9. Phase 8: Release Hardening

## Sign-Off Checklist

- [x] Example workspace builds in Swift 6.
- [x] Example workspace targets iOS 15+.
- [x] No critical bridge path relies on unstructured `Task` dispatch for correctness.
- [x] Async APIs throw instead of returning fabricated defaults.
- [x] Public API surface no longer carries completion-handler compatibility baggage.
- [ ] Strict concurrency issues are resolved or narrowly justified.
- [x] Tests execute real coverage for async bridge behavior.
- [x] Docs describe a breaking Swift 6 release with no CocoaPods support.
