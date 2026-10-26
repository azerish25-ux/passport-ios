# CI diagnostics — run 48

Commit: `2ae6d9f666c9fd8321fd6be8a0f8045573afadc6`
Event: push

## build/simulator-build.log
```text
--- last 40 lines ---

Ld /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/Binary/PassportProof normal x86_64 (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -Xlinker -reproducible -target x86_64-apple-ios17.0-simulator -isysroot /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk -O0 -L/Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator -F/Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator -Xlinker -rpath -Xlinker @executable_path -Xlinker -rpath -Xlinker @executable_path/Frameworks -rdynamic -Xlinker -no_deduplicate -Xlinker -objc_abi_version -Xlinker 2 -Xlinker -debug_variant -e ___debug_blank_executor_main -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __debug_dylib -Xlinker /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/PassportProof-DebugDylibPath-normal-x86_64.txt -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __debug_instlnm -Xlinker /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/PassportProof-DebugDylibInstallName-normal-x86_64.txt -Xlinker -filelist -Xlinker /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/PassportProof-ExecutorLinkFileList-normal-x86_64.txt /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/Binary/PassportProof.debug.dylib -o /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/Binary/PassportProof

CreateUniversalBinary /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/PassportProof normal arm64\ x86_64 (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/lipo -create /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/arm64/Binary/PassportProof /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/Binary/PassportProof -output /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/PassportProof

CopySwiftLibs /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-swiftStdLibTool --copy --verbose --scan-executable /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/PassportProof.debug.dylib --scan-folder /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/Frameworks --scan-folder /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/PlugIns --scan-folder /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/SystemExtensions --scan-folder /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/Extensions --platform iphonesimulator --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.3.7003.10.OZgVtp/Metal.xctoolchain --toolchain /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/Frameworks --strip-bitcode --strip-bitcode-tool /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span
Ignoring --strip-bitcode because --sign was not passed

ExtractAppIntentsMetadata (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor --toolchain-dir /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.3.7003.10.OZgVtp/Metal.xctoolchain --module-name PassportProof --sdk-root /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.2.sdk --xcode-version 17C529 --platform-family iOS --deployment-target 17.0 --bundle-identifier com.passportproof.app --output /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app --target-triple arm64-apple-ios17.0-simulator --target-triple x86_64-apple-ios17.0-simulator --binary-file /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/PassportProof --dependency-file /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/arm64/PassportProof_dependency_info.dat --dependency-file /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/PassportProof_dependency_info.dat --stringsdata-file /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/arm64/ExtractedAppShortcutsMetadata.stringsdata --stringsdata-file /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/ExtractedAppShortcutsMetadata.stringsdata --source-file-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/arm64/PassportProof.SwiftFileList --source-file-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/PassportProof.SwiftFileList --metadata-file-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/PassportProof.DependencyMetadataFileList --static-metadata-file-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/PassportProof.DependencyStaticMetadataFileList --swift-const-vals-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/arm64/PassportProof.SwiftConstValuesFileList --swift-const-vals-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/Objects-normal/x86_64/PassportProof.SwiftConstValuesFileList --compile-time-extraction --deployment-aware-processing --validate-assistant-intents --no-app-shortcuts-localization
2026-10-26 19:03:49.419 appintentsmetadataprocessor[2206:10243] Starting appintentsmetadataprocessor export
2026-10-26 19:03:49.424 appintentsmetadataprocessor[2206:10243] warning: Metadata extraction skipped. No AppIntents.framework dependency found.

AppIntentsSSUTraining (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    /Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsnltrainingprocessor --infoplist-path /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/Info.plist --temp-dir-path /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/ssu --bundle-id com.passportproof.app --product-path /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app --extracted-metadata-path /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app/Metadata.appintents --metadata-file-list /Users/runner/work/passport-ios/passport-ios/build/Build/Intermediates.noindex/PassportProof.build/Debug-iphonesimulator/PassportProof.build/PassportProof.DependencyMetadataFileList --archive-ssu-assets
2026-10-26 19:03:49.455 appintentsnltrainingprocessor[2211:10254] Parsing options for appintentsnltrainingprocessor
2026-10-26 19:03:49.456 appintentsnltrainingprocessor[2211:10254] No AppShortcuts found - Skipping.

RegisterExecutionPolicyException /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-RegisterExecutionPolicyException /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app

Validate /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-validationUtility /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app -shallow-bundle -infoplist-subpath Info.plist

Touch /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app (in target 'PassportProof' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    /usr/bin/touch -c /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProof.app

** BUILD SUCCEEDED **

```

