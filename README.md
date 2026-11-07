# Punchino with workload colors

An independent native SwiftUI implementation for iPhone and Apple Watch. It uses the public [Punchino reference](https://apps.apple.com/us/app/time-tracker-punchino/id6757963430) and direct inspection of the original app through the user's iPhone Mirroring session. It adds named workload colors to each recorded session.

The live audit covers three-tab navigation, all focus modes, calendar borders, manual sessions, week details, Debug, CSV pickers, Statistics, and active phone tracking. It also includes native Watch idle Track, active Track, and Totals captures. [Reference/REFERENCE.md](Reference/REFERENCE.md) separates observed details, implemented behavior, and completed verification. Current native observations supersede conflicting promotional layouts. Exact rendering across OS versions and the remaining live/reference limits remain unverified.

The Settings footer preserves the original creator credit as a visual reference. The app icon reuses the original public [App Store artwork](https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/20/b6/5a/20b65a45-0b92-7b00-8530-1b920bf0101c/AppIcon-0-0-1x_U007ephone-0-1-sRGB-85-220.png/1024x1024bb.png) without raster edits. This repository contains independent code. It does not contain the original app's source code.

## Open and run

Requirements: Xcode 26 or later, an iOS 26 or later simulator/device, and watchOS 26 or later for the watch app. Development used Xcode 27.2.

The original phone is an iPhone 16 Plus on iOS 26.6.2. Its verified system settings are Default Display Zoom, Medium text, and Bold Text on. Inspection did not change those system settings. The matched-model idle control now uses a 220pt ring, 10pt stroke, and 56pt OUT text. Earlier 200/9/48 estimates used the wrong device model.

An iOS 26.5 runtime was installed from Apple's official catalog because 26.6.2 was unavailable. The full iPhone 16 Plus suite passed on 26.5. That run used Medium content size, with the reference-only Bold modifier for reference captures.

1. Open `Punchino.xcodeproj` in Xcode.
2. Select the `Punchino` scheme.
3. Select an iPhone simulator.
4. Press Run.

The iPhone app embeds the watch app and both platforms have widget extensions. Select the `PunchinoWatch` scheme to run the watch app directly. The watch app also records time without an iPhone.

No signing team is selected. For physical devices, select your Apple development team for the app and extension targets. Configure the bundle identifiers and App Group in that team first. The default build keeps iCloud disabled and stores time locally.

## Workload colors

On iPhone:

1. Open Settings.
2. Select Workload Colors.
3. Press the plus button.
4. Enter a workload name.
5. Select a preset color or a custom color.
6. Press Save.
7. Open the OUT tab.
8. Tap the large OUT control.
9. Select a colored Punch In button.
10. Tap the active IN control to punch out.

The first punch-in tap reveals the choices. A session starts only after a workload selection. Work, Study, and Personal are available initially.

On Apple Watch:

Define and edit workload colors on iPhone. The Watch picker uses those predefined choices.

1. Tap the OUT control.
2. Scroll the workload wheel with the Digital Crown or your finger.
3. Select a workload.
4. Tap Punch In.
5. Tap IN to punch out.

Each session keeps its recorded workload name and color. Later workload edits apply to new sessions. Archiving a workload preserves its past sessions.

Custom filled controls choose the higher-contrast black or white text. Colored workload labels use primary text when their contrast against the neutral surface is weak. Separate outline rules keep blending swatches and controls visible, including history markers, timeline bars, and editor choices. The three original preset RGB values retain their existing appearance. These display rules preserve stored colors and add no fields to recorded sessions.

## Features

- Live timers, punch in/out, and haptic feedback.
- Daily, weekly, and monthly totals.
- Native Home, Statistics, and OUT/IN tabs, with collapsing navigation titles.
- iPhone monthly heatmap history, month navigation, daily timelines, and week details.
- Statistics for D, W, M, 6M, and Y, including charts, comparisons, outliers, and summaries.
- Balance, Momentum, and Observe focus modes with matching tracking/pattern labels.
- iPhone manual session creation, editing, individual deletion, and daily deletion.
- Weekly and daily goal/limit/target sliders in half-hour increments.
- Six accent colors and system light/dark appearance.
- Named workload colors, presets, custom colors, and workload archiving.
- CSV export with the original seven-column prefix, followed by workload, color, session ID, and precise ISO timestamps.
- CSV import with an optional replacement of existing sessions.
- Debug information for refresh, CloudKit, sessions, and App Group storage.
- Offline storage, paired-device synchronization, and optional private CloudKit synchronization.
- iPhone widgets, watch Smart Stack widgets, and inline, circular, and rectangular complications.
- Configurable widget status/totals display and interactive punch-out controls.
- Siri/Shortcuts actions for punch in and punch out on iPhone.

Inactive widgets open the app's workload selection. Active widget controls can stop the current session. System widget scheduling controls update timing.

## Native Watch reference audit

The physical reference is an Apple Watch Series 9 (GPS), 45mm, on watchOS 26.6 (23U67), with Bold Text on. Its exact Dynamic Type category remains unknown. The user supplied native 396 × 484px idle Track, active Track, and Totals PNGs through iPhone Photos. Those images and their provenance remain in the ignored `Reference/Private` directory. Public evidence uses synthetic sessions and does not reproduce the user's totals. The user recorded one approved short Watch session and confirmed that it stopped. That record remains intact. The agent did not operate the original Watch punch controls.

The user reported that tapping the original Today card does not open a list. The Watch now has Track and read-only Totals pages. Unsupported Watch history, Settings, and editor screens/code were deleted. The added workload picker directs definition and editing to iPhone. Earlier Watch history tests remain historical evidence of the superseded implementation.

The [runtime environment record](Evidence/WatchOS26Environment/environment.json) identifies the download from [Apple's simulator catalog](https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex). The catalog snapshot did not offer watchOS 26.6. Xcode installed watchOS 26.5 (23T570) for the Series 9 comparison. The optional runtime verification command returned `-67054`, reporting a missing or invalid sealed resource. Normal phone/watch boot completed with exit code 0, without a bypass. The environment record preserves the diagnostic and boot logs.

The native 26.5 baseline retained the earlier 27.2 geometry differences. A reference-only app-view override reaches the corrected page leaves, which report xLarge/Bold and resolved point sizes. This does not identify the physical Watch's Dynamic Type category or change the native system clock's font.

The revised Track ring, OUT text, and Today strip match measured geometry. Totals cards and invariant labels match bounds, colors, and binary ink masks. After the final 0.5pt trailing adjustment, all three invariant Totals suffix m glyphs match their shape and position. The Today duration unit retains a small weight difference: its 16 × 16px mask has area 181 versus the original's 199. The closer size-matched choice is retained.

The later active capture supports a 164px core and 208px halo. It also supports smaller IN and timer text, a proportional Started row, and partially transparent timer ink. The correction preserves the selected workload hue. Timer ink uses the observed 0.7 opacity only when its calculated composite contrast remains at least 4.5:1. Other colors and reduced-luminance mode keep opaque timer ink. The user did not notice ring motion during the test. The still image does not establish pulse behavior.

The earlier [aligned 45mm record](Evidence/Watch26AlignedFinal/validation.json) preserves idle/Totals measurements and reference-only environment diagnostics before the active-screen correction. The current four-case run is in [Evidence/WatchActiveFinal](Evidence/WatchActiveFinal). It covers both reference states, Crown selection, persisted time, and extreme colors. The current larger-screen run is in [Evidence/WatchActive46mmFinal](Evidence/WatchActive46mmFinal). It establishes fitting on watchOS 27.2, without an original 46mm comparison.

## Native Watch widgets and complications

Reference 13 displays the Utility face. Its curved bottom slot uses `accessoryInline`: Apple's [ClockKit migration guide](https://developer.apple.com/documentation/widgetkit/converting-a-clockkit-app) maps `utilitarianLarge` to that family. Apple explains that the face can render inline image/text content along a curve in [Go further with Complications in WidgetKit](https://developer.apple.com/videos/play/wwdc2022/10051/). The existing inline family covers the shown slot. An `accessoryCorner` family is not required for that reference.

Actual native Smart Stack captures appear in [Evidence/NativeWidgetsFinal](Evidence/NativeWidgetsFinal). The [measurement record](Evidence/NativeWidgetsFinal/measurements.json) compares circle/text geometry and sampled background tones with the public reference. OUT text has matching 154 × 62px ink bounds on the 416 × 496px canvas. Elapsed text stays on one line without clipping. Scroll position changes the system header and card origin.

## Offline timer reconciliation

If an older offline Work timer meets a newer Study session that already stopped, the older timer closes at the newer session's start. Later deletion of that newer session does not revive the older timer. The model preserves timer-start boundaries across merge order and deletion. Completed imported history does not stop a live timer. Regression tests cover these cases and legacy records.

## Shared-code synchronization probe

The bidirectional simulator probe passed using the Shared source set identified in its evidence. The phone started Work. The Watch received and stopped it, then started Study. The phone received and stopped Study. Both stored snapshots converged to the same two ended sessions with matching fields and no active timer.

Current synthetic reports and source hashes appear in `Evidence/ConnectivityProbe/ContrastCorrection`. Its validation summary matches all current Shared source hashes. Earlier runs remain preserved in their original folders. The reproducible harness and instructions are in [Tests/ConnectivityProbe](Tests/ConnectivityProbe/README.md).

```sh
python3 Tests/ConnectivityProbe/run_probe.py \
  --phone PAIRED_IPHONE_SIMULATOR_UUID \
  --watch PAIRED_WATCH_SIMULATOR_UUID \
  --evidence Evidence/ConnectivityProbe
```

This checks actual foreground, small-history WatchConnectivity transport with CloudKit disabled. It uses isolated temporary apps and repositories, then uninstalls those apps. It does not establish physical-device behavior, background latency, file/user-info transfers, App Group storage, CloudKit, or APNs.

The widget stop action now retains its local store while awaiting a paired-sync queue operation. The operation waits up to three seconds for WatchConnectivity activation. Queue acceptance means the framework accepted the snapshot. It does not acknowledge counterpart delivery. Timeout or unavailability preserves the local stop and reports paired sync as pending or unavailable.

Separate native evidence verifies more than queue acceptance. In [Evidence/NativeWidgetBarrier/validation.json](Evidence/NativeWidgetBarrier/validation.json), the actual Smart Stack stop control ran while the Watch app remained `notRunning`, without reopening it. The paired phone and Watch App Group snapshots converged to exactly equal session fields and matching file hashes, with no active timer and CloudKit disabled. The current lifetime probe separately verified delivery from short-lived and retained stores, plus preservation of the local stop after an activation timeout. These simulator results do not establish delivery before every extension termination or physical-device background latency.

The earlier zero-timeout run queued after activation was already complete. The new run exercised the timeout fallback: it returned in approximately 4.9ms, preserved the local stop, and reported Paired sync pending. It did not report counterpart delivery. Details appear in `Evidence/ConnectivityProbe/ContrastCorrection/validation-summary.json`.

The native [Black widget check](Evidence/NativeBlackWidget/validation.json) also passed. It seeded workload definitions and no sessions. The fixture preserved nine existing sessions. The normal Watch wheel and confirmation then started a Black session. The stored color remained `000000`.

Its actual WidgetKit stop ran while the Watch app stayed `notRunning`. The paired session fields matched exactly and no active timer remained. Screenshots display the visible outlined black circle and elapsed text.

## CSV compatibility

The original export schema was checked against a private 27-session sample. Its first seven columns are `Start Date`, `Start Time`, `End Date`, `End Time`, `Duration (minutes)`, `Duration (hours)`, and `Source`.

This implementation preserves that prefix and appends `Workload`, `Color`, `Session ID`, `Start`, and `End`. The appended timestamps preserve precision and disambiguate daylight-saving transitions. The export does not add a Status column. Its filename follows `punchin-export-yyyy-MM-dd.csv`.

The original sample remains under the ignored `Reference/Private/` directory. The committed tests use synthetic records. The sample's individual sessions do not enter repository documentation or fixtures.

## Build and test

Run these commands from the repository directory. Use a simulator name available in your Xcode installation.

```sh
xcrun simctl list devices available

xcodebuild -project Punchino.xcodeproj \
  -scheme Punchino \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO build

swift test

xcodebuild -project Punchino.xcodeproj \
  -scheme Punchino \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO test

xcodebuild -project Punchino.xcodeproj \
  -scheme PunchinoWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 12 (46mm)' \
  -derivedDataPath DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO test
```

Simulator validation uses ad-hoc signing so the App Group entitlement takes effect. CLI inspection verified registration of `group.com.xuming.PunchinoColor` in the iPhone simulator. This simulator check does not register identifiers in an Apple developer account.

Do not force a global `-sdk iphonesimulator` for the combined app scheme. Xcode must select the watch simulator SDK for embedded watch targets.

Package tests cover midnight and daylight-saving boundaries, overlap handling, validation, merge conflicts, deletion records, CSV import/export, statistics, repository persistence, and custom-color contrast. The expanded iPhone suite checks workload selection, persistence, manual editing, three-tab navigation, Settings, focus modes, statistics ranges, and real-editor white/black workloads. The revised Watch cases cover Crown selection, punch in/out, read-only totals, persisted recorded time, black/white readability, and matched-model reference captures. UI tests use isolated repositories and disable synchronization services. They attach screenshots to their test results. Separate native widget checks use synthetic workload definitions and normal Watch punch-in.

Validation status on November 7, 2026:

- All 66 package tests passed, including six custom-color contrast tests. Measured contrast checks use opaque base colors and representative neutral surfaces.
- Full phone, Watch, iOS-widget, and watchOS-widget typechecks passed before the native Watch layout revision. Their commands, run-specific hashes, and logs appear in `Evidence/ConnectivityProbe/ContrastCorrection/ValidationLogs`.
- Ad-hoc simulator signing and App Group registration passed verification. Both original reference-icon catalogs passed isolated asset compilation.
- The current unsigned generic device build passed with embedded Watch/widgets and `Config/CloudSync.xcconfig`. `Evidence/WatchActiveFinalValidation/device-build.json` records the native Watch active-screen correction and 31 matching product/config hashes. All source timestamps precede completion. Its build log is adjacent. Earlier build manifests remain historical.
- The current component audit passed 82 hash checks across the generic build, final Watch run, relevant phone captures, and Shared probes. `Evidence/WatchActiveFinalValidation/current-component-hash-audit.json` records each check and its scope.
- The three focused layout/workload/persistence cases passed in 84.421 seconds before the text-helper refinement. They include the absolute 486.7pt anchor check. Result: `TestResults/LiveTrackLayoutFinal.xcresult`.
- The current dark/Medium/Bold reference case passed in 41.287 seconds. Its active blue capture, raster measurements, and current source hashes are in `Evidence/ReferenceActiveLive`.
- The current custom-color/history case passed in 119.399 seconds. It covers punch controls, day/week history, timeline, editor choices, and relaunch in both appearances. Its 14 inspected captures and run-specific hashes are in `Evidence/CustomColorLiveTrackFinal`.
- The three-case native 26.5 Watch run passed: 3 tests, 0 failures, 117.068 seconds, `TestResults/Watch26MatchFinal.xcresult`. Its captures and pre-alignment hashes are in `Evidence/Watch26MatchFinal`. It covers Crown selection, persisted recorded time, read-only Totals, custom colors, and the reference capture.
- Before the active-screen correction, the aligned 45mm reference check passed: 1 test, 0 failures, 8.343 seconds, `TestResults/Watch26AlignedFinal.xcresult`. Final captures, measurements, and source hashes are in `Evidence/Watch26AlignedFinal`. Only Totals trailing padding changed after the three-case run.
- Before the active-screen correction, the 46mm fitting check passed: 1 test, 0 failures, 8.255 seconds, `TestResults/Watch46FittingFinal.xcresult`. Captures and matching source hashes are in `Evidence/Watch46FittingFinal`. It establishes fitting, not an original 46mm visual match.
- The current four-case Watch run passed: 4 tests, 0 failures, 133.646 seconds, `TestResults/WatchActiveFinal.xcresult`. Its 14 captures and unchanged source hashes are in `Evidence/WatchActiveFinal`. It covers Crown selection, a real isolated one-minute session, saved totals after relaunch, read-only Totals, black/white workloads, and active/idle reference captures.
- The current 46mm fitting run passed: 2 tests, 0 failures, 25.374 seconds, `TestResults/WatchActive46mmFinal.xcresult`. Its idle/active captures are in `Evidence/WatchActive46mmFinal`. This check establishes fitting, not an original 46mm match.
- The independent static audit in `Evidence/WatchActiveFinalValidation/independent-visual-audit.json` records matching active geometry and invariant masks. It preserves small raster/glow residuals. Trial3 differs from the current source only in indentation and comments, as the exact-hash reconstruction and source diff show.
- Earlier two-case runs in `Evidence/WatchDisplayContrastFinal` and `Evidence/Watch45mmFinal` predate the native Watch correction. Their history-navigation checks describe deleted UI and are historical.
- The earlier full phone suite passed 14 tests in 324.063 seconds on iPhone 16 Plus/iOS 26.5. Those captures predate the active-layout correction. There are 15 unique phone cases across completed runs, including the separate custom-color case.
- Current Shared-code probes verified two equal ended sessions with no active timer, short-lived and retained stop delivery, and timeout preservation. Their current hashes are in `Evidence/ConnectivityProbe/ContrastCorrection/validation-summary.json`.
- Earlier actual Smart Stack captures and native widget stops are in `Evidence/NativeWidgetsFinal`, `Evidence/NativeWidgetBarrier`, and `Evidence/NativeBlackWidget`. Their source hashes remain historical after the display-only refinement. `Evidence/LiveTrackFinalValidation/display-review.json` records that distinction.
- The latest signing/device check found zero valid identities and simulator development devices only. The original iPhone was inspected through Mirroring.
- The user reported that Watch Mirroring displays the Watch directly on the iPhone. The Mac's iPhone Mirroring view displayed only the settings switch after retry in this session. Native Track/Totals PNGs later supplied through iPhone Photos enabled the private comparison. This observation does not establish a general OS restriction.
- Signed installation, physical paired synchronization, live iCloud/APNs, background latency, and large-history transfers remain unverified.

The live original app differs from the older App Store images. The audit prioritizes live observations. Earlier automated runs used iOS/watchOS 27.2. The closest available iPhone runtime is 26.5, while the original phone uses 26.6.2. Current evidence does not establish identical pixels across those environments.

## Optional screenshot fixture

Add `--demo-data` to the iPhone scheme's Run arguments for populated calendar screenshots. The app then uses a separate temporary repository and disables synchronization services. Each demo run resets that fixture. Demo sessions never enter production history. Disable the argument to return to normal storage.

`--reference-empty` uses a separate empty reference fixture. Its view modifier sets Medium text and Bold Text on to match the inspected phone. Production follows the device's system settings. The modifier does not change system settings.

## Enable iCloud for a signed build

The default `Config/Base.xcconfig` sets `PUNCHINO_CLOUD_SYNC_ENABLED = NO`. `Config/CloudSync.xcconfig` enables CloudKit and selects `Config/Cloud.entitlements`.

1. Register the four app and extension bundle identifiers with your Apple team.
2. Register the App Group `group.com.xuming.PunchinoColor`.
3. Enable that App Group on all four identifiers.
4. Register the iCloud container `iCloud.com.xuming.PunchinoColor`.
5. Enable CloudKit for the signed app and extension identifiers.
6. Associate the container with those identifiers.
7. Enable Push Notifications for provisioning profiles that use `Cloud.entitlements`.
8. Build with your team and the CloudSync configuration.

```sh
xcodebuild -project Punchino.xcodeproj \
  -scheme Punchino \
  -destination 'generic/platform=iOS' \
  -xcconfig Config/CloudSync.xcconfig \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates build
```

The identifiers are examples for this project. If your team cannot register them, replace them consistently in the generator, entitlements, Info.plist files, `SnapshotRepository.swift`, and `CloudSync.swift`. Regenerate the project after changing its generator.

Sign into the same iCloud account on your devices. The app stores snapshots in a private CloudKit zone. It refreshes after changes, when the app becomes active, and periodically while active. Offline changes remain on the device until synchronization succeeds. Settings > Debug Info displays CloudKit and refresh information. Its Refresh control requests an update. Background delivery and exact synchronization latency require device validation.

The Cloud configuration now creates a private record-zone subscription for silent changes. The iPhone and Watch delegates refresh only for notifications from the expected private subscription. Notification registration does not request alert permission. Default local builds and isolated fixtures do not initialize CloudKit or register for APNs.

The iPhone configuration includes `fetch` and `remote-notification` background modes. The Watch configuration includes `remote-notification`. The sync engine skips an upload when its merged snapshot already matches the device's server record. This prevents unchanged uploads from generating repeated push updates.

The unsigned Cloud configuration compile check uses:

```sh
xcodebuild -project Punchino.xcodeproj \
  -scheme Punchino \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/punchino-device-build \
  -xcconfig Config/CloudSync.xcconfig \
  CODE_SIGNING_ALLOWED=NO build
```

The current unsigned build includes the phone and Watch active-screen corrections, custom-color contrast, and read-only Watch Totals. `Evidence/WatchActiveFinalValidation/device-build.json` records its source hashes and exact command. Its build log is adjacent. Silent delivery, background scheduling, account provisioning, and physical paired-device synchronization still require signed devices.

CloudKit development and production environments are separate. A distribution build also requires appropriate production schema/container setup and distribution entitlements. The supplied Cloud entitlement file uses the development push environment.

## Project files

- `Phone/`: iPhone screens and Siri actions.
- `Watch/`: watch screens and scrolling workload selection.
- `Widgets/`: WidgetKit extensions for both platforms.
- `Shared/`: models, storage, time calculations, CSV, synchronization, and shared state.
- `Tests/`: core tests, iPhone UI tests, and Watch UI tests.
- `Config/`: Info.plist files, build settings, and entitlements.
- `Reference/`: public source images and the reference audit. These files do not enter the app bundle.
- `Scripts/`: project generation and an unused exploratory icon renderer.

The committed Xcode project opens without the generator gem. To regenerate it after adding source files:

```sh
gem install xcodeproj --user-install
ruby Scripts/generate_project.rb
```

The generator recreates the Xcode project. It also resets manual signing-team changes. Keep shared project changes in the generator.

The app icons are unchanged copies of the opaque 1024px App Store PNG. Source URLs and hashes appear in `Reference/icon-assets.json`. Restore the catalog copies with:

```sh
cp Reference/original-icon-legacy.png Phone/Assets.xcassets/AppIcon.appiconset/AppIcon.png
cp Reference/original-icon-legacy.png Watch/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

The exploratory `render_icon.swift` script is not part of the current icon workflow. It generates a different icon.

## Remaining reference limits

The phone audit restored Home, November, and Build Momentum before the later Watch inspection. One approved phone test record and one approved Watch test record remain in the original history. The user confirmed that the Watch test stopped. No original session was deleted. The live audit covers all three focus modes, calendar borders, week details, Debug, CSV pickers, editing, statistics empty captions, and active tracking. The earlier private original CSV sample verified the schema and selected aggregates.

The exact rolling cutoff within a boundary day remains inferred. Slider endpoints of 0–80 weekly hours and 0–24 daily hours follow observed geometry. The original sliders were not changed to those endpoints.

The completion audit found a custom-color readability gap in history and editor markers. That correction passed the expanded UI test. The later approved active-session inspection found a different current layout from the older promotional screen. The correction preserves the idle center, omits active totals, uses MM:SS below one hour, and displays a vertical IN tab icon. The focused layout, matched reference capture, and custom-color/history checks passed.

Original onboarding and destructive confirmation dialogs remain untested live. Phone pulse timing, glow, and exact font weights remain inferred from captures. Original Watch idle Track, active Track, and Totals now have native-image evidence. The user completed the approved short Watch test. Ring motion remains unobserved. The agent did not operate the original Watch punch controls.

The physical Watch's exact Dynamic Type category, native clock rendering, and the small Today-unit weight residual remain explicit limits. Signed device validation requires an Apple development team, provisioning, and connected development devices. Signed paired-device synchronization, live iCloud/APNs, general background latency, and large-history file transfers remain unverified. Native rendering can differ across OS versions. These limits prevent a claim of exact pixels or complete equivalence.
