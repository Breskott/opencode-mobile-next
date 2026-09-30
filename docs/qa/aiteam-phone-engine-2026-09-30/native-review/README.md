# Native engine review follow-up

Finish line: the packaged daemon authenticates its private launcher pipe before the app sends any bearer HTTP request, survives the launching thread, and exits on app-pipe EOF.

Non-goal: model turns, UI journey, changing boundary eligibility, signing or installing an APK.

The preview test instrumentation now supports the no-model-spend regression mode:

```sh
adb -s emulator-5554 shell am instrument -w -r \
  -e isolatedQa true -e nativeRegressions true \
  io.github.eslamasabry.opencode_mobile.preview.test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance
```

It requires the matching preview/test APKs and existing in-app Ubuntu/server credentials. It refuses to displace a listener already on port 4098. The checks use a real squatter on that fixed port, the actual packaged daemon on its authenticated random port, a short-lived launcher thread, actual stdin EOF, and a forged readiness-line negative control that must cause no TCP connection. No fake boundary receipt or execution capability is installed. Removing MAC validation allows the forged-pipe test to connect; restoring fixed-port polling/binding fails the squatter test; restoring launcher-thread PDEATHSIG fails the liveness assertion.

Device execution remains pending; source checks are not a device proof. Root owns serial compile and execution evidence.

## Native lifecycle follow-up

- A1: only the exact `:local_pdf` PID/UID/package registered by Android ActivityManager is added to the known-process inventory. A worker's forgeable `/proc` command line is never trusted. Regression controls reject other process names, other UIDs, missing package membership and unknown inventory.
- A2: deletion invokes the verified packaged engine's descriptor-anchored `--erase-tree` helper. It repairs mode-000 and read-only worker directories without pathname-following chmod. Failure retains the durable deletion tombstone. Instrumentation creates mode-000/0555 children and an outside symlink sentinel, then requires complete deletion with sentinel preservation. Root supplies and checks the Rust helper and matched bundle.
- A3: signing completes before the protection marker is committed while legacy launches remain fenced by the existing monitor. Existing protection markers are never cleared. The regression asserts sign-before-protect and no protect call on signer failure.
- A4: Stop all attempts every tracked service and reports the first error afterward. Even a phone-engine credential cleanup failure attempts the tracked daemon stop and updates the service inventory. The regression injects an engine-stop failure and requires the server and remaining services to be stopped.
- A6: normal stop already erased the active credential copy. Runtime uninstall now also sweeps inactive engine-profile password copies after all services/processes stop. It unlinks leaf symlinks instead of following them. The focused test scopes the same cleanup to two isolated fixture profiles and preserves an outside sentinel.

A5 remains under review: moving the proof out of the global monitor requires a launch-admission fence and cancellation checks for both service and PTY launches; simply removing synchronization would introduce a confinement race. No device run is claimed by these source changes.
