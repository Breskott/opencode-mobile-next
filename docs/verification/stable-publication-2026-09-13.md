# Stable Android publication path

Finish line: an existing signed CI draft can be verified and published as a stable Android GitHub release from the exact reviewed master source, without accessing signing keys locally or pretending it is a Shorebird release.

Non-goals: changing signing identities, publishing desktop/web, fabricating runtime evidence, triggering CI, or executing publication in this implementation slice.

## Operator sequence

1. Integrate the About copy fragment in `stable-publication-copy.json` into English/Arabic localization, regenerate once, and validate the final candidate. This branch declares 1.0.43+49; the separately delivered 1.0.43+48 checkpoint is not its verification baseline.
2. Run the full Android quality workflow on the final source, then verify native upgrade/profile/draft retention. An APK-only workflow is insufficient.
3. Fast-forward the reviewed source to `master` on `mobile-next`, preserving other checkouts. The clean publication checkout must track `mobile-next/master` (or another same-named upstream pointing to the same GitHub repository).
4. Create and push immutable tag `v1.0.43+49` on that exact master. The Android release workflow verifies master/tag/version, builds with the existing public key, verifies package/signature/version, and stages a stable draft with versioned notes. Its artifact is named `opencode-mobile-signed-<source SHA>`; manual branch builds remain artifact-only.
5. Inspect the public APK and perform the corresponding public-lineage upgrade checks. The maintainer APK remains separate, signed with its existing `2D010...` certificate.
6. Set `OC_RELEASE_BUILD_RUN_ID` to the successful tagged Android release run and `OC_RELEASE_QUALITY_RUN_ID` to the successful full quality run. Run `./scripts/release.sh github` from the synchronized clean master to verify without publishing.
7. Once all source, upgrade and runtime evidence is accepted, run `./scripts/release.sh github --publish`. Existing maintainer release authorization applies. This publishes the verified draft with stable/latest flags and checks the resulting release and body.

The GitHub mode derives the repository from master's upstream and refuses the old `opencode-mobile` repository. It requires local/remote tag agreement, identical CI source, trusted workflow/event, successful complete quality steps, stable draft state, matching draft/CI APK bytes and checksums, exact public signer, package and version, and notes derived from the committed versioned document. Existing Shorebird release/sideload/patch modes retain their original gates. No script creates new keys, rotates a certificate, or overwrites a published release.

## Validation status

Implementation is source-only. Coordinator owns shell-contract checks, formatting, About widget tests after localization integration, final analyzer and release gates. This note does not claim any build, runtime, signing, tag or publication success.

Focused checks to run after integration:

- `bash test/release_script_test.sh` retains legacy Shorebird release, sideload, patch and alpha safeguards.
- `bash test/github_release_script_test.sh` exercises 23 mocked cases: dry-run/publication success; wrong branch/tree/upstream/tag/source/workflow outcome; APK-only and already-published rejection; draft state/body/checksum/bytes/signer/package/version mismatch; and the actual workflow draft-staging shell for new/existing drafts and published-release refusal.
- `flutter test --concurrency=1 test/about_alpha_notice_test.dart test/release_script_contract_test.dart` after localization generation. The second file executes both shell contracts.

Only `git diff --check` has been executed by the worker; it passed. All tests remain pending coordinator execution.
