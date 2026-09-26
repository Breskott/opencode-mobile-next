# KitRowParts v2 (KitRowMenu, KitSwitchRow, KitExpandRow): API freeze (wave 0, 2026-09-26)

Unit: `kit-KitRowParts-v2` (wave 1, tier 1d, kit-change), whose write set is `lib/ui/kit/kit_row_parts.dart` (cut review C14, C25; the edge changes in README.md).

- **Spec:** kit-v2.md §2.5 (KitRowMenu as the swipe's twin), §2.6 (KitSwitchRow risk and locked), §2.11 (a controlled KitExpandRow), §4.2, §8.2 (KitRow row), §8.3; design-standard.md §6; visual language §5 (no per-row ⋮).
- **Rules:** KIT-26, KIT-28, KIT-30, KIT-35, KIT-43, SEC-9, STATE-8, LAY-9, LAY-11, A11Y-5, MOT-5.

## Purpose

These are the row parts that sit beside `KitRow`:

- **`KitRowMenu`:** the one overflow (⋮) button, now opening `showKitMenu`.
- **`KitSwitchRow`:** an on/off setting as a row. It gains a risk scope with an inline "for how long" and the status-line notice, and `locked` for "always on".
- **`KitExpandRow`:** a row that unfolds in place. It can now be controlled, so every `ExpansionTile` moves to it.

## Replaces

- **KitRowMenu:**
  - kit-v2.json `existingAdoption` KitRowMenu, 11 elements: `chat#chat-appbar-session-menu`, `embedded-context-menu-region#embedded-context-menu-region-item`, `embedded-local-agent-onboarding-block#more-menu`, `files#files-order-menu`, `global-sessions#global-sessions-row-menu`, `managed-workspaces#managed-workspaces-tile-menu`, `review-workspace#review-workspace-file-actions`, `team-run#team-run-more`, `workspace#workspace-session-menu`, `workspace-archived-sheet#workspace-archived-sheet-menu`, `worktrees#worktrees-tile-menu`;
  - its own `PopupMenuButton` (kit_row_parts.dart:89).

  Row menus move from a trailing ⋮ to `KitRow.menu` (KIT-28, KitRow.md). `KitRowMenu` stays for places that are not rows: a top-bar or section overflow.
- **KitSwitchRow:**
  - kit-v2.json `existingAdoption` KitSwitchRow, 17 elements on 15 pages: `embedded-transcript-display-toggles`; `mcp-setup` (detect-oauth); `notifications-settings` (notifications-toggle); `phone-setup-customize-sheet` (optional-switch, required-switches); `privacy-settings` (share-session-views); `provider-quota` (provider-quota-consent); `session-approvals-sheet` (inherit-switch, server-switch); `session-export` (redact); `session-menu-sheet` (display-toggles); `settings-transcript-display-sheet` (transcript-toggles); `shell-output` (follow); `skill-activation-sheet` (run-now); `stage-revert-sheet` (apply-files); `team-agent-output` (follow); `team-home-runs-tab` (upkeep-toggle);
  - G16 `SwitchListTile`, 24 uses in 13 files (the notifications settings alone have 9);
  - `phone-setup-customize-sheet`'s disabled-on switches, which become `locked:`.
- **KitExpandRow:** G16 `ExpansionTile`, 17 uses in 14 files. The spec says 18. The files: `app_diagnostics_screen`, `chat/attention_card` (2), `chat/composer` (2), `chat/prompt_stash`, `guide_screen`, `servers_screen` (2), `settings/plugins_screen`, `tailscale_setup_screen`, `team/agent_screen`, `team/gate_sheet`, `team/work_sheet`, `termux_setup_screen`, `termux_storage_screen`, `web_sources_screen`.
- **KitMenuItem** leaves this file for `kit_menu.dart` and is re-exported from here (KitMenu.md, Open question 1).

## File

`lib/ui/kit/kit_row_parts.dart` (existing, changed additively).

- **Tests:** `test/kit/kit_row_parts_test.dart`.
- **Gallery:** `test/goldens/kit/kit_row_parts_golden_test.dart` (the unit's derived file), with one group per public widget; the G4 manifest maps `KitRowMenu`, `KitSwitchRow` and `KitExpandRow` to it (README.md convention: one gallery file per unit).
- **Unchanged here:** `KitRowIcon`, `kitCurrentSpan` and `KitChevron`, apart from moving their literals onto `KitTokens` under the G21 kit ratchet.

## Public API

```dart
export 'kit_menu.dart' show KitMenuItem;   // moved by kit-KitMenu

/// The one overflow button (⋮): opens [items] with showKitMenu. For a top
/// bar or a section; a row's menu is KitRow.menu (no per-row ⋮, KIT-28).
class KitRowMenu extends StatelessWidget {
  const KitRowMenu({
    super.key,
    required this.items,
    this.tooltip,          // default l10n.kitMore ("More"); same words as today's chatUiMore
    this.enabled = true,
    this.menuLabel,        // new: the opened menu's semantic name ("Conversation actions")
    this.menuKey,          // new: passed to showKitMenu
  });

  final List<KitMenuItem> items;
  final String? tooltip;
  final bool enabled;
  final String? menuLabel;
  final Key? menuKey;

  /// The same menu without the button: what KitRow and KitTappable call on
  /// long-press, right-click, Shift+F10 and the context-menu key.
  static Future<KitMenuItem?> show(
    BuildContext context,
    List<KitMenuItem> items, {
    Offset? position,
    String? menuLabel,
    Key? menuKey,
  });
}

/// How long a risky switch stays on (kit-v2.md §2.6).
enum KitUntil {
  off,           // "Until I turn it off"   (l10n.kitUntilOff)
  conversation,  // "For this conversation" (l10n.kitUntilConversation)
  hour,          // "For an hour"           (l10n.kitUntilHour)
}

/// A risky switch's scope (security vertical, KIT-30, SEC-9).
@immutable
class KitRisk {
  const KitRisk({
    required this.scope,        // "Every conversation on this server"
    required this.onLabel,      // the status-line words while on: "Auto-approve is on"
    required this.icon,         // the switch's glyph, used on the status line (KitStatusLine.md: neutral tone)
    required this.onUntil,      // ValueChanged<KitUntil>: the chosen duration, before onChanged(true)
    this.until = const [KitUntil.off],
    this.current,               // while on: the duration in force, shown in the supporting line
  }) : assert(until.length >= 1 && until.length <= 3);

  final String scope;
  final String onLabel;
  final IconData icon;
  final ValueChanged<KitUntil> onUntil;
  final List<KitUntil> until;
  final KitUntil? current;
}

/// An on/off setting as a row (design standard §6). Existing parameters
/// unchanged (KIT-43); new ones are optional.
class KitSwitchRow extends StatelessWidget {
  const KitSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
    this.supporting,
    this.switchKey,
    this.below,
    this.risk,             // new: KitRisk?
    this.locked,           // new: String? e.g. "Always included"
    this.disabledReason,   // new: String? shown as the supporting line when onChanged is null
  }) : assert(locked == null || risk == null),
       assert(locked == null || value, 'locked means always on');

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final String? supporting;
  final Key? switchKey;
  final Widget? below;
  final KitRisk? risk;
  final String? locked;
  final String? disabledReason;
}

/// A row that unfolds in place (design standard §6). Uncontrolled as today
/// (initiallyExpanded), or controlled with [expanded] + [onExpansionChanged].
class KitExpandRow extends StatefulWidget {
  const KitExpandRow({
    super.key,
    required this.title,
    required this.children,
    this.leading,
    this.supporting,
    this.initiallyExpanded = false,
    this.headerKey,
    this.expanded,               // new: bool?; non-null = controlled
    this.onExpansionChanged,     // new: ValueChanged<bool>?
    this.supportingMaxLines = 1, // new: 2 where the fold's line explains itself (§6)
    this.maintainState = false,  // new: keep folded children alive (a form inside); ExpansionTile parity
  }) : assert(expanded == null || !initiallyExpanded,
           'controlled rows take expanded, not initiallyExpanded');

  final String title;
  final Widget? leading;
  final InlineSpan? supporting;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Key? headerKey;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  final int supportingMaxLines;
  final bool maintainState;
}

// Unchanged: KitRowIcon, kitCurrentSpan, KitChevron.
```

- **KitSwitchRow.risk flow (§2.6):**
  1. **Off to on:** a tap does **not** call `onChanged(true)`. The row unfolds in place, using `KitReveal` under the row, never a sheet (KIT-16). The unfolded part holds:
     - the `scope` sentence;
     - with 2–3 `until` options, a `KitChoiceList.single(actsOnTap: true)` of the `until` labels, where the choice itself acts (KIT-25). The labels ("Until I turn it off", "For this conversation", "For an hour") are long for 2–4 short segments, so they are full-width choice rows (README.md, decision D7);
     - with one option, a secondary `KitButton` "Turn on" (l10n.kitRiskTurnOn);
     - a tertiary "Not now" (l10n.kitRiskNotNow) that folds it back.
  2. **Choosing:** calls `risk.onUntil(choice)`, then `onChanged(true)`, and folds.
  3. **While on:**
     - the supporting line starts with the scope and the duration ("Every conversation on this server · For an hour");
     - the row wraps itself in `KitStatusContribution(status: KitStatus(kind: KitStatusKind.riskySwitch, id: 'risk:<switchKey or title>', icon: risk.icon, message: risk.onLabel, action: KitAction(label: l10n.kitRiskTurnOff /* "Turn off" */, onPressed: () => onChanged!(false))))`. That puts the condition on the screen's one status line at KIT-35 priority 4. The types are frozen in KitStatusLine.md and KitScreen.md (`kit_status_slot.dart`). A risky-switch status is never dismissible (KitStatusLine.md);
     - the condition leaves when `value` turns false or the row is disposed.
  4. **On to off:** acts at once (`onChanged(false)`, DATA-11 "neither").
- **KitSwitchRow.locked:**
  - no switch;
  - a trailing `locked` word in `text3` with the locked glyph (`AppIconography.locked`, 20);
  - the row is not tappable;
  - semantics: "on", with the hint `locked`.

  This replaces a greyed-on switch that reads as off.
- **KitRowMenu v2 renders** a `KitIconButton(icon: AppIconography.more, tooltip: tooltip ?? l10n.kitMore, onPressed: …)` that calls `showKitMenu(context, items: items, semanticsLabel: menuLabel, menuKey: menuKey)`. With `enabled == false` or empty `items`, the button is not shown (STATE-8), instead of today's dimmed ⋮. This is a behaviour change, and it is listed in the QA record per TEST-19 for any test that found a disabled ⋮.
- **KitExpandRow controlled:**
  - with `expanded != null`, a tap calls `onExpansionChanged(!expanded)` and the row shows `expanded` as given;
  - uncontrolled, it toggles its own state and also calls `onExpansionChanged`;
  - there is no `trailing`, `tilePadding` or `childrenPadding` (see Non-goals).
- **Internal keys (TEST-5):**
  - `kit-row-menu-button`;
  - `kit-switch-risk-step`, the unfolded step;
  - `kit-switch-locked`;
  - `kit-row-current-mark`, which stays (used by 2 tests).

## States

| Part | States (KIT-12) |
|---|---|
| KitRowMenu | default; focused; hidden when disabled or empty (no disabled look) |
| KitSwitchRow | off; on; disabled with its reason as the supporting line (`text2`), with the title and switch in `text3`/disabled track (no `Opacity`); risk: the step unfolded, or on with the scope and duration; locked |
| KitExpandRow | folded; open; focused; with a two-line supporting line |

None of the three shows server data, so none has loading, empty or error states. A fold's children carry their own.

## Tokens

- **ThemeRoles:**
  - `text1`, `text2`, `text3`;
  - `accent` (the switch's on track and the focus ring, LOOK-6);
  - `surface1` (the risk step sits on the row's panel; its choice rows are KitChoiceList's);
  - `hairline`.

  The attention roles are **not** used: a risky switch is not "needs you" (LOOK-4). Its warning is words plus the status line.
- **KitTokens:**
  - `rowHeight`, `rowHeightTwoLine`, `minTarget`;
  - `space1`–`space4`, `gutter`;
  - `smallIconSize`, `iconTileSize`, `iconTileRadius`;
  - `rowTitle`, `rowSupporting`, `rowValue` (the locked word), `note`.
- **KitText:** `rowTitle`, `secondary`, `label`.
- **KitMotion:** `standard`, `emphasized` (the chevron turn, through `KitSpin.chevron`), `quick`, `reduced(context)`. The risk step and the fold use `KitReveal` (lib/ui/kit/motion/kit_reveal.dart, on both branches).
- **Not yet on the VL branch** (STANDARDS §0.5 step 2): `KitTokens.hairlineWidth(context)` and `focusRingWidth(context)`.
- **New tokens:** none. `KitChoiceList` brings its own (`choiceRowMinHeight`, `_new-tokens.md`).

## Adaptive

| Part | compact | medium | expanded / large |
|---|---|---|---|
| KitRowMenu | 48 dp ⋮ `KitIconButton`; the menu is anchored to it | the same | the same, plus a hover tooltip; Enter or Space opens the menu with the first item focused |
| KitSwitchRow | the whole row toggles; the risk step unfolds below with its `until` choice rows (KitChoiceList) | the same | hover and focus on the row (through KitRow/KitTappable); Space toggles; the step's choice rows take arrow keys, Space and Enter |
| KitExpandRow | a tap on the header folds or unfolds | the same | hover and focus ring; Enter or Space toggles; Right and Left (mirrored in RTL) open and close when focused |

- **Short windows:** no change; the unfolded content scrolls with the list.
- **All targets:** 48 dp or larger (§8.3).

## Accessibility

- **KitRowMenu:** a button named `tooltip` ("More"). The opened menu is named `menuLabel` (KitMenu.md).
- **KitSwitchRow:**
  - `MergeSemantics`, as today: a toggle, "on" or "off", named `title`, with `supporting` as the value;
  - disabled: `enabled: false`, with `disabledReason` as visible text *and* the hint (STATE-8);
  - risk: when the step unfolds, focus moves to the scope sentence, and the step is announced once as part of the route change of focus, not as a live region. While on, the status line announces its condition once (KIT-35, A11Y-3);
  - locked: toggled "on", `enabled: false`, hint `locked`.
- **KitExpandRow:** `button`, with `expanded` semantics, as today. The unfolded children follow in reading order.
- **Targets:** 48 dp. The switch's 48 dp area and the row's tap area are the same target, so there are no overlapping targets.
- **200 % text:**
  - titles wrap to two lines (KitSwitchRow already uses `titleMaxLines: 2`);
  - supporting lines wrap to their max, then truncate with the full value in semantics (A11Y-8);
  - the risk step's choice rows wrap and grow (KitChoiceList);
  - there is no overflow at 320 dp (G6).

## RTL

- The switch, the locked word, the ⋮ and the chevron sit at the end, mirrored.
- All padding is directional.
- The chevron glyphs point down and up, and are not mirrored.
- Scope text that names a server is wrapped by the caller with `KitBidi.auto` (COPY-30).

## Motion and haptics

- **KitExpandRow:** the chevron is `KitSpin.chevron` (`KitMotion.standard`/`emphasized`; README.md decision D10), and the children unfold with `KitReveal`, which is the only allowed layout animation (MOT-5). It is never used inside a scrolling list item's own size: the fold is the list item.
- **KitSwitchRow:** the risk step unfolds with `KitReveal`, and the switch thumb uses the framework's switch animation, timed by the theme on `KitMotion.quick`.
- **KitRowMenu:** the menu's own cross-fade (KitMenu).
- **Reduced motion:** everything is instant (G8).
- **Haptics:** none. Toggles, folds and menus are silent (MOT-11).

## Data safety and honest state

- **Risky switches (KIT-30, SEC-9):**
  - They state their scope and duration before they take effect.
  - They show an indicator while on (the status line).
  - They can be turned off where they are shown.
  - "Always allow" is never a request card's primary; it lives in `showKitRequestSheet` as this row (kit-KitRequestSheet).
- **Locked:** says what is true (always on), and never shows a grey-on switch that reads as off.
- **Disabled switch:** says why, as visible text.
- **KitRowMenu:** hides instead of showing a dead ⋮ (STATE-8). Destructive items are last, after a divider (KitMenu ordering, §4.2).
- **Controlled KitExpandRow:** lets the chat keep the reasoning and tool-group folds in its own state, so a fold survives rebuilds and reconnects honestly (chat chain, wave 2c).

## Depends on

- **kit-KitMenu:** `showKitMenu` and `KitMenuItem`.
- **kit-KitStatusLine-v2:** the risky-switch condition in the one status line.
- **kit-KitChoiceList** (tier 1c): the `until` choice. It replaces C25's edge to kit-KitSegmented (README.md, decision D7), which would otherwise follow kit-KitChoiceList (the stacked form) and push this unit, kit-KitRow-v2 and its dependents one more tier.
- **kit-KitIconButton-v2** (tier 1a): KitRowMenu's button; edge added for the record.
- **kit-KitMotionParts** (tier 1a): `KitSpin.chevron`; edge added.
- **Depend on it:** kit-KitRow-v2, kit-KitRequestSheet, kit-KitToolRow (C25).

## Tests required

These go in `test/kit/kit_row_parts_test.dart` (G9, G14x, G37):

1. **KitRowMenu:**
   - a tap opens `showKitMenu` with the items, and destructive items are last after a divider;
   - `enabled: false` or empty `items` renders no button;
   - the tooltip defaults to "More";
   - Enter on the focused button opens the menu with the first item focused (desktop capabilities);
   - `KitRowMenu.show` opens the same list at a position.
2. **KitSwitchRow:** a tap toggles; with `onChanged: null`, the reason text is visible and the hint equals it, and nothing is painted at alpha below 255.
3. **Risk, off to on:**
   - a tap unfolds `kit-switch-risk-step` and does **not** call `onChanged`;
   - picking "For an hour" calls `onUntil(KitUntil.hour)`, then `onChanged(true)`, in that order;
   - "Not now" folds back and calls neither;
   - with one `until` option, "Turn on" does the same.
4. **Risk, while on:** the status-line slot shows `onLabel` with a "Turn off" action, which calls `onChanged(false)`. After `value` becomes false, the condition is gone. This test runs inside a `KitScreen` with its slot.
5. **Risk, on to off:** acts at once, with no step.
6. **Locked:** there is no `Switch` in the tree, `kit-switch-locked` shows the word, a tap does nothing, and semantics say toggled on with `enabled: false`. `locked` with `value: false` asserts.
7. **KitExpandRow controlled:**
   - a tap calls `onExpansionChanged(true)` without unfolding until the parent rebuilds with `expanded: true`;
   - uncontrolled, it toggles and still reports;
   - `expanded` with `initiallyExpanded: true` asserts;
   - `maintainState: true` keeps a folded child's `State`.
8. **Keyboard (G14):** Space toggles a switch row, and Enter and Space fold an expand row.
9. **KIT-43:** every existing constructor call shape compiles (KitSwitchRow in 3 files, KitExpandRow in 4 files, KitRowMenu in 4 files, KitMenuItem in 4 files).
10. **G6:** a risk step at text 2.0 and 320 dp lays out its three choice rows with no overflow, LTR and RTL.
11. **G8:** every fold and step settles after one `pump()` under reduced motion.

## Galleries required

These are rendered at DPR 3.0 (TEST-9, TEST-20), inside a `KitRowGroup` on `ground`:

- **KitRowMenu group** (names `kit_row_menu_…png`):
  - `default` (the button in a top-bar-like row) and `open` (the menu shown, with a destructive item), at 412×915, dark and light: 4 PNGs;
  - `default` at the 5 other sizes: 10 PNGs;
  - text 2.0 and Arabic at 412 and 1280: 8 PNGs;
  - **total:** 22 PNGs.
- **KitSwitchRow group** (names `kit_switch_row_…png`):
  - `off`, `on`, `disabled`, `risk_step`, `risk_on` and `locked`, at 412×915, dark and light: 12 PNGs;
  - `default` (off and on in one group) at the 5 other sizes: 10 PNGs;
  - text 2.0 and Arabic, with `risk_step` as the scene because it is the tallest: 8 PNGs;
  - **total:** 30 PNGs.
- **KitExpandRow group** (names `kit_expand_row_…png`):
  - `folded` and `open`, at 412×915, dark and light: 4 PNGs;
  - `open` at the 5 other sizes: 10 PNGs;
  - text 2.0 and Arabic: 8 PNGs;
  - **total:** 22 PNGs.
- **Unit total:** 74 PNGs. This is **over the 60-PNG cap** (TEST-20), which allows more only with the coordinator's approval in the record. Cutting sizes instead would break TEST-9, which requires the default state at every gallery size. See Open question 2.

## Non-goals

- No per-row ⋮ inside `KitRow`. Existing trailing `KitRowMenu`s in rows keep working (KIT-43) and move to `KitRow.menu` in wave 2. There is no assert in wave 1.
- No `trailing`, `tilePadding`, `childrenPadding` or `collapsedBackgroundColor` on KitExpandRow: the kit owns the look. A wave-2 site needing another trailing uses a `KitRow` with its own `onTap` and a `KitReveal`.
- No choice rows or radio and checkbox tiles: that is `KitChoiceRow` in kit-KitChoiceList.
- No risk timer: the owner of the setting (the gateway or the controller) ends an "hour" or "conversation" and flips `value`. The row shows what it is given.

## Open questions

1. **Who owns `kit_status_slot.dart`: settled (README.md, decision D5).** The file (`KitStatusScope`, `KitStatusLineSlot`, `KitStatusContribution`, frozen in KitScreen.md) goes into kit-KitStatusLine-v2's write set (tier 1b), so this unit reaches the one status line through `KitStatusContribution` without waiting for kit-KitScreen-v2. A local substitute is not an option (R13).
2. **The gallery budget (coordinator).** Three public widgets live in one write set, which comes to 74 PNGs against the 60-PNG cap per unit (TEST-20). The compliant route is the coordinator approving 74 in the unit's record. The alternative would amend TEST-9 so that a multi-widget kit unit renders the other sizes once per unit, not per widget. That is a rulebook change, not this unit's choice.
