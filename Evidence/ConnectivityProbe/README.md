# Actual Shared transport evidence

The isolated simulator probe passed on iOS 27.2 and watchOS 27.2. It compiled the current Shared sources directly. CloudKit stayed disabled.

The phone started Work. The Watch received its exact UUID, name, color, source, and start time. The Watch stopped Work and started Study. The phone received ended Work and active Study, then stopped Study. Both stored snapshots converged to two ended sessions and no active timer.

`validation.json` records the successful checks and source hashes. `phone-report.json` and `watch-report.json` contain the action checkpoints. The snapshot files contain the final stored records. `environment.json` records the simulator runtime versions.

All records are synthetic Work/Study test data. The probe used unique app identifiers and separate app-owned repositories. The runner removed both probe apps after collecting this evidence. It did not change production code, production data, or simulator pairing.

The reproducible harness is in `Tests/ConnectivityProbe`. This result covers foreground, small-history synchronization. It does not verify physical-device behavior, background timing, file/user-info transfers, CloudKit, or APNs.
