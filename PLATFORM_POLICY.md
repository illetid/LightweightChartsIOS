# Platform Policy for LightweightChartsIOS

## Effective Version: 5.1.0

This document defines the supported platform and distribution policy for the LightweightChartsIOS wrapper library.

---

## Supported Distribution Path

### Swift Package Manager only

As of version 5.1.0, Swift Package Manager is the only supported distribution path for this repository.

| Distribution Path     | Status      |
|-----------------------|-------------|
| Swift Package Manager | Supported   |
| CocoaPods             | Removed     |

---

## Minimum Platform Version

### iOS 15.0

As of version 5.1.0, the minimum supported iOS version is **15.0**.

### Why iOS 15.0?

1. Swift 6 and the async/await-first API are the baseline for the current release.
2. The wrapper depends on modern WebKit and concurrency behavior that is aligned with iOS 15+.
3. Supporting older versions would increase maintenance burden for a release that already contains intentional breaking changes.

---

## Migration Impact for Users

Apps targeting iOS earlier than 15.0 or relying on CocoaPods must remain on an older release line or migrate to:

- iOS 15.0+
- Swift 6
- Swift Package Manager

---

## Maintenance Rule

Platform minimum version increases and supported distribution path changes are major-release decisions and must be reflected consistently in:

1. [Package.swift](/Users/aovcharenko/Work/rappers/LightweightChartsIOS/Package.swift)
2. [README.md](/Users/aovcharenko/Work/rappers/LightweightChartsIOS/README.md)
3. [CHANGELOG.md](/Users/aovcharenko/Work/rappers/LightweightChartsIOS/CHANGELOG.md)

---

## Version History

| Wrapper Version | Minimum iOS | Distribution | Notes |
|-----------------|-------------|--------------|-------|
| 4.0.0           | 12.0        | CocoaPods/SPM | Legacy pre-Swift-6 wrapper |
| 5.1.0           | 15.0        | SPM only     | Swift 6 async release, CocoaPods removed |
