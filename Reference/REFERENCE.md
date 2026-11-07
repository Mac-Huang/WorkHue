# Punchino reference audit

Source: [Time Tracker – Punchino](https://apps.apple.com/us/app/time-tracker-punchino/id6757963430).
Inspection date: November 7, 2026.

The listing identifies version 1.04. Its screenshots display promotional compositions, except the six watch captures.
Screenshots establish visible layout and labels. They do not establish complete behavior or pixel-perfect dimensions for every device.
Promotional screenshots remain reference-only. The icon provenance section documents the original icon copies in the platform asset catalogs.

A later audit inspected the original app that the user opened in iPhone Mirroring. The live observations below supersede conflicting details in the promotional images. The original phone was verified as an iPhone 16 Plus on iOS 26.6.2. Its Default Display Zoom, Medium text, and Bold Text on settings were inspected without changes. The installed app version remains unverified. Earlier simulator validation used iOS/watchOS 27.2. An iOS 26.5 runtime from Apple's official catalog is now available because 26.6.2 was unavailable. The full iPhone 16 Plus suite passed on iOS 26.5, with Medium content size and the reference-only Bold modifier for reference captures.

## Icon provenance

The app catalogs now use the original public [App Store icon artwork](https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/20/b6/5a/20b65a45-0b92-7b00-8530-1b920bf0101c/AppIcon-0-0-1x_U007ephone-0-1-sRGB-85-220.png/1024x1024bb.png). The retrieved file is an opaque RGB PNG at 1024 × 1024 pixels. It retains the original circular face and vertical glyph. It covers the full square without transparent corners.

`Phone/Assets.xcassets/AppIcon.appiconset/AppIcon.png` and `Watch/Assets.xcassets/AppIcon.appiconset/AppIcon.png` are unchanged copies of `Reference/original-icon-legacy.png`. No raster edit or added mask was applied. All three files have SHA-256 `009143da0c81f85aea104c7119a15bef7580ea2faf7380316bbe07dd0866f71b`.

The newer `Placeholder.mill` artwork has transparent, pre-masked corners. It remains reference-only as `original-icon-placeholder.png`. Both direct raw-image endpoints returned HTTP 403. The selected App Store thumbnail endpoint returned the suitable square PNG. `icon-assets.json` records both URLs and the copy provenance. Both platform catalogs passed isolated `actool` compilation with these exact copies.

## Live audit on November 7, 2026

The user requested meticulous comparison with the installed original. The live audit found screens and controls that the initial App Store images did not display. It now covers all three focus modes, calendar borders, week details, Debug, CSV pickers, manual editing, and statistics empty states. Completed automated checks pass. The latest device/runtime checks appear in the validation section. Remaining live/reference limits appear below.

| Area | Observed in the original | Implemented | Verified so far |
|---|---|---|---|
| Main navigation | Three native tabs: Home/calendar, Statistics/chart.bar.fill, and OUT/circle. Titles collapse to inline titles while scrolling. The toolbar uses `gear`. | Native TabView, a NavigationStack per tab, large titles, and toolbar gear. | Three-tab navigation and state preservation passed UI tests. Reference appearance was captured. |
| Focus selection | Your Focus contains Find Balance, Build Momentum, and Just Observe. Their descriptions are Protect your personal time, Achieve more, track progress, and Awareness without expectations. | Three persistent focus modes with these labels and descriptions. Their symbols are sun.horizon.fill, figure.run, and eye.fill. | All three focus switches and their statistics card titles passed UI tests. The implemented text matches the live audit. |
| Focus targets | Balance uses Your Limits / Weekly Limit / Daily Limit. Momentum uses Your Goals / Weekly Goal / Daily Goal. Observe uses Your Targets / Weekly Target / Daily Target. Observe retains both controls. | Focus-specific labels with persistent target values. | The reference-appearance capture passed. The implemented target labels match the live audit. |
| Accent colors | Six colors: green, blue, teal, purple, pink, and orange. The selected circle is larger. Other circles have approximately half opacity. | Six choices with matching selection treatment. | The six choices and selection treatment were inspected live. Native OS rendering remains a general limitation. |
| Goal controls | Sliders use half-hour increments. Endpoints are inferred from geometry, not verified by changing the original controls. | Sliders use 0.5-hour increments, with 0–80 weekly and 0–24 daily endpoints. | Half-hour steps observed directly. Endpoint inference remains explicit. |
| Data controls | Export CSV. Import includes Replace existing sessions, initially off, and Import CSV. | Native export sheet, document import, and optional replacement. | Original pickers were inspected live. Sixteen CSV package tests and the native export-sheet UI test passed. Import uses the native document picker. |
| Debug information | Debug Info opens a native pushed screen. | Native navigation to Debug Info. | Original Debug layout inspected live. Implementation exposes refresh, CloudKit, monitoring, sessions, and storage information. |
| Home goal cards | All three focus modes display Today and Week, then a progress bar, then a compact current/target footer such as 0m / 3h 0m. | Matching order and compact totals. | All three original focus presentations were inspected live. |
| Calendar state | Empty current-week dates have an accent outline. Balance uses red over-limit borders. Momentum uses green. Observe omits those borders. Future dates are dim and disabled. Today has a white outline in dark mode. | Focus-specific, current-week, future, and today styling. | Equal square calendar columns passed a UI test. All three focus border rules were inspected live. |
| Idle Track | The verified iPhone 16 Plus model supports a 220pt ring, 10pt stroke, and 56pt OUT text. Earlier 200/9/48 estimates used the wrong model. The idle screen has no totals cards. | Corrected 220pt ring, 10pt stroke, 56pt OUT text, and no idle totals. | Idle controls, hidden totals, and two-tap workload selection passed UI tests. |
| Active Track | The current live screen keeps the idle center. It has a 200pt core, approximately 220pt middle ring, pulsing outer ring, MM:SS timer below one hour, Started row, and no totals. Its IN tab icon is a vertical rounded line. | Centered control with 230–240pt outer pulse, compact timer, Started row, and native poweron tab icon. Added workload name/color appears below Started without moving the control. | The original was inspected during one approved session. Absolute-center, compact-timer, no-totals, native-tab, reference-appearance, and custom-color/history checks passed. |
| Empty day | Timeline displays No Sessions and No time logged for this day. Delete All Sessions stays visible but disabled. | Matching empty state and disabled deletion control. | The original empty day was inspected live. The implementation matches its observed text and disabled deletion state. |
| Manual session | New Session initially has equal start/end times. Save stays disabled. Session Ended permits an active session. Source initially displays iPhone. Navigation uses a back chevron. | Native pushed editor with matching initial state, ended toggle, source, and save validation. | New Session save validation, the ended toggle, selected workload, and active-session source passed the earlier full UI suite. |
| Statistics ranges | D, W, M, 6M, Y. Chart titles are Last 24 Hours, Last 7 Days, Last 30 Days, Last 6 Months, Last 12 Months. Default selection is W. | All five ranges and corresponding chart buckets. | Seventeen statistics package tests passed. All five range controls and headings passed UI tests. |
| Statistics cards | Chart, period comparison, focus-specific tracking/patterns, Outliers, and Summary. Dark cards are approximately #0B0B0D, with 12pt corners, 16pt padding, and 24pt spacing. | Chart, comparisons, tracking/patterns, outliers, and summaries with matching structure. | Calculations and focus card titles passed tests. Native OS rendering remains a general limitation. |
| Momentum statistics | Progress Tracking displays Goals Hit and Average Over Goal. Outliers display Most Productive and Needs Improvement, with the chart bucket period appended. | Matching labels and symbols. | Observed Year example reproduced by a deterministic test. Focus card switching passed a UI test. |
| Balance statistics | Balance Tracking displays Days Within Limit and Average Under Limit. Outliers display Busiest and Best Balanced, with the bucket period appended. | Matching labels and symbols. | Observed Year example reproduced by a deterministic test. Focus card switching passed a UI test. |
| Observe statistics | Patterns displays Most Active Day with a calendar symbol, and Typical Range with a purple waveform symbol. Target lines remain visible. | Weekday aggregation, indexed quartiles, and Longest/Quietest outliers. Target lines remain visible. | Observe's Longest/Quietest outliers and compact quartile range were inspected live. The matching model uses synthetic tests. |
| Statistics summary | A 2×2 grid displays Average, Total, Periods Worked, and Sessions. Average uses nonzero chart buckets. | Matching summary metrics and labels. | Package tests cover totals, bucket counts, cross-midnight sessions, and active/deleted sessions. |
| Week detail | Day rows are read-only. A crossing session keeps its full duration in its row, while the selected week's total clips at week boundaries. Goal and remaining time appear in every focus mode. | Matching read-only rows, full row duration, clipped totals, and target/remaining display. | Original inspected in all focus modes. Shared time calculations have synthetic boundary tests. |
| Statistics empty cards | Tracking/Patterns use No sessions to analyze. Outliers use No sessions in selected range. Summary uses No sessions to calculate averages without an icon or zero grid. | Exact captions with separate raw-session and chart-bucket empty conditions. | Original captions inspected. Empty analysis/summary captions and icon presence passed UI tests in all three focus modes. |
| Watch flow | Native idle Track, active Track, and Totals PNGs display the Series 9 45mm layout. The user reported that Today does not open a list. Public images also display widgets and a Utility-face complication. | Track and read-only Totals, plus the added workload wheel. Definitions stay on iPhone. Unsupported Watch history, Settings, and editor code were deleted. The Utility slot uses accessoryInline. | Native 26.5 measurements match the measured idle/active geometry and invariant glyph masks. The current four-case run and two-case 46mm fitting run passed. Earlier history tests describe deleted UI. Small raster residuals, motion, physical synchronization, and exact Utility-slot rendering remain unverified. |
| Added custom colors | The user requested predefined workload colors. This is an addition to the reference. | Readable phone/Watch ink and subtle outlines for extreme custom colors, including history markers, timeline bars, and editor swatches. Stored values and default styling stay unchanged. | The expanded real-editor phone case passed punch in/out, day/week history, timeline, and editor-choice checks in both appearances. Fourteen screenshots were inspected. Watch color readability and the native Black widget stop also passed. Stored black remained 000000. |

### Current live Active Track inspection

The user approved one short session in the original app. On November 7, the session ran from 10:56 to 10:57 AM and displayed as 1 minute in day history. It remains in the original history. No original session was deleted. The phone audit restored Build Momentum, blue accent, a 21-hour weekly goal, and a 3-hour daily goal. It also restored Home and November before the later Watch inspection.

The active screen was inspected at 00:03, 00:40, and 01:11. These live observations supersede the older promotional active layout and its earlier replica captures.

- The active and idle control share a center. The mirrored center was approximately (348, 829) pixels within a phone viewport spanning x=17–680.
- The filled core measured approximately 200pt. The middle ring measured approximately 220pt. The outer ring changed size between captures.
- The live elapsed label used MM:SS below one hour. The older public example supports H:MM:SS above one hour.
- The Started row sat below the centered control. No Today, Week, or Month cards appeared, including after an attempted scroll.
- The selected IN tab used a single vertical rounded line. The native poweron symbol reproduces this shape.

The implementation uses 56pt rounded IN text, a 24pt semibold monospaced timer, and a 230–240pt outer pulse. Exact font weight, pulse timing, and glow are inferred from the captures. The 1.8-second animation duration per direction is an approximation. Reduce Motion disables the pulse. The pulse stays static during UI tests for stable measurements.

The requested workload color/name appears below Started. This addition does not move the original control or Started anchor. Older `Evidence/ReferencePlus` and `Evidence/PhoneIOS26` active captures display the superseded promotional layout.

`Evidence/ReferenceActiveLive/measurements.json` records the current dark/Medium/Bold capture on iPhone 16 Plus/iOS 26.5. Idle and active controls both center at (215, 486.667)pt. The viewport-derived original center is approximately (214.676, 487.069)pt. The difference is less than 0.5pt on each axis. The replica Started ink spans y=622.333–638.333pt. Its center projects to approximately raw y=1049.9, close to the observed approximate y=1052 if that observation meant the row center. The original top-versus-center ambiguity remains unresolved. The manifest retains current source hashes and the native line-icon measurements.

A reference-only modifier applies Medium text and Bold Text for `--reference-empty`. Production follows system preferences. It does not change the device's settings.

### Native Watch Track and Totals inspection

The physical reference is an Apple Watch Series 9 (GPS), 45mm, running watchOS 26.6 (23U67), with Bold Text on. The exact physical Dynamic Type category remains unknown. Native idle Track, active Track, and Totals PNGs arrived through iPhone Photos at 396 × 484px. Their images, values, and provenance stay in ignored `Reference/Private`. This document records data-independent geometry and glyph facts only. The user recorded one approved short Watch session and confirmed that it stopped. Its history record remains intact. The agent did not operate the original Watch punch controls.

The user reported that tapping the original Today card leaves the same screen visible. The implementation now keeps Track and read-only Totals. Unsupported Watch history, Settings, and editor screens/code were deleted. The added picker directs workload definition and editing to iPhone. Earlier tests that opened Watch history remain historical evidence of the prior implementation.

The [environment record](../Evidence/WatchOS26Environment/environment.json) records the selection from [Apple's simulator catalog](https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex). Its catalog snapshot did not offer watchOS 26.6. Xcode downloaded watchOS 26.5 (23T570) and booted a Series 9 45mm simulator. The optional runtime verification command returned `-67054`, reporting a missing or invalid sealed resource. Both normal boot commands returned exit code 0 without a bypass. The record preserves that diagnostic and the normal boot logs.

The native 26.5 baseline reproduced the earlier 27.2 geometry/colors. An app-root legibility override did not reach the relevant page leaves. The corrected reference fixture reaches those leaves and records xLarge/Bold with resolved point sizes. These diagnostics do not identify the physical Watch's exact Dynamic Type category. The native system clock sits outside the app-view override.

The data-independent native comparison established these targets:

- The Track ring is 176px across with a 6px stroke. The Today strip is 356 × 58px at x20/y360. The revised ring, OUT text, Today label, and strip match their measured geometry.
- Totals cards span x4–392px. Their y bounds are 84–184, 194–294, and 304–404, with 5pt gaps. Background RGB is 34/34/35 and the revised corner contours match.
- Totals labels have foreground RGB 154/154/161. Today, This Week, and This Month ink bounds and binary masks match the original. Residual raster color differences are at most one channel level.
- The flat accent is RGB 0/145/255. Synthetic captures reproduce this style without using the user's numerical totals.
- The invariant Totals suffix m matches its 17 × 18px shape and 179px mask area. After the final 0.5pt trailing adjustment, all three suffix positions also match. An independent comparison found identical right edges and vertical bounds.
- The Today duration unit remains slightly lighter: at the same 16 × 16px size, its mask area is 181 versus the original's 199. The closer size-matched choice is retained as an explicit residual.

All public simulator captures use synthetic data. No private Watch total was seeded into a fixture or copied into public evidence.

The later active capture established these additional targets:

- The active core is 164 × 164px, within a 208 × 208px halo centered at (197.5, 207.5)px.
- The IN ink spans 48 × 37px. Timer ink spans 78 × 19px in the captured five-character format. The colon spans 6 × 15px.
- The Started icon spans 19 × 19px. The invariant text prefix spans 82 × 16px. The row uses proportional text and foreground RGB 141/141/147.
- Timer ink on the original blue core corresponds to black at approximately 0.7 opacity. IN remains opaque black.

The implementation preserves workload-specific hue. It applies the observed timer opacity only when the calculated composite contrast remains at least 4.5:1. Other colors and reduced-luminance mode keep opaque timer ink. An exact-source harness checked 1,482 color cases in normal mode and again in reduced-luminance mode. Its results appear in `Evidence/WatchTimerInkValidation`. The user did not notice ring motion. The native still image does not establish pulse behavior.

The earlier [aligned 45mm record](../Evidence/Watch26AlignedFinal/validation.json) preserves idle/Totals measurements and reference-only environment diagnostics before the active-screen correction. The current four-case run is in [Evidence/WatchActiveFinal](../Evidence/WatchActiveFinal). It covers both reference states, Crown selection, persisted time, and extreme colors. The current larger-screen run is in [Evidence/WatchActive46mmFinal](../Evidence/WatchActive46mmFinal). It establishes fitting on watchOS 27.2, without an original 46mm comparison.

### Shared-code transport verification

`Evidence/ConnectivityProbe/ContrastCorrection/SharedSequence/validation.json` records the current bidirectional simulator run of the actual Shared sources. Its Shared hashes match the current files. Earlier manifests remain preserved. The phone started Work. The Watch received and stopped it, then started Study. The phone received and stopped Study. Both stores converged to two ended sessions, with all recorded fields equal and no active timer.

The harness is reproducible through `Tests/ConnectivityProbe/README.md`. It uses isolated temporary app identifiers and repositories. CloudKit stays disabled. It does not read production data or change pairing. The runner uninstalls its probe apps.

This result covers foreground, small-history transport through the actual WatchConnectivity implementation on paired simulators. It does not establish physical behavior, background latency, file/user-info transfer paths, App Group persistence, CloudKit, or APNs.

The widget action retains its local store while awaiting `finishPendingPairedSync`, with a default three-second activation timeout. Successful queue acceptance means WatchConnectivity accepted the snapshot. It does not acknowledge counterpart delivery. A timeout or unavailable counterpart leaves the stop saved locally and reports pending/unavailable paired sync.

The current lifetime probe verified short-lived and retained-store delivery plus preservation of the local stop after timeout. Its evidence is `Evidence/ConnectivityProbe/ContrastCorrection/WidgetLifetime/results.json`. This isolates store lifetime in a foreground process compiled with `PUNCHINO_WIDGET`. It does not by itself establish a WidgetKit host's lifetime.

The earlier zero-timeout case queued after activation was already complete. The new case exercised the timeout fallback and returned in approximately 4.9ms. The local Watch stop remained saved, status reported Paired sync pending, and counterpart delivery was not reported. The validation summary records this expected difference from delivered cases.

Actual WidgetKit execution was checked separately. `Evidence/NativeWidgetBarrier/validation.json` records a successful tap on the installed Smart Stack stop circle after terminating the Watch app. The app remained `notRunning` and was not reopened. The phone and Watch App Group files converged to equal session fields and identical snapshot hashes, with zero active timers and CloudKit disabled. The proof is the stored counterpart state, rather than queue success alone. General physical-device and background scheduling limits remain.

`Evidence/NativeBlackWidget/validation.json` records the earlier native black-color path. The fixture seeded workload definitions and no sessions. It preserved nine existing sessions. The normal Watch wheel and confirmation created the session. Its stored hex remained `000000`.

A tap on the actual native widget then stopped it while the Watch app remained `notRunning`. The paired phone session matched every recorded field and the active count was zero. The native outlined-circle screenshot is legible.

Its original source hashes remain unchanged. The later display-only correction changed Models, Watch labels, and widget text. Current UI and transport checks are recorded separately.

### Observed statistics calculation details

- D uses 24 hourly chart buckets through the current hour. Its displayed hours advance with the clock.
- W uses seven calendar-day chart buckets ending today. M uses thirty calendar-day buckets.
- M ticks align with configured week starts. 6M ticks use dated month boundaries. Y uses month abbreviations.
- 6M uses weekly buckets across six months. Y uses monthly buckets across twelve months.
- Empty buckets do not create zero-height bar marks. The native Y scale includes zero and retains the target rule.
- Chart target lines use the daily target for D/W/M, the weekly target for 6M, and four weekly targets for Y.
- Tracking metrics compare each nonzero bucket with the daily goal/limit, even for weekly or monthly buckets.
- Momentum averages excess only across buckets that reach the goal. Balance averages remaining allowance only across worked buckets within the limit.
- Observe's Typical Range uses sorted positive bucket values at integer indices `n/4` and `3*n/4`.
- The range format has one trailing h and no spaces around its hyphen. Equal bounds produce one value.
- Observe outliers use Longest and Quietest, followed by the bucket unit. Their symbols are moon.stars.fill and bolt.fill.

The original can have an empty W chart while Summary still counts sessions. Live inspection displayed a nonzero raw total and two sessions, with zero worked chart buckets and a zero chart average. Patterns retained the active weekday and displayed N/A for Typical Range. Tracking retained 0 / 0 rows. Outliers remained empty.

The implementation therefore separates raw and chart intervals. Raw totals, session counts, and weekday patterns use rolling windows through now. These windows are 24 hours, seven calendar days, thirty calendar days, six months, and twelve months. Buckets, averages, indexed ranges, progress metrics, and outliers use the chart intervals.

The private sample supports this distinction. It cannot distinguish exact boundary times within the extra day, or every raw overlap-clipping choice. Calendar-based rolling cutoffs remain a documented inference. Calendar comparisons continue to clip overlapping sessions at their period boundaries. The original previous-week result verified clipping rather than whole-session duration sums.

### Original CSV verification

The official [product page](https://jwahlmueller.com/apps/punchino/) and [support page](https://jwahlmueller.com/apps/punchino/support) do not publish a schema. A later private original export provided direct schema evidence.

The original seven columns are `Start Date`, `Start Time`, `End Date`, `End Time`, `Duration (minutes)`, `Duration (hours)`, and `Source`. The implementation preserves this prefix. It appends workload/color, session ID, and precise ISO timestamps. It does not append a Status column. The filename follows `punchin-export-yyyy-MM-dd.csv`.

The 27-record original sample verified parsing and selected aggregate results. It stays in `Reference/Private/`, which `.gitignore` excludes. Committed tests contain synthetic data. This audit does not reproduce the private rows.

### Credit and evidence scope

The original Settings footer credits Johann Wahlmueller and Hong Kong. The implementation retains that footer as a visual reference. Its source code is an independent implementation. The app icon reuses the original public artwork with the provenance above. The audit did not retrieve original source code or an internal data implementation.

The live audit expands the initial public audit. It does not establish identical rendering across OS versions or unobserved behavior. Remaining limits include original onboarding, original destructive confirmations, Watch ring motion, signed paired/iCloud behavior, and native OS differences.

## Current validation and remaining limits

Automated results describe the current implementation. They do not establish exact pixels or complete equivalence with the original. The remaining live/reference limits appear below.

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

The sync model preserves timer-start boundaries across stop, deletion, and merge order. An older offline timer closes when a later timer start arrives, even if that later session already ended or was deleted. A completed CSV import does not create a timer boundary that stops an unrelated live timer. Regression tests cover these cases and legacy records.

Cloud code now creates a private zone subscription for silent pushes. Both app delegates filter notifications to the expected private subscription. They register without an alert-permission prompt only when the Cloud configuration is enabled. Local builds and isolated fixtures avoid CloudKit initialization and APNs registration. Unchanged device snapshots skip uploads to prevent push loops. The iPhone configuration enables `fetch` and `remote-notification`. The Watch configuration enables `remote-notification`. These code paths compiled, but actual silent delivery remains unverified.

The original app's iPhone Mirroring connection recovered during the audit. The phone audit restored Home, November, and Build Momentum. One approved phone test record and one approved Watch test record remain in the original history. The user confirmed that the Watch test stopped. No original session was deleted.

The completion audit found a custom-color readability gap in day/week history and editor/timeline markers. That correction passed the expanded phone UI test. The later approved active-session inspection found a different current layout from the older promotional screen. The focused layout, matched reference capture, and custom-color/history checks passed. Exact parity remains unverified for the limits below.

Remaining limits:

1. Active-ring pulse timing, glow, and exact font weights remain inferred from live captures.
2. Original onboarding and destructive confirmation dialogs remain unseen.
3. Native original Watch idle Track, active Track, and Totals were inspected. The user completed the approved short Watch test and confirmed that it stopped. Ring motion remains unverified. The exact physical Dynamic Type category, native system-clock match, and Today duration-unit weight residual remain unresolved.
4. Signed paired-watch synchronization, iCloud, APNs, general background latency, and large-history file transfers remain unverified. Signed device checks require an Apple development team, provisioning, and connected development devices.
5. The exact raw-range cutoff cannot be resolved from the private sample.
6. Native rendering can differ across device and OS versions.

## Public screenshot evidence: iPhone

These older promotional details yield to the current live observations above.

### Overview

References: 02, 04, 05, 06, and 07.

- The main surface is white in light mode and black in dark mode.
- A circular settings button appears at the upper right. Its gear symbol uses the accent color.
- The large, bold title is `Overview`.
- Two gray cards display `Day` and `Week`, current time versus target, a thin progress bar, and remaining time.
- The month header has a left chevron, a centered month/year, and a right chevron.
- The right chevron is gray when the displayed month is the current month.
- The calendar uses Monday-first columns and abbreviated weekday names.
- Calendar tiles have rounded corners, a day number, and a small duration when time exists.
- Time intensity changes the accent opacity. Empty tiles use pale gray.
- The legend contains eight rounded swatches and labels `0h · <2h · 2–4h · 4–6h · 6–8h · 8h+`.
- A red outline marks days with 9h in the examples. This appears to represent a daily limit.
- A dark outline marks the current day in light mode. A white outline marks it in dark mode.
- A floating bottom pill contains `Home` with a chart symbol and `OUT` with an outlined circle.
- The selected Home segment uses a gray capsule, an accent icon, and accent text.
- Visible accent variants are green, blue, purple, orange, and pink.

### Track

Reference: 01. The composition crops the right and bottom edges.

- The large, bold title is `Track`.
- The active state uses a large green filled circle with two translucent concentric rings.
- The circle contains `IN` in white and an elapsed monospaced timer beneath it.
- A gray clock symbol and `Started 06:58` appear below the circle.
- A wide gray `Today` card appears below the primary control.
- Smaller `This Week` and `This Month` cards appear side by side below Today.
- The screenshot displays elapsed time as `1:01:06` and totals as `1h 1m`.

The inactive iPhone Track control is not displayed directly.
The watch inactive control and the bottom OUT tab provide related visual evidence, but not an exact iPhone inactive screen.

### Day detail sheet

Reference: 03. The composition crops the right edge.

- A sheet has a light grouped background, rounded top corners, and a drag indicator.
- The header contains a previous-day chevron, a date such as `Jan 27, 2026`, and a next-day chevron.
- A white rounded group contains `Total Time` with a filled clock symbol and `Sessions` with a list symbol.
- A `Timeline` section displays a horizontal track with hour labels at three-hour intervals.
- The example session appears as a pale green bar from approximately 09:35 to 18:35.
- A `Sessions` section displays `09:35 – 18:35` in monospaced type and the source `Siri` beneath it.
- The same white group contains `Add Session Manually`.
- A separate white rounded button reads `Delete All Sessions` in red.

## Public screenshot evidence: Apple Watch

### Track page

References: 08 and 09. Native source size: 416 × 496 pixels.

- The background is black. The system time appears at the upper right.
- An inactive central control is a dark-gray outlined circle containing gray `OUT`.
- An active central control is a vivid green circle with two darker green outer rings.
- Active text is dark `IN`, with a monospaced elapsed timer such as `00:03` beneath it.
- A gray clock symbol and `Started 08:28` appear below the active circle.
- A dark rounded Today strip has a gray label at left and a green total at right.
- Two horizontal pagination dots appear at the bottom. The first dot is active.

### Totals page

Reference: 10.

- Three full-width dark rounded cards display `Today`, `This Week`, and `This Month`.
- Labels are gray, left aligned, and vertically centered.
- Totals are green, monospaced, and right aligned.
- The second of two pagination dots is active.

### Widgets and complication

References: 11, 12, and 13.

- A rectangular Smart Stack widget has a dark green-to-black background and a thin green border.
- Its inactive state has a large white outlined circle and white `OUT`.
- Its active state has a green filled circle and white elapsed text such as `3sec`.
- A Utility-face bottom complication displays a filled gray status dot and curved elapsed text such as `2MIN 5SEC`.

The face identification follows the Arabic dial, date placement, two upper complication slots, and bottom slot in Apple's [Utility face image](https://ipcdn-web.apple.com/assets/v2/web/bc95d025-7107-451b-a726-c020e0d27e53) and [watch-face guide](https://support.apple.com/en-euro/guide/watch/apde9218b440/27/watchos/27). This identifies the shown slot as Utility's bottom position.

Apple's [ClockKit migration guide](https://developer.apple.com/documentation/widgetkit/converting-a-clockkit-app) maps `utilitarianLarge` to `accessoryInline`. Apple also explains that inline image/text content can be flat or curved to match the face in [Go further with Complications in WidgetKit](https://developer.apple.com/videos/play/wwdc2022/10051/). `widgetLabel` on circular content serves the upper circular Infograph position, while corner content requires `accessoryCorner`. Neither is the shown Utility bottom slot. The current inline family supports that slot. Exact native placement remains to be captured.

### Native Smart Stack comparison

`Evidence/NativeWidgetsFinal` contains actual installed extension captures, rather than an in-app widget mockup. `measurements.json` records the comparison on a 416 × 496px canvas. The widget uses a 58pt circle and 45pt status/elapsed text. OUT ink bounds match the reference at 154 × 62px. Native `7sec` ink is 180 × 61px, versus 184 × 62px for the reference's different `3sec` value, with one line and no clipping.

Sampled interior background patches are close: native RGB 16/105/48 versus reference 17/106/49, and 11/93/41 versus 13/94/41. Edge/compositing samples differ more. The measurements retain those differences. The system header and card origin vary with scroll position. These results support the geometry and tone refinements without a claim of identical pixels.

## Publicly documented features

The listing describes these features. Their complete operation is not visible in the images.

- Punch in/out with haptic feedback and a live timer.
- Daily, weekly, and monthly totals.
- Standalone watch operation and multiple complications.
- Monthly heatmap history and day details.
- A configurable weekly goal and daily limit.
- Private iCloud synchronization and CSV export.
- A month carousel, empty statistics states, a week detail view, half-hour settings increments, and widget customization.

## Added user requirement

- Users define workload names and colors before recording time.
- The first iPhone punch-in tap reveals the colored workload buttons.
- A workload button starts the session and records its workload.
- The watch permits workload selection by scrolling before the session starts.

## Evidence limits

The initial App Store images do not display Settings, CSV export, a manual-session editor, a week-detail view, or an empty calendar state. The later live audit above now covers several of those flows.
The public images display older navigation and goal-card labels. The live installed app has three tabs and updated focus-specific screens.
The audit does not establish internal sync conflicts, background delivery, every deletion interaction, or exact rendering on other OS versions.
No original source code or internal storage implementation was available. Remaining uncertainty appears in the live-audit table instead of treating initial screenshot gaps as permanent limitations.

## Screenshot sources

The exact URLs and App Store JSON paths also appear in `assets.json`.

- [01: iPhone Track active promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/50/a0/61/50a06198-e98d-e380-a0d1-41b1624ea24d/Style_2.jpg/1400x2800bb.jpg) → `reference-01.jpg`
- [02: iPhone Overview green promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/e5/79/36/e57936f7-37e7-6bdc-f00e-7fbf7bb8332a/Style_1.jpg/1400x2800bb.jpg) → `reference-02.jpg`
- [03: iPhone day-detail sheet promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/a6/84/10/a6841008-c2fb-21d2-5320-a7f6bdc73d4c/Style_1__U0028No_Text_U0029.jpg/1400x2800bb.jpg) → `reference-03.jpg`
- [04: iPhone Overview blue promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/a5/09/d8/a509d8d4-079c-beb2-acc3-8f393d956f82/Style_3.jpg/1400x2800bb.jpg) → `reference-04.jpg`
- [05: iPhone Overview purple promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/6e/55/75/6e5575d5-11e2-64ee-ac3e-5a9c54aee482/Style_31.jpg/1400x2800bb.jpg) → `reference-05.jpg`
- [06: iPhone Overview orange promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/72/fe/b7/72feb7b6-bf77-3949-ddd7-10162ad13412/Style_3_2.jpg/1400x2800bb.jpg) → `reference-06.jpg`
- [07: iPhone Overview dark/pink promotional image](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/f9/62/a4/f962a496-95d7-263f-62b2-8927aab29f6e/Style_1_2.jpg/1400x2800bb.jpg) → `reference-07.jpg`
- [08: Watch Track active](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/9b/18/ad/9b18ad3b-94b6-ff38-1fb2-d988eaee5869/incoming-A8573EC6-BD7C-482E-BC01-DCE09ADC4429.png/1400x2800bb.jpg) → `reference-08.jpg`
- [09: Watch Track inactive](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/f6/a4/4e/f6a44e3d-1550-0f29-e421-5337439ba8c7/incoming-BD5DCA02-18E9-4B68-A6A3-FB742725FA75.png/1400x2800bb.jpg) → `reference-09.jpg`
- [10: Watch totals](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/6e/f6/5b/6ef65bbf-c016-63cc-199b-25ab44e8824d/incoming-7AE7B9A1-6E25-41E3-9690-71F3E6B2A576.png/1400x2800bb.jpg) → `reference-10.jpg`
- [11: Watch Smart Stack inactive](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/39/f2/3d/39f23da7-ee50-90cc-9661-e95ae5010d0e/incoming-127AD278-A884-4DD3-A06B-AA9EE686C879.png/1400x2800bb.jpg) → `reference-11.jpg`
- [12: Watch Smart Stack active](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/a6/fd/5d/a6fd5d3a-c03b-ac78-5fa1-7e1538cd0a88/incoming-4897E05A-640F-4F27-9524-C3937F2445FF.png/1400x2800bb.jpg) → `reference-12.jpg`
- [13: Watch-face complication](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/24/fc/68/24fc6804-4e1c-6ac2-eff2-b4d5a23b9662/incoming-7AF55C21-594B-4FDC-A040-47DD0C38923D.png/1400x2800bb.jpg) → `reference-13.jpg`
