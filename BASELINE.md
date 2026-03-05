# Baseline: LightweightChartsIOS v4.0.0

**Captured:** 2026-02-26
**Purpose:** Establish baseline versions and constraints before v4 to v5 migration

## Version Summary

| Component | Version |
|-----------|---------|
| CocoaPods Podspec | 4.0.0 |
| Embedded JS Bundle | 4.0.0 |
| Swift Version | 5.0 |

## Platform Constraints

| Package Manager | Minimum iOS Version |
|-----------------|---------------------|
| CocoaPods (podspec) | iOS 12.0 |
| Swift Package Manager | iOS 10.0 |

**Note:** There is an intentional mismatch between package managers - SPM supports iOS 10+ while CocoaPods requires iOS 12+.

## Embedded JavaScript Bundle

- **File:** `Sources/LightweightCharts/Assets/lightweight-charts.js`
- **Upstream:** TradingView Lightweight Charts
- **Version:** 4.0.0
- **File Size:** 148,189 bytes (~145 KB)
- **Format:** UMD standalone production build
- **Version Marker:** `* TradingView Lightweight Charts v4.0.0`

## Package Resources

The following JavaScript files are packaged as resources:
- `Assets/lightweight-charts.js` - Main library (v4.0.0)
- `Assets/content-setup.js` - Content initialization
- `Assets/wrapper_functions.js` - Swift-JavaScript bridge functions

## Source Files Pattern

- Swift sources: `Sources/LightweightCharts/**/*.swift`
- Resources: `Sources/LightweightCharts/Assets/*`

## Migration Target

- **Target JS Version:** 5.1.0
- **Target Wrapper Version:** 5.0.0
- **Upstream Source:** Local lightweight-charts repository at `/Users/aovcharenko/Work/rappers/lightweight-charts`
