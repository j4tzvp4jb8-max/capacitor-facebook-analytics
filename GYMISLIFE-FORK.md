# GymIsLife fork of @capgo/capacitor-facebook-analytics

Forked from Cap-go/capacitor-facebook-analytics at `983badb` (release 8.1.19). Licence unchanged: MPL-2.0
(see `LICENSE`). This fork is published so the source of every modified file is available, as MPL-2.0
section 3.2 requires for the GymIsLife app binaries that include it.

## What changed (8.1.19-gil.1, 24 Oct 2026)

- **Meta SDK pinned exactly to 19.0.0** on iOS (`Package.swift`, podspec) and Android (`android/build.gradle`,
  no longer overridable). 19.0.0 is the first release in which automatic event logging switched off in the
  app cannot be switched back on from Events Manager, and the first with opt-outs for the screen-title /
  AppLink metadata and layout-sampling streams Meta enables on 31 Oct 2026.
- **Consent gate in the plugin itself**: `logEvent`, `logPurchase` and `enableAdvertiserTracking` are refused
  until `initAppEvents()` has run in the same process. The app calls `initAppEvents()` only after a stored,
  explicit yes.
- **`initAppEvents()`** writes automatic logging OFF and advertiser-ID collection ON explicitly before
  activating (the SDK caches these switches on the device and the cache wins over Info.plist / the manifest).
  Android also follows Meta's delayed-init sequence: `setAutoInitEnabled(true)` then `fullyInitialize()`.
- Both also write OFF the two 19.0.0 automatic streams - screen-title/AppLink metadata
  (iOS `isMetaDataCollectionEnabled`, Android `setAutoLogMetaDataEnabled`) and product-improvement layout
  sampling (`isAutoLogProductImprovementEnabled` / `setAutoLogProductImprovementEnabled`) - and, on Android,
  SDK self-monitoring (`setMonitorEnabled`). The app's Info.plist / manifest set the same switches false.
- **New `stopAppEvents()`** (withdrawal): refuses further events and writes automatic logging, advertiser-ID
  collection and (Android) auto-init back to false; iOS 15-16 also clears advertiser tracking.
- **New `requestTrackingAuthorization()` / `getTrackingAuthorizationStatus()`** (iOS): Apple's App Tracking
  Transparency prompt, requested only while the app is active. It never initialises the Meta SDK.
- **New `openAppSettings()`** (iOS, 8.1.19-gil.2): opens the app's page in iPhone Settings, where Apple's
  "Allow Tracking" switch lives. Touches nothing in the Meta SDK. Android rejects it as unimplemented.
