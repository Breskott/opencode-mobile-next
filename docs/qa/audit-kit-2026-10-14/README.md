# Audit slice: kit (2026-10-14)

Source: `docs/audits/ui-ux-audit-2026-10-14.md` section 6. Branch `fix/audit-kit`.

| ID | Verdict | Reason | Commit |
|---|---|---|---|
| P1-1 | REAL | `graphiteLight` surface1 == surface2 == #FFFFFF. surface1 is now #FAFAF8 (ground and surface3 left alone, smaller change than the audit proposed); QR paper stays pure white via surface2. Light goldens regenerated. | ef1dfac1a |
| P1-7 | REAL | Selected indicator drew a second hairline flush against the track's. Now inset 2dp, concentric, no border of its own. | 1b5eceb2e |
| P1-9 | REAL | Chip, menu, row tile and chevron, current mark, button, spinner, jump pill used raw `smallIconSize`; now `tokens.iconSize`. | 0f1aa5869 |
| P2-3 | REAL | Diff page was Scaffold + SafeArea + `KitScreen(header:)`; now `KitScreen(topBar:)`. | 5a2447ae5 |
| P2-7 | FALSE | The scope chip is a `KitChip.action`, already a 48dp box (`minHeight: minTarget`) around the 32dp pill. | none |
| P2-9 | REAL | Group note sat at gutter+4; now on the section label's gutter. | ff6090a40 |
| P2-10 | REAL | Raw `Divider` replaced by `KitDivider` with a scaled, rounded indent in KitChoiceList and KitSegmented. | 1b5eceb2e |
| P2-11 | REAL | `kitCurrentSpan` now uses the label role like `KitNeedsYou.span`. | 0f1aa5869 |
| P2-12 | REAL | Top bar failure subtitle and code-block copy failure were red. Now neutral text; copy failure also shows the error glyph. The top bar still shows amber for attention (not routed through `toneFor`, which would make needs-you neutral). | 5a2447ae5 |
| P2-13 | SKIP | Unifying warning triangle and question mark would change how "needs you" looks (KitTaskMark question vs notice triangle). Recommendation: keep the two glyphs, they mean "answer this" vs "be aware"; owner decides. | none |
| P2-15 | REAL | KitSearchField now steps its border hairline to text3 on pointer hover like KitField. | ff6090a40 |
| P3-1 | REAL | requestTileRadius 10 to 9 (matches iconTileRadius). | ff6090a40 |
| P3-5 | REAL | `Icons.check` replaced by `AppIconography.check`. | 1b5eceb2e |
| P3-6 | REAL | Multiline field padding uses the resolved style's line height, not a fixed 24. | ff6090a40 |
| P3-7 | REAL | Menu supporting line used 4dp; now `KitTokens.rowLineGap`. Choice list uses the token (same 2dp value). | 0f1aa5869, 1b5eceb2e |
| P3-8 | REAL | `_KitJumpPillButton` now uses `KitTappable` (inner focus ring, surface step); resting fill and hairline drawn around it. | ff6090a40 |
| P3-9 | REAL | A chip with `onLongPress` keeps its hover tooltip (manual trigger, so touch long-press still opens the menu). Keyboard focus does not show it, only hover. | 0f1aa5869 |

Tests that fail without the fixes: `test/kit/audit_kit_2026_10_14_test.dart` (P1-9, P2-9, P2-12 x2, P2-15, P3-9; all six verified failing with `lib/` reverted).
Existing tests updated: jump pill (finds `KitTappable`, ring now inside), segmented (Phosphor check), tappable (light surface1 steps to surface2/surface3), theme roles/packs, QR paper, pre-wave tokens.

Goldens: regenerated for every affected file; `agent_card_list_mixed` was left alone (fails on the base commit too).

Images: `p1-1-before/after-settings-about-light.png`, `p1-7-before/after-segmented-dark.png`.
