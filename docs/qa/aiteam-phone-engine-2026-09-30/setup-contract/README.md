# Phone setup backend contract

Finish line: setup receives safe native start failure codes, can inspect unconfined children while the daemon is stopped, and every eligible start launches a newly proved daemon generation instead of reusing an old receipt.

Non-goal: UI edits, removing the global startup monitor, signing/installing APKs, relaxing the on-device proof or automatically resubmitting interrupted tasks.

Verification is recorded after the focused gate below. Device instrumentation is authored separately from executed host/Dart checks.

## Contract and tests

- Native static start codes pass through the controller as `PhoneEngineException.code`, including restart/safety-tools distinctions. Regression drives actual MethodChannel → BuiltinLinux → BuiltinPhoneProjectEngineBridge → controller and verifies native message/details never reach the public exception. Typed bridge errors retain their code; unknown errors remain `engineUnavailable`.
- `BuiltinPhoneEngineStatus.unconfinedChildren` is parsed independently of `running`/`restartRequired`. Regression supplies a stopped daemon with old unconfined children; omitted fields keep older maps compatible.
- Every eligible explicit start stops its tracked old daemon and reruns actual controls before issuing a new signed generation. A different profile cannot be displaced. Existing receipt/binary authority checks remain unchanged; unsupported kernel or unconfined old processes cannot grant execution.
- Old controller heartbeat producers and clients drain before token rotation. Regression requires the old gateway to close after an explicit new start. Attach remains the no-restart reuse operation.
- Native no-model regressions now call the real packaged daemon twice, requiring proof-factory invocation twice, different Process instances and different bearer tokens, with the first process dead and another-profile start refused. Null proof in that lifecycle test leaves boundary/execution unavailable.
- A separate `reproofRegression` mode runs the actual signed boundary proof twice through BuiltinLinux, requiring a different signed `boundaryGeneration` while the second daemon remains attested. It contains no fake receipt or capability. It requires an idle preview runtime, matching preview/test APKs, installed Ubuntu/credential prerequisites, and Landlock ABI 6. It never stops another profile's engine or submits model turns.

```sh
adb -s SERIAL shell am instrument -w -r \
  -e isolatedQa true -e reproofRegression true \
  io.github.eslamasabry.opencode_mobile.preview.test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance
```

Stop preview servers/terminals through the existing setup controls before this proof test. The native lifecycle regression remains available under `-e nativeRegressions true`. No device execution is claimed until its instrumentation output is recorded.

## Final focused gate

- `OC_TEST_SLOTS=1 tool/qa/machine_lock.sh test -- <pinned Flutter> test --concurrency=1 test/phone_project_engine_controller_test.dart test/builtin_phone_engine_test.dart test/phone_engine_connection_review_test.dart`: **31 passed, zero failed** on the final changed Dart candidate.
- Pinned `flutter analyze` under the same lock: **clean**; no ignores added.
- Nested test/build lock, JDK 17, Gradle `:app:compileReleaseKotlin :app:compileReleaseAndroidTestKotlin -PocPreview=true`: **passed**. This checks current native production code and both no-model instrumentation modes; it is compilation evidence, not device proof.
- Pinned Dart formatting and `git diff --check`: **passed**.
- The stop/start race test exposed a self-awaiting future cleanup callback during development. The corrected callback returns void; the final regression requires human dispatch to wait for old-engine stop, then allows it to proceed, and requires old stop before new start. Failed earlier candidates are not counted as the final gate.
- Rust source digest still matches the staged dual-ABI manifest, so the native ELF bundle stays unchanged. No new cargo run or binary rebuild is needed for Kotlin/Dart-only edits.
- `adb devices` has no attached device. Actual signed running-generation re-proof and the new packaged-daemon lifecycle regression remain pending on Android. No signing, installation, model spend, push or UI edits occurred.

Integration: merge this engine branch into the coordinator's candidate. UI can read `status.unconfinedChildren` before starting and switch on `PhoneEngineException.code`. Use `start()` for proof/generation refresh and `attach()` to reconnect without restarting work.