## build/test-bundles.log
```text
--- last 40 lines ---
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -exclude Headers -exclude PrivateHeaders -exclude Modules -exclude \*.tbd -resolve-src-symlinks /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/XCTestCore.framework /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks

Copy /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks/XCTest.framework /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/XCTest.framework (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -exclude Headers -exclude PrivateHeaders -exclude Modules -exclude \*.tbd -resolve-src-symlinks /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/XCTest.framework /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks

Copy /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks/XCTAutomationSupport.framework /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/XCTAutomationSupport.framework (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -exclude Headers -exclude PrivateHeaders -exclude Modules -exclude \*.tbd -resolve-src-symlinks /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/XCTAutomationSupport.framework /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks

Copy /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks/Testing.framework /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/Testing.framework (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -exclude Headers -exclude PrivateHeaders -exclude Modules -exclude \*.tbd -resolve-src-symlinks /Applications/Xcode_26.3.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/Testing.framework /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/Frameworks

CodeSign /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/PlugIns/PassportProofUITests.xctest (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    
    Signing Identity:     "Sign to Run Locally"
    
    /usr/bin/codesign --force --sign - --timestamp\=none --generate-entitlement-der /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/PlugIns/PassportProofUITests.xctest

CodeSign /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    
    Signing Identity:     "Sign to Run Locally"
    
    /usr/bin/codesign --force --sign - --timestamp\=none --generate-entitlement-der /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app
/Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app: replacing existing signature

RegisterExecutionPolicyException /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/PlugIns/PassportProofUITests.xctest (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    builtin-RegisterExecutionPolicyException /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/PlugIns/PassportProofUITests.xctest

Touch /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/PlugIns/PassportProofUITests.xctest (in target 'PassportProofUITests' from project 'PassportProof')
    cd /Users/runner/work/passport-ios/passport-ios
    /usr/bin/touch -c /Users/runner/work/passport-ios/passport-ios/build/Build/Products/Debug-iphonesimulator/PassportProofUITests-Runner.app/PlugIns/PassportProofUITests.xctest

** TEST BUILD SUCCEEDED **

```

