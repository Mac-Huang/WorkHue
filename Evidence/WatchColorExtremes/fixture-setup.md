The focused Watch UI test uses `--ui-testing --color-extremes`. Both arguments are required for the color fixture. Normal launches ignore the color flag.

A fresh isolated temporary repository contains Black (`000000`) and White (`FFFFFF`) workload definitions. It contains no preloaded sessions. The test selects and starts each workload through the real Watch wheel. It stops each session through the real Track control.

The `--preserve-data` relaunch reuses the repository. It does not seed the definitions again. Background sync remains disabled for this isolated fixture. The ordinary `--ui-testing` fixture retains its original preset workloads.

The native Smart Stack check uses a different setup on the approved disposable simulator pair. The preload utility calls the actual Shared `SnapshotRepository.update` API against the Watch app's normal App Group repository. It inserts only missing Black and White workload definitions. It verifies that the session array remains unchanged. It does not seed sessions or create extension-only state.

The native check launches the normal Watch app without test arguments. It selects Black with the Digital Crown and starts the session through the normal confirmation button. The installed widget reads that real saved session. The check then terminates the Watch app and taps the native widget's status circle.

The approved Watch is `F0B67AC3-174C-4ED3-8F0C-B882CF29B587`. Its approved paired phone is `1373B48D-7ECF-4E80-994F-B9FCD970AD3D`. All native fixture data stays on these task-created devices. The existing Pro Max/Watch pair remains unchanged.

The preload source, before/after snapshots, and setup validation are in `Evidence/NativeBlackWidget`. The native diagnostic remains outside the normal test project. The normal Watch target contains only its workload regression and focused color test.
