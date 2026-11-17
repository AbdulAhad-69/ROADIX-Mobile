# ROADIX — Build & Deployment Guide

**Status:** DRAFT BASELINE (To be finalized in Phase 10)  
**Target Platforms:** Android (minSdk 21+, targetSdk 34+), iOS (iOS 14.0+)  

---

## 1. Environment Configuration

ROADIX uses environment files (`.env`) injected at build time via Flutter's `--dart-define-from-file`:

```bash
# Debug run with local development environment
flutter run --dart-define-from-file=.env

# Release build for Android APK
flutter build apk --release --dart-define-from-file=.env

# Release build for Android App Bundle (Play Store)
flutter build appbundle --release --dart-define-from-file=.env
```

---

## 2. Platform Release Checklists

### Android
- [ ] Application ID configured in `android/app/build.gradle.kts` (`com.roadix.roadix_mobile`).
- [ ] Release signing keys configured in `key.properties` (never commit keys to Git).
- [ ] Permissions verified: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- [ ] ProGuard / R8 rules configured for MapLibre and Supabase serialization.

### iOS
- [ ] Bundle Identifier configured in Xcode (`com.roadix.roadixMobile`).
- [ ] CocoaPods initialized and `pod install` run successfully.
- [ ] **MANDATORY PERMISSION:** Add `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` to `ios/Runner/Info.plist`.
- [ ] Distribution certificate and provisioning profile installed.