## build/unit-test.log
```text
48:Test Suite 'AssessmentDiagnosticsTests' passed at 2026-10-26 19:08:35.675.
49:	 Executed 9 tests, with 0 failures (0 unexpected) in 0.651 (0.658) seconds
63:Test Suite 'CatalogueContractTests' passed at 2026-10-26 19:08:35.688.
64:	 Executed 6 tests, with 0 failures (0 unexpected) in 0.010 (0.013) seconds
94:Test Suite 'CoreRegressionTests' passed at 2026-10-26 19:08:35.785.
95:	 Executed 9 tests, with 0 failures (0 unexpected) in 0.077 (0.084) seconds
101:Test Suite 'ExportStagingTests' passed at 2026-10-26 19:08:35.804.
102:	 Executed 2 tests, with 0 failures (0 unexpected) in 0.017 (0.019) seconds
126:Test Suite 'ManualFramingTests' passed at 2026-10-26 19:08:35.823.
127:	 Executed 11 tests, with 0 failures (0 unexpected) in 0.011 (0.019) seconds
183:Test Suite 'PassportProofTests' passed at 2026-10-26 19:08:37.577.
184:	 Executed 26 tests, with 0 failures (0 unexpected) in 1.478 (1.746) seconds
202:Test Suite 'PhotoSessionTests' passed at 2026-10-26 19:08:37.834.
203:	 Executed 8 tests, with 0 failures (0 unexpected) in 0.252 (0.257) seconds
413:Test Suite 'PortraitAssessmentTests' passed at 2026-10-26 19:08:43.235.
414:	 Executed 4 tests, with 0 failures (0 unexpected) in 5.398 (5.401) seconds
415:Test Suite 'PassportProofTests.xctest' passed at 2026-10-26 19:08:43.235.
416:	 Executed 75 tests, with 0 failures (0 unexpected) in 7.895 (8.219) seconds
417:Test Suite 'Selected tests' passed at 2026-10-26 19:08:43.236.
418:	 Executed 75 tests, with 0 failures (0 unexpected) in 7.895 (8.220) seconds
--- last 40 lines ---
expression=cannotVerify unmeasured
glasses=cannotVerify unmeasured
resolution=fail value=200.0 unit=px required=600 × 840 px minimum
photoAge=cannotVerify unmeasured
noManipulation=cannotVerify unmeasured
ASSESSMENT input=WhiteBackgroundPortrait-de-schengen-visa spec=de-schengen-visa size=200x200 overall=fail
Contract evidence only; landmark accuracy is measured by the isolated Vision diagnostic.
geometry=nil
headHeight=cannotVerify unmeasured
centring=cannotVerify unmeasured
backgroundUniformity=cannotVerify unmeasured
shadow=cannotVerify unmeasured
expression=cannotVerify unmeasured
glasses=cannotVerify unmeasured
resolution=fail value=200.0 unit=px required=420 × 540 px minimum
photoAge=cannotVerify unmeasured
noManipulation=cannotVerify unmeasured
Test Case '-[PassportProofTests.PortraitAssessmentTests testAnalysisContractHoldsForEveryFixtureAndWorkflow]' passed (3.343 seconds).
Test Case '-[PassportProofTests.PortraitAssessmentTests testAutomaticCropIsBoundedAndAspectLocked]' started.
Test Case '-[PassportProofTests.PortraitAssessmentTests testAutomaticCropIsBoundedAndAspectLocked]' passed (1.807 seconds).
Test Case '-[PassportProofTests.PortraitAssessmentTests testDigitalExportMeetsGeometryAndByteCeiling]' started.
Test Case '-[PassportProofTests.PortraitAssessmentTests testDigitalExportMeetsGeometryAndByteCeiling]' passed (0.174 seconds).
Test Case '-[PassportProofTests.PortraitAssessmentTests testUnavailableGeometryNeverBecomesAConfidentMeasurement]' started.
Test Case '-[PassportProofTests.PortraitAssessmentTests testUnavailableGeometryNeverBecomesAConfidentMeasurement]' passed (0.074 seconds).
Test Suite 'PortraitAssessmentTests' passed at 2026-10-26 19:08:43.235.
	 Executed 4 tests, with 0 failures (0 unexpected) in 5.398 (5.401) seconds
Test Suite 'PassportProofTests.xctest' passed at 2026-10-26 19:08:43.235.
	 Executed 75 tests, with 0 failures (0 unexpected) in 7.895 (8.219) seconds
Test Suite 'Selected tests' passed at 2026-10-26 19:08:43.236.
	 Executed 75 tests, with 0 failures (0 unexpected) in 7.895 (8.220) seconds
2026-10-26 19:08:44.046 xcodebuild[4456:19376] [MT] IDETestOperationsObserverDebug: 44.890 elapsed -- Testing started completed.
2026-10-26 19:08:44.047 xcodebuild[4456:19376] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-10-26 19:08:44.047 xcodebuild[4456:19376] [MT] IDETestOperationsObserverDebug: 44.890 sec, +44.890 sec -- end

Test session results, code coverage, and logs:
	/Users/runner/work/passport-ios/passport-ios/build/UnitResults.xcresult

** TEST EXECUTE SUCCEEDED **

Testing started
```

