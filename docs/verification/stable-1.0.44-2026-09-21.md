# Stable Android 1.0.44+50 — release verification

The Android release uses immutable tag `v1.0.44+50`, source
`c62f159ae3c1741cb4ec0ef92b4941c0ddfc0a18`.

## Exact candidate checks

- Analyzer clean over the whole project, tests included.
- Local full suite passed before tagging, together with the generated SDK
  package tests (47), the Python QA tests (21), the quota tool tests (36) and
  Android `lintRelease`. The first push failed the CI analyze step on one
  unused import in a new test file; it was removed and everything re-run.
- [Full Android quality run 35548517425](https://github.com/Eslamasabry/opencode-mobile-next/actions/runs/35548517425)
  passed on `master` at that exact source: generated SDK integrity, SDK
  analyzer/tests, app analyzer, full serial Flutter tests, Android lint,
  release compilation and signed maintainer APK verification. The same gate
  passed on `dev` ([35546837597](https://github.com/Eslamasabry/opencode-mobile-next/actions/runs/35546837597)),
  as did the Linux, Windows and iOS preparation workflows.
- [Public release build 35548516245](https://github.com/Eslamasabry/opencode-mobile-next/actions/runs/35548516245)
  passed against the immutable tag: public signer, package/version, release
  notes and draft asset preparation verified.
- `scripts/release.sh github` verified the draft, CI provenance, the quality
  gate and the public APK identity before `--publish`.

The tag also started the experimental Linux desktop workflow, which attached
its `.deb`, `.tar.gz` and `SHA256SUMS-linux` to the draft. They were
removed before publishing: the stable contract is the APK and its checksum,
and desktop builds are experimental. They remain in that workflow run.

## APK identity and upgrade checks

Package `io.github.eslamasabry.opencode_mobile`, version name `1.0.44`,
version code `50`, size 203332920 bytes.

| Artifact | Certificate SHA-256 | APK SHA-256 |
| --- | --- | --- |
| Public APK | `842284B27AA297FB74CF831779FD16498517E1BC2104451459FEC2EA7AC11D1C` | `0c0f8add1a37f3cc763ec2eb81708b580518c8d945b4833ea546cfeac9978c52` |

Checked on an Android emulator (Pixel 6 image, x86_64):

- Public `1.0.43+49` installed fresh and launched; the public `1.0.44+50`
  installed over it in place (`adb install -r`), reported version code 50,
  launched, and logged no fatal exception or Flutter error.
- A release build of the same source, upgraded over an existing install with
  data: started the phone's OpenCode 2.0.10 server from a cold boot, opened an
  existing conversation, and completed a live turn (prompt shown once, reply
  received).

Not checked on a physical phone by the release process: the arm64 installs of
the on-phone services, a real Claude sign-in, large text and right-to-left on
hardware. The maintainer used earlier builds of this source on a phone
throughout development.
