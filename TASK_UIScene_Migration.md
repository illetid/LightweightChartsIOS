# Task: Migrate Example App to UIScene Lifecycle

## Problem

Xcode emits this warning at launch:

```
`UIScene` lifecycle will soon be required. Failure to adopt will result in an assert in the future.
```

The Example app uses the legacy `AppDelegate`-only lifecycle (`application(_:didFinishLaunchingWithOptions:)` creates the window directly). Apple is deprecating this pattern and will eventually enforce `UIScene` adoption.

## Current State

- [Example/LightweightCharts/AppDelegate.swift](Example/LightweightCharts/AppDelegate.swift) — creates `UIWindow`, sets `rootViewController`, and calls `makeKeyAndVisible` in `didFinishLaunchingWithOptions`.
- [Example/LightweightCharts/Info.plist](Example/LightweightCharts/Info.plist) — no `UIApplicationSceneManifest` key.
- No `SceneDelegate` exists.

## Changes Required

### 1. Create `SceneDelegate.swift`

New file at `Example/LightweightCharts/SceneDelegate.swift`:

- Conform to `UIWindowSceneDelegate`.
- Move the window creation and root ViewController setup from `AppDelegate` into `scene(_:willConnectTo:options:)`.
- Wrap the `UINavigationController` + `TableViewController` setup here.

### 2. Update `AppDelegate.swift`

- Remove window creation logic from `application(_:didFinishLaunchingWithOptions:)`.
- Add `configurationForConnecting` method to return a `UISceneConfiguration` pointing to `SceneDelegate`.
- Keep the `window` property for iOS 12 backward compatibility (deployment target is iOS 13.0, so this may not be needed — verify).

### 3. Update `Info.plist`

Add the `UIApplicationSceneManifest` dictionary:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                <key>UISceneStoryboardFile</key>
                <string></string>
            </dict>
        </array>
    </dict>
</dict>
```

### 4. Add `SceneDelegate.swift` to Xcode project

Add to `project.pbxproj` in 4 sections: PBXBuildFile, PBXFileReference, PBXGroup (under LightweightCharts app group, not Example), Sources build phase.

## Scope

- Example app only — no changes to the library source under `Sources/`.
- Deployment target is already iOS 13.0, so no backward-compatibility dance needed (UIScene was introduced in iOS 13).
- Verify the app still launches correctly on simulator after migration.

## Priority

Low — the app works fine today. This is a future-proofing task to silence the warning before Apple turns it into a hard assert.
