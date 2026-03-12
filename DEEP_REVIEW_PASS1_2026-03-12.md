# Deep Review Pass 1 (2026-03-12)

## Baselines

- Wrapper repo: `/Users/aovcharenko/Work/rappers/LightweightChartsIOS`
- Upstream baseline: `upstream/master` at merge-base `5394d40fead4fbade89ee1c7e37aca4138b3186c`
- Reviewed HEAD: `3ed2176609fcfb5031dd983b88ea353277846f1b`
- JS reference repo: `/Users/aovcharenko/Work/rappers/lightweight-charts`
- JS reference commit: `b1570d9eca3c3a6763bdff6defa92b7978907386`
- Git bucket state at review start:
  - `C` (committed): present (`BASE..HEAD` includes 8 commits)
  - `S` (staged): none
  - `W` (unstaged): none
  - `U` (untracked): none

## Scope Snapshot

- Diff size (`BASE..HEAD`): 160 files changed, `+11817 / -1061`
- High-churn directories: `Sources/LightweightCharts/*` and `Example/LightweightCharts/Example/*`
- Public surface touched:
  - `Sources/LightweightCharts/Protocols/ChartApi.swift`
  - `Sources/LightweightCharts/Protocols/SeriesApi.swift`
  - `Sources/LightweightCharts/Protocols/TimeScaleApi.swift`
  - `Sources/LightweightCharts/Protocols/PriceScaleApi.swift`

## High-Signal Findings

### [F-001] Medium (7/15) | Domain: Panes API | Parity: Divergent

- Swift evidence:
  - `Sources/LightweightCharts/Implementations/API/Chart.swift:388` creates pane handle via `Pane(chartJSName:..., context:..., closureStore:...)`
  - `Sources/LightweightCharts/Implementations/API/Chart.swift:715` sets `self.index = 0` in that initializer
- Contract evidence:
  - `Sources/LightweightCharts/Protocols/ChartApi.swift:10` says `PaneApi.index` is "The pane index at the time this handle was created"
- Expected JS behavior:
  - JS pane handles are index-aware (`src/api/pane-api.ts:56` uses live model index) and not forced to zero
- Impact:
  - For charts with existing panes, `addPane()` returns a `PaneApi` whose `index` snapshot is wrong when the new pane is not index `0`
  - Live pane operations still resolve via JS handle and `currentIndex()`, so blast radius is narrower than a full pane-management failure
- Closure criteria:
  - Initialize the newly-created `Pane` with its real creation index (or remove snapshot guarantee from protocol/docs)

### [F-002] Low-Medium (5/15) | Domain: Data Validation | Parity: Partial

- Swift evidence:
  - Validator introduced: `Sources/LightweightCharts/LightweightChartsModels/Validation/SeriesDataValidator.swift`
  - Shared instance declared but not invoked anywhere: `SeriesDataValidator.swift:177`
  - Validation state fields exist but are not used in data paths: `Sources/LightweightCharts/Implementations/API/Series/SeriesObject.swift:24-27`
- JS evidence:
  - JS validates ordering/type before update paths (`src/api/series-api.ts:150-162`)
- Impact:
  - Review expectation may be that Swift-side pre-validation is active, but runtime behavior currently relies on JS-side checks only
  - This is mostly dormant scaffolding risk (expectation and observability), not a proven runtime parity break by itself
- Closure criteria:
  - Either wire Swift validator into `setData/update` flows or explicitly document that Swift validator is currently non-operative scaffolding

### [F-003] Medium (8/15) | Domain: API Semantics | Parity: Partial

- Swift evidence:
  - `Sources/LightweightCharts/Protocols/ChartApi.swift:305-309` allows `priceScaleId: String?`
  - `Sources/LightweightCharts/Implementations/API/Chart.swift:499-507` maps `nil` to `""`
- JS evidence:
  - JS API expects explicit `string` id (`src/api/ichart-api.ts:249`)
- Impact:
  - `nil` maps to empty string, but JS path resolves through `findPriceScale(...)`; this can fail at runtime for invalid ids
  - This path is pre-existing behavior (not introduced by this branch), but remains a real contract risk
- Closure criteria:
  - Decide/document whether empty-string fallback is intentional compatibility behavior
  - Add a regression test for `priceScale(priceScaleId: nil, paneIndex: ...)`

## Parity Matrix (Pass 1)

| Domain | Status | Evidence |
|---|---|---|
| Chart lifecycle and screenshot flags | Full | Swift `Chart.swift` vs JS `src/api/chart-api.ts:299-321` |
| Time scale API (async surface + `timeToIndex`) | Full | Swift `TimeScaleApi.swift` + `TimeScale.swift` vs JS `src/api/time-scale-api.ts` |
| Price scale options/range/autoscale | Partial | Methods present; optional-id fallback needs explicit contract |
| Series update/data changed/historical update | Full | Swift `SeriesApi.swift` + `SeriesApi+Extension.swift` vs JS `src/api/series-api.ts:158-163` |
| Panes add/remove/swap and pane handle semantics | Partial | `PaneApi.index` snapshot mismatch risk on `addPane()` |
| Marker/plugin migration path | Full | Swift plugin adapters and wrappers align with JS plugin model |
| Swift-side data validation | Partial | Validator shipped but not wired into update/set paths |
| Error observability on sync bridge writes | Partial | `submitScript` reports via delegate path; direct call sites often lack local failure semantics |

## Test and Build Evidence

- Build command:
  - `xcodebuild -workspace Example/LightweightCharts.xcworkspace -scheme LightweightCharts-Example -configuration Debug -sdk iphonesimulator build`
  - Result: `** BUILD SUCCEEDED **`
- Test command:
  - `xcodebuild -workspace Example/LightweightCharts.xcworkspace -scheme LightweightCharts-Example -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' test`
  - Result: `Executed 52 tests, with 0 failures (0 unexpected)` and `** TEST SUCCEEDED **`

## Review Disposition

- Confirmed branch-introduced issues: `F-001`, `F-002`
- Confirmed pre-existing issue still relevant in branch: `F-003`
- Recommended for next pass: close `F-001` first (user-visible API correctness), then decide validator activation scope (`F-002`), then formalize nil price-scale policy (`F-003`)
