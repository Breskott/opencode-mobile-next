# Dart boundary tier slice

Finish line: authenticated health and native status expose recognized confinement tiers, preserve older schema-1 health compatibility, and reject unknown or inconsistent tier values.

Non-goal: implementing native confinement, attestation or launcher behavior; enabling execution from a client string; editing UI or state-controller code; running device proof.

The additive contract is documented in `docs/design/aiteam-phone-boundary-tiers-2026-09-30.md`.

Focused regressions in `test/phone_project_engine_gateway_test.dart` cover verified proot and Landlock health, an unverified `none` response, old health with no tier, one-location additive transitions, and unknown/malformed/conflicting tiers. `test/builtin_phone_engine_test.dart` covers all native status tiers, old status compatibility, and safe refusal of unknown/malformed values.

The worker ran pinned Dart formatting and `git diff --check`; both completed. The thin worktree has no package map and formatting emitted an unresolved `flutter_lints` include warning. No Flutter tests or analyzer were launched here. The root agent owns the serialized focused gate and must record its result before claiming verification.
