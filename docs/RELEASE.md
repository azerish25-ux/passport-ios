# PassportProof — Release checklist

What it takes to move this repository from *submission-ready build
configuration* to *submitted*. Split by where the work lives: in the repo
(done, and asserted by tests) and in App Store Connect (manual, one-time).

---

## In the repository — done

| Item | Where | How it is verified |
|---|---|---|
| App icon, 1024 px, opaque, flat | `PassportProof/Resources/Assets.xcassets/AppIcon.appiconset/` | `Tools/generate_icon.py` regenerates it; `testAppIconIsCompiledIntoTheBundle` asserts `CFBundleIconName` in the compiled bundle |
| Launch screen | `Info.plist` → `UILaunchScreen` → `UIColorName = LaunchBackground` | `testLaunchScreenIsConfigured`; the colour set carries light/dark variants of the paper tone, so there is no white flash in dark mode |
| Camera privacy description | `Info.plist` → `NSCameraUsageDescription` | `testPrivacyUsageDescriptionsArePresent` |
| Photo-library privacy description | `Info.plist` → `NSPhotoLibraryUsageDescription` | `testPrivacyUsageDescriptionsArePresent` |
| Privacy manifest | `PassportProof/Resources/PrivacyInfo.xcprivacy` | `testPrivacyManifestIsBundled`; declares no tracking, no collected data, no accessed required-reason APIs — accurate for this app, which has no UserDefaults, no networking, and no file-timestamp reads |
| Export compliance | `Info.plist` → `ITSAppUsesNonExistentEncryption = false` | the app ships only Apple's own crypto (StoreKit, OS HTTPS); the key removes the per-build export-compliance prompt |
| Release version | `Tools/generate_project.py` → `MARKETING_VERSION = 1.0.0` | `testBundleVersionIsAReleaseVersion` rejects a `0.x` version |
| Promise-word audit (AC5) | — | `testInfoPlistCarriesNoBannedPromiseWords` over the compiled plist; no `approved` / `guaranteed` / `official` / `accepted` anywhere in app strings |
| StoreKit configuration | `StoreKit/PassportProof.storekit` | one non-consumable, `com.passportproof.app.unlock` (AC3) |
| No photo storage (P1) | `PhotoSession` is memory-only; export staging files are deleted on dismissal | kill-and-relaunch review check in `docs/MANUAL-QA.md` |
| CI proof | `.github/workflows/ios-build.yml` | simulator build + unit tests + unsigned Release device build on every push |

## In App Store Connect — manual, before submission

1. **App record.** Create the app with bundle ID `com.passportproof.app`.
2. **Signing.** Set the development team in Xcode (Signing & Capabilities) or
   pass `DEVELOPMENT_TEAM` on the `xcodebuild archive` command line. The
   checked-in project deliberately does not hardcode a team ID.
3. **In-App Purchase.** Create the non-consumable `com.passportproof.app.unlock`
   at $17.99 with the localizations from the `.storekit` file, and submit it
   with the first build. Until it exists, the paywall shows the labelled
   prototype bypass — do not ship that state to production builds.
4. **App Privacy labels.** "Data Not Collected", no tracking. That matches
   `PrivacyInfo.xcprivacy` exactly.
5. **Screenshots.** 6.9" and 6.5" iPhone sets: Library, Capture, Diagnose
   (with findings), Export. The design system's paper background photographs well.
6. **Review notes.** State plainly: informational diagnosis only, no approval
   promised (the `cannot verify` third state is the visible form of that),
   photos never leave the device, four of twelve documents encoded and labelled
   as such, calibration sheet is free, unlock is one non-consumable.
7. **Demo path for the reviewer.** The simulator has no camera, so review on
   device *or* ship one sample photo in the review notes' instructions — the
   library import path completes every flow in Airplane mode (AC4).

## Archive command

```bash
python3 Tools/generate_project.py
xcodebuild archive \
  -project PassportProof.xcodeproj \
  -scheme PassportProof \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/PassportProof.xcarchive
xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist \
  -archivePath build/PassportProof.xcarchive \
  -exportPath build
```

## Known gaps that stay open after this release

- Eight of twelve launch documents are unencoded and shown as empty slots.
- The gate runs on the captured still, not the live feed (`UIImagePickerController`
  exposes no frames). Moving to `AVCaptureSession` is the E2 upgrade.
- Expression and glasses are honest `cannot verify` / glare-proxy checks, not
  classifiers (GAP G2).
- The corpus figures carry `isPrototypeData`; the 2.5–4 documents/person-day
  verification programme has not run.