## build/storekit-test.log
```text
18:Configured error: Optional(StoreKitTest.SKTestFailures.Purchase.generic(StoreKit.StoreKitError.userCancelled))
49:Configured error: StoreKitError.notAvailableInStorefront
69:Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
74:Test Suite 'StoreKitIntegrationTests' passed at 2026-10-26 19:12:52.639.
75:	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
76:Test Suite 'PassportProofTests.xctest' passed at 2026-10-26 19:12:52.640.
77:	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
78:Test Suite 'Selected tests' passed at 2026-10-26 19:12:52.640.
79:	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.002) seconds
--- last 40 lines ---
Resulting state: failed("The App Store could not complete that request. Check your connection and try again.")
Unlocked: false; working: false
Thrown error chain:
StoreKitError.notAvailableInStorefront domain=StoreKit.StoreKitError code=4
Test Case '-[PassportProofTests.StoreKitIntegrationTests testNonCancellationPurchaseFailureStaysLockedAndCanRetry]' passed (0.385 seconds).
Test Case '-[PassportProofTests.StoreKitIntegrationTests testPendingPurchaseStaysLockedUntilApproval]' started.
Test Case '-[PassportProofTests.StoreKitIntegrationTests testPendingPurchaseStaysLockedUntilApproval]' passed (1.015 seconds).
Test Case '-[PassportProofTests.StoreKitIntegrationTests testPurchaseRestoreAndRefundUpdateVerifiedEntitlement]' started.
2026-10-26 19:09:31.677157+0000 PassportProof[7137:28385] [Default] [a579197a_SK2] Error finishing transaction: Error Domain=storekitd.Request.RequestError Code=1 "(null)"
2026-10-26 19:09:31.686551+0000 PassportProof[7137:28435] [Default] [04a605e3_SK2] Error finishing transaction: Error Domain=storekitd.Request.RequestError Code=1 "(null)"
Test Case '-[PassportProofTests.StoreKitIntegrationTests testPurchaseRestoreAndRefundUpdateVerifiedEntitlement]' exceeded execution time allowance of 2 minutes. The test may have hung; check Xcode's test report for additional diagnostics. If the test requires additional time, use -[XCTestCase executionTimeAllowance] or one of xcodebuild's command-line overrides.


*** If you believe this error represents a bug, please attach the result bundle at /Users/runner/work/passport-ios/passport-ios/build/StoreKitResults.xcresult

IOSurfaceClientSetSurfaceNotify failed e00002c7
2026-10-26 19:12:47.167220+0000 PassportProof[15869:50438] [General] Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
2026-10-26 19:12:47.428476+0000 PassportProof[15869:50438] [General] Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com.apple.app_launch_measurement.ExtendedLaunchMetrics

Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.

Test Suite 'Selected tests' started at 2026-10-26 19:12:52.638.
Test Suite 'PassportProofTests.xctest' started at 2026-10-26 19:12:52.639.
Test Suite 'StoreKitIntegrationTests' started at 2026-10-26 19:12:52.639.
Test Suite 'StoreKitIntegrationTests' passed at 2026-10-26 19:12:52.639.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'PassportProofTests.xctest' passed at 2026-10-26 19:12:52.640.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
Test Suite 'Selected tests' passed at 2026-10-26 19:12:52.640.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.002) seconds
2026-10-26 19:13:36.904 xcodebuild[5982:24780] [MT] IDETestOperationsObserverDebug: 262.581 elapsed -- Testing started completed.
2026-10-26 19:13:36.904 xcodebuild[5982:24780] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-10-26 19:13:36.904 xcodebuild[5982:24780] [MT] IDETestOperationsObserverDebug: 262.581 sec, +262.581 sec -- end

Test session results, code coverage, and logs:
	/Users/runner/work/passport-ios/passport-ios/build/StoreKitResults.xcresult

** TEST EXECUTE FAILED **

Testing started
```

