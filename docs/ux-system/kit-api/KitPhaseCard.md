# KitPhaseCard

`class KitPhaseCard` lives in `lib/ui/kit/team/kit_phase_card.dart`.

Purpose: an engine-neutral presentation of one AI Team surface. The caller owns
localized labels, state and callbacks; see [the constructor contract](../../qa/aiteam-kit-2026-09-29/API.md).

States: empty, loading, running, needs-you, stalled, failed, done and stale.
The status text explains the actual state and its age. Loading has no guessed
progress; stale/loading suppress mutation actions. Read-only rows remain readable.
Spec blocks use readOnly for approved content; drafts remain caller-owned.

Layout: host gutter once, no outer side padding. Cards have token space4 inner
padding; their children are flat rows, never panels. Metadata wraps beneath titles.
All actions use kit targets of at least 48 dp. Wide layouts reuse the same content
without inflating the reading width. Reduced motion is static.

Accessibility: logical title/content/action order, labelled controls, keyboard
activation using kit controls, no once-per-second live-region announcements.
Theme colors use semantic roles; severity has explicit words as well as color.

Validation: `test/kit/kit_phase_card_test.dart` and
`test/goldens/kit/kit_phase_card_golden_test.dart`; 360 dp at 2x text, phone and
wide Android galleries in light and dark. Actual TalkBack requires a device.
