# Platform Policy for LightweightChartsIOS

## Effective Version: 5.0.0

This document defines the platform support policy for the LightweightChartsIOS wrapper library.

---

## Minimum Platform Version

### iOS 13.0

As of version 5.0.0, the minimum supported iOS version is **13.0** for all package managers.

| Package Manager | Minimum iOS Version |
|-----------------|---------------------|
| CocoaPods       | iOS 13.0            |
| SPM             | iOS 13.0            |

---

## Rationale

### Current State (v4.0.0)
- CocoaPods specified iOS 12.0
- SPM specified iOS 10.0
- README documented "iOS 12.0+"
- Inconsistent requirements across package managers created confusion

### Why iOS 13.0?

1. **Consistency**: Unified minimum version across all package managers eliminates user confusion.

2. **Market Saturation**: As of 2026, iOS 13+ represents >99% of active devices. iOS 13 was released in September 2019.

3. **Major Version Flexibility**: v5.0.0 is a major version bump, which semantically allows for breaking changes including platform minimum increases.

4. **Modern APIs**: iOS 13 provides access to modern APIs that may be useful for future wrapper enhancements (e.g., Combine, updated WKWebView capabilities).

5. **Maintainability**: Dropping support for iOS 10-12 reduces testing matrix and allows use of newer Swift language features without complex availability checks.

---

## Migration Impact for Users

### Users on iOS 12.x
Apps targeting iOS 12.x will need to either:
- Remain on LightweightChartsIOS v4.0.0
- Update their app's deployment target to iOS 13.0+

### Users on iOS 13.0+
No migration required. Upgrade directly to v5.0.0.

---

## Future Platform Bumps

### Policy
Platform minimum version increases will only occur with **major version bumps** (e.g., v6.0.0).

### Criteria
Future platform version increases will be considered when:
1. The older iOS version represents <1% of active devices
2. Significant developer experience improvements are available
3. A major version bump is already planned for other breaking changes

### Notification
Platform minimum changes will be:
1. Announced in the changelog
2. Documented in migration guides
3. Included in release notes at least one minor version ahead of the change

---

## Implementation Files

The following files must be updated consistently when changing platform versions:

1. `LightweightCharts.podspec` - `s.ios.deployment_target`
2. `Package.swift` - `.iOS(.vXX)` in platforms array
3. `README.md` - Requirements section

---

## Version History

| Wrapper Version | Minimum iOS | Date       | Notes                                  |
|-----------------|-------------|------------|----------------------------------------|
| 4.0.0           | 12.0 (CP)   | 2024       | Inconsistent: SPM specified 10.0       |
| 5.0.0           | 13.0        | 2026-02    | Unified across all package managers    |

---

## Related Documents

- `MIGRATION_PLAN_V4_TO_V5.md` - Technical migration details
- `TASKS_V4_TO_V5.md` - Implementation checklist
- `MIGRATION_V4_TO_V5.md` - User-facing migration guide (to be created)
