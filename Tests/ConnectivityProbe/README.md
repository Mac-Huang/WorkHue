# Shared WatchConnectivity probe

This probe compiles the current `Shared/*.swift` files into two temporary simulator apps. It calls the actual `TimeStore`, `WatchSync`, `SnapshotRepository`, and model code.

Each run uses unique probe bundle identifiers and separate repositories inside the probe app containers. CloudKit stays disabled. The probe does not read production repositories, use an App Group, or change simulator pairing. The runner removes its probe apps after the run. Build products remain outside the repository in a temporary directory.

The automatic sequence checks these actions:

1. The phone starts Work.
2. The Watch receives its UUID, workload name, color, source, and start time.
3. The Watch stops Work and starts Study.
4. The phone receives ended Work and active Study with the expected metadata.
5. The phone stops Study.
6. Both stored snapshots converge to two ended sessions and no active timer.

The runner compares every stored session field between the devices. It also compares start/end times against the checkpoints where each action occurred. Source hashes identify the Shared code used for the run. The runner rejects a run if those source files change during execution.

## Run

1. Boot an existing paired iPhone and Watch simulator.
2. Read their identifiers with `xcrun simctl list pairs`.
3. Run this command from the repository directory:

```sh
python3 Tests/ConnectivityProbe/run_probe.py \
  --phone PAIRED_IPHONE_SIMULATOR_UUID \
  --watch PAIRED_WATCH_SIMULATOR_UUID \
  --evidence Evidence/ConnectivityProbe
```

The runner uses ad-hoc simulator signatures. It does not require a development signing identity. It does not boot devices or change pairing.

## Evidence and limits

Successful runs save synthetic reports, stored snapshots, and `validation.json` in the selected evidence directory. The reports contain only the Work/Study test sessions and default settings/workloads.

This checks foreground, small-history transport. It does not establish physical-device behavior, background delivery latency, large-history file transfers, CloudKit, or APNs behavior. The harness calls the data store directly. Separate UI tests cover the views.

Apple documents that Simulator does not support [file transfers](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile(_:metadata:)) or [user-info transfers](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)). This probe exercises the app's `updateApplicationContext` and `sendMessageData` paths through its actual transport implementation.

## Widget store lifetime regression

`LifetimeProbeApp.swift` tests a separate fresh Watch process compiled with `PUNCHINO_WIDGET`. It uses the actual Shared code and keeps CloudKit disabled. The phone starts a synthetic Work session. A first Watch process receives it into its own repository, then the runner terminates that process. A fresh Watch process stops the saved session, awaits the bounded paired-sync queue operation, and releases its local store. It stays alive for 15 seconds without reopening the Watch app or creating another store. The phone observes whether the stop arrives.

Run the regression with the existing simulator pair:

```sh
python3 Tests/ConnectivityProbe/run_lifetime_probe.py \
  --phone PAIRED_IPHONE_SIMULATOR_UUID \
  --watch PAIRED_WATCH_SIMULATOR_UUID \
  --evidence Evidence/ConnectivityProbe/WidgetLifetime/after
```

The default modes test a short-lived store, a retained-store control, and a zero-timeout call. The short-lived and retained cases must queue the stop and converge to exactly equal stored sessions. The short-lived case must release its store after the call. The zero-timeout case must return promptly and preserve the local stop; if it cannot queue, its status must say paired sync is pending. `--modes baseline` skips the queue barrier to reproduce the old caller behavior. Baseline delivery can depend on activation timing, so that mode records its outcome without requiring failure.

Reports include process identifiers, store lifetime, queue acceptance, activation/delegate state, and stored snapshots. Before-fix evidence records a missing delegate before activation, a local stop, and a phone session that remained active. Its retained control converged. After-fix evidence records the regression results against the Shared source hashes in that run.

This isolates the data-store lifetime in a foreground Watch app process. It does not establish the lifetime of a WidgetKit host or guarantee delivery before extension termination. A successful queue operation means WatchConnectivity accepted the application context; it does not mean the counterpart acknowledged delivery. The local repository remains the saved copy when activation times out or transport is unavailable.
