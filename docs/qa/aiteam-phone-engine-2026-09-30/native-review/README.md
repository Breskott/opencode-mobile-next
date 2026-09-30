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
