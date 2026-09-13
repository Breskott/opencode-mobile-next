# Stable Android 1.0.43+49 — release verification

The Android release uses immutable tag `v1.0.43+49`, source
`2c882a35005f11ea671b41d2fa9cb9de1e26fe5e`.

## Exact candidate checks

- Pinned Flutter 3.47.2; analyzer clean.
- Local full serial suite: **3,805 passed, 12 skipped**, all 326 test files,
  including nested directories, in nine bounded chunks. Completed unchanged
  candidate at 09:49 UTC on September 13, 2026.
- [Full Android quality run 34749804973](https://github.com/Eslamasabry/opencode-mobile-next/actions/runs/34749804973)
  passed at that exact source: generated SDK integrity, SDK analyzer/tests,
  app analyzer, full serial Flutter tests (same counts), Android lint, release
  compilation, signed maintainer APK verification and upload.
- [Public release build 34751208433](https://github.com/Eslamasabry/opencode-mobile-next/actions/runs/34751208433)
  passed against the immutable tag: public signer, package/version, release
  notes and draft asset preparation verified.

## APK identity and upgrade checks

Both APKs identify `io.github.eslamasabry.opencode_mobile`, version name
`1.0.43`, version code `49`, and size 201,170,228 bytes. They have separate
signing lineages; they are not interchangeable updates.

| Artifact | Certificate SHA-256 | APK SHA-256 |
| --- | --- | --- |
| Public APK | `842284B27AA297FB74CF831779FD16498517E1BC2104451459FEC2EA7AC11D1C` | `781ec6bb2c4f03759f054e123471e969ada3e7d083e5a7e5fc62e259337ae3bf` |
| Maintainer APK | `2D010C2103CB2F78ABAACA690EAD4D45F8003A6C0A02082CD2A2AE62FD18D0EC` | `935270520e0d68b7c640412751b0e06767ab6db499e71c6fcc8e49dfac341958` |

- Maintainer emulator: `adb install -r` upgraded 1.0.43+48 to +49. The saved
  server profile, selected project and exact chat draft survived.
- Public emulator: `adb install -r` upgraded 1.0.42+47 to 1.0.43+49. The saved
  server profile, selected project and exact chat draft survived.
- Public About screen showed the exact version and public certificate, with
  neutral “About this build” copy and the community/AI-assistance disclosure.
- Runtime used an isolated authenticated OpenCode 1.18.25 server, synthetic
  sessions and no provider/model calls. Credentials were not included in
  screenshots or this report. Unsupported project inventory was shown as
  unknown, rather than claimed verified.

[Maintainer draft after upgrade](../qa/stable-1.0.43-2026-09-13/maintainer49-draft-preserved.png),
[public draft before](../qa/stable-1.0.43-2026-09-13/public47-before-upgrade-draft.png),
[public draft after](../qa/stable-1.0.43-2026-09-13/public49-draft-preserved.png),
[public About](../qa/stable-1.0.43-2026-09-13/public49-about.png).

## Publication verification

Published at 10:27:31 UTC on September 13, 2026. An unauthenticated check of
GitHub’s latest-release API confirmed `draft=false`, `prerelease=false`, the
exact version/tag and public APK digest. The direct APK URL returned HTTP 200.
[Public stable release](https://github.com/Eslamasabry/opencode-mobile-next/releases/tag/v1.0.43%2B49).

Publication ran through `scripts/release.sh github`, first in dry-run mode,
then with `--publish`. It verified exact CI source/workflow provenance,
full-quality steps, tag/master identity, APK byte equality between CI and draft,
versioned notes, SHA256SUMS, certificate and the exact two release assets.

GitHub returned 404 for the draft's by-tag REST lookup. The draft was visible
through `gh release view` and its database-ID endpoint, ID `387862258`.
A release-scoped CLI compatibility adapter mapped only this exact tag lookup
onto that verified ID for this immutable candidate. All existing verification
checks remained in place. The permanent helper correction is a separate
post-release tooling commit; it does not change the released APK or tag.

## Scope and limits

Android is the supported release platform. This verification does not claim
physical-phone Termux installation/cleanup coverage, production web deployment,
complete OpenCode 2 feature parity, or a Shorebird OTA baseline. Web remains in
active development; desktop and AI Team / Gas City remain experimental.

The ready-server handoff regression, cancellation/ownership checks and labelled
widget capture evidence are in
[the focused report](termux-ready-handoff-2026-09-13.md).

## Post-release tooling and documentation

The draft lookup fix passed 33 mocked publication contract cases on the final
integrated tree, including a missing by-tag draft endpoint, invalid IDs, identity
changes and tag mismatches. Shell syntax and documentation links passed. These
post-release tooling/docs changes do not alter app code or the released tag;
the full Flutter coverage above belongs to the exact tagged APK source.