## build/ui-test.log
```text
1205:/Users/runner/work/passport-ios/passport-ios/PassportProofUITests/PassportProofUITests.swift:465: error: -[PassportProofUITests.PassportProofUITests testSystemPhotoPickerOpens] : XCTAssertTrue failed - Required UI is missing: no element matching that query. On screen: Visa, BackButton, sun.max, capture.camera, capture.library, PUPickerUnavailableView, camera, chevron.right, photo.on.rectangle
1209:Test Case '-[PassportProofUITests.PassportProofUITests testSystemPhotoPickerOpens]' failed (119.883 seconds).
1215:Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
1354:Test Suite 'PassportProofUITests' passed at 2026-10-26 19:21:52.611.
1355:	 Executed 1 test, with 0 failures (0 unexpected) in 42.048 (42.060) seconds
1356:Test Suite 'PassportProofUITests.xctest' passed at 2026-10-26 19:21:52.613.
1357:	 Executed 1 test, with 0 failures (0 unexpected) in 42.048 (42.063) seconds
1358:Test Suite 'Selected tests' passed at 2026-10-26 19:21:52.616.
1359:	 Executed 1 test, with 0 failures (0 unexpected) in 42.048 (42.068) seconds
--- last 40 lines ---
    t =    36.41s     Check for interrupting elements affecting "library.unlock" Button
    t =    36.48s     Synthesize event
    t =    36.80s     Wait for com.passportproof.app to idle
    t =    36.87s Waiting 20.0s for "unlock.purchaseArea" Any to exist
    t =    37.88s     Checking `Expect predicate `existsNoRetry == 1` for object "unlock.purchaseArea" Any`
    t =    37.88s         Checking existence of `"unlock.purchaseArea" Any`
    t =    37.95s Waiting 25.0s for "Export is unlocked for this Apple Account." StaticText to exist
    t =    39.00s     Checking `Expect predicate `existsNoRetry == 1` for object "Export is unlocked for this Apple Account." StaticText`
    t =    39.00s         Checking existence of `"Export is unlocked for this Apple Account." StaticText`
    t =    39.06s Checking existence of `"unlock.purchase" Button`
    t =    39.11s Checking existence of `"unlock.restore" Button`
    t =    39.16s Find the "unlock.restore" Button
    t =    39.25s Checking existence of `"unlock.restore" Button`
    t =    39.30s Find the "unlock.restore" Button
    t =    39.36s Tap "unlock.restore" Button
    t =    39.36s     Wait for com.passportproof.app to idle
    t =    39.36s     Find the "unlock.restore" Button
    t =    39.43s     Check for interrupting elements affecting "unlock.restore" Button
    t =    39.52s     Synthesize event
    t =    39.84s     Wait for com.passportproof.app to idle
    t =    40.86s Find the "unlock.restore" Button
    t =    40.91s Tear Down
    t =    40.91s     Terminate com.passportproof.app:36335
Test Case '-[PassportProofUITests.PassportProofUITests testUnlimitedPurchaseSurvivesRelaunchAndRestores]' passed (42.048 seconds).
Test Suite 'PassportProofUITests' passed at 2026-10-26 19:21:52.611.
	 Executed 1 test, with 0 failures (0 unexpected) in 42.048 (42.060) seconds
Test Suite 'PassportProofUITests.xctest' passed at 2026-10-26 19:21:52.613.
	 Executed 1 test, with 0 failures (0 unexpected) in 42.048 (42.063) seconds
Test Suite 'Selected tests' passed at 2026-10-26 19:21:52.616.
	 Executed 1 test, with 0 failures (0 unexpected) in 42.048 (42.068) seconds
2026-10-26 19:22:27.375 xcodebuild[19148:59162] [MT] IDETestOperationsObserverDebug: 495.028 elapsed -- Testing started completed.
2026-10-26 19:22:27.384 xcodebuild[19148:59162] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-10-26 19:22:27.384 xcodebuild[19148:59162] [MT] IDETestOperationsObserverDebug: 495.028 sec, +495.028 sec -- end

Test session results, code coverage, and logs:
	/Users/runner/work/passport-ios/passport-ios/build/UIResults.xcresult

** TEST EXECUTE FAILED **

Testing started
```

