# Phone engine APK packaging gate

Finish line: release assembly preserves the staged AI Team executable bytes and
fails if the actual APK differs from its runtime manifest.

Non-goal: signing, release publication, device boundary proof, or emulator setup.

The Android release strip task rewrote `libaiteam_*.so` after the native bundle
manifest was generated. The app consequently refused the otherwise valid bundle.
`android/app/build.gradle.kts` now sets
`packaging.jniLibs.keepDebugSymbols += "**/libaiteam_*.so"`. Other native libraries
retain the existing packaging settings.

Every release variant's `assembleRelease` (or corresponding flavored assembly)
depends on `verifyReleasePhoneEngineApk`. The verification task consumes AGP's
`SingleArtifact.APK` provider, which schedules APK packaging before verification.
It reads the current `output-metadata.json` rather than discovering old APKs by
filename. The assembly dependency avoids a package-task finalizer cycle and fails
assembly when verification fails. Python 3.9+ is required by the local gate.

`tool/qa/verify_phone_engine_apk.py` checks the actual ZIP entries, requiring the
embedded manifest to equal the source manifest and each supported ABI's engine,
sandbox, and boundary-probe executable to match its SHA-256. Duplicate entries,
missing entries, unknown engine libraries/ABIs, and malformed manifests fail.
ABI split metadata selects the required ABI for each APK; an explicit ABI filter
can also verify an intentionally filtered APK. An APK with no supported engine
ABI fails. Hashes are printed from the actual packaged bytes on success.

Run the build check directly, using the same local Flutter/Gradle build settings:

```bash
cd android
./gradlew :app:verifyReleasePhoneEngineApk -PocPreview=true
```

For an existing unsigned or signed universal APK, from the repo root:

```bash
python3 tool/qa/verify_phone_engine_apk.py \
  --manifest android/app/src/main/assets/aiteam-engine-manifest.json \
  --apk /absolute/path/to/app-release.apk
```

For an intentionally x86_64-only APK, append `--abi x86_64`. For current AGP
outputs, replace `--apk` with `--apk-dir build/app/outputs/apk/release`. APK signing
changes ZIP metadata, not executable bytes, so the same gate applies before and
after signing.

Focused verification:

```bash
python3 -m unittest discover -s tool/qa/tests \
  -p test_verify_phone_engine_apk.py -v
```

Result: **13 tests passed**. Regression controls cover stripped bytes, a missing
individual library or entire ABI, duplicate libraries/manifest entries, modified
packaged manifest, unknown libraries/ABIs, explicit ABI filters, split output
metadata, stale APK exclusion, invalid output paths, and CLI nonzero failure.

The implementation branch has not run Gradle or produced a new APK. The parent
engine worktree owns serialized Gradle/build and emulator verification and will
record the real APK hashes there. No signing or publication occurred here.
