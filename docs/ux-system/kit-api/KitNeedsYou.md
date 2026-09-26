# KitNeedsYou — API freeze (wave 0)

Unit: `kit-KitNeedsYou` (wave 1, tier 1b, kind `kit-part`). Spec: kit-v2.md §1.21, §4.5, §8.2, with cut review C05 and C25 (it depends on KitStatusMark-v2, and not the reverse). Rules: LOOK-24, AUTO-10, AUTO-11, AUTO-12, AUTO-17, STATE-9, A11Y-3, G37, G38. §11 of STANDARDS applies to this part (§0.4).

## Purpose

The one "needs you" marker, in the same words everywhere and counted once by the one attention source. It has four builders:

- the row mark;
- the supporting-line word;
- the count badge (tab, rail destination, header switcher, server row);
- the pointing row that Work, Inbox and team lists use to open the conversation at the request card.

## Replaces

- **Map elements, 9 on 5 pages (kit-v2.json `new[KitNeedsYou]`, merged gap `KitBadge`):**
  - `activity` (activity-permission-row, activity-question-row, activity-saved-servers-row, activity-team-gate-row);
  - `chat` (chat-appbar-running-work);
  - `embedded-profile-monitor-inbox` (embedded-profile-monitor-inbox-request-row, embedded-profile-monitor-inbox-summary);
  - `home-shell` (home-shell-badge);
  - `profile-monitor` (profile-monitor-request-row).
- **Code reach, adopted by wave-2 units:**
  - G16 `Badge` ×4: `activity_screen.dart` 1, `chat_screen.dart` 2, `home_screen.dart` 1;
  - the hand-counted needs-you words on team rows (`team_needs_you.dart` G16 Icon 1, Text 3);
  - the monitor's double count and its green dot on a request.
- **Retired API:** `KitNotice.card` as a needs-you card in lists (see KitNotice.md; LOOK-24).

## File

- `lib/ui/kit/kit_needs_you.dart` (`KitNeedsYou`, `KitNeedsYouReason`)
- Tests: `test/kit/kit_needs_you_test.dart`
- Gallery: `test/goldens/kit/kit_needs_you_golden_test.dart`

## Public API

```dart
/// Why the app asks (AUTO-9; G38 wants exactly these three).
enum KitNeedsYouReason {
  decision,   // only the person can decide: a permission, a question or form, a gate, a merge
  blocked,    // work cannot continue: credentials rejected, a limit, storage full, a step still failing
  consent,    // a first-time consent at the moment it becomes relevant
}

abstract final class KitNeedsYou {
  /// A row's leading mark: exactly KitTaskMark(state: KitTaskState.needsYou)
  /// (§2.9), with the word "Needs you" in semantics.
  static Widget mark({Key? key});

  /// The start of a row's supporting line, like kitCurrentSpan: "Needs you · ",
  /// or "{count} need you · " for count > 1 (ICU plural). In the attention
  /// tone at label weight.
  static TextSpan span(BuildContext context, {int count = 1});

  /// A count on a tab, a rail destination, a header's switcher or a server
  /// row. count <= 0 returns [child] unchanged; > 99 shows "99+".
  /// Semantics: the host's label gains ", {count} need you" (the badge
  /// itself is excluded, so the count is read once).
  static Widget badge({required int count, required Widget child, Key? key});

  /// The pointing row (LOOK-24, AUTO-17): Work, Inbox and team lists show
  /// a request as this row, which opens the conversation scrolled to its
  /// KitRequestCard. It never answers. Built on KitRow.
  static Widget row({
    Key? key,
    required String title,               // the ask in one line: "Run a shell command"
    required KitNeedsYouReason reason,   // G37: required
    required String ifIgnored,           // G37 / AUTO-10: "The team waits; nothing is lost."
    required VoidCallback onOpen,
    String? who,                         // "fox" (agent) — shown before the server
    String? server,                      // "laptop": the server label (multi-server, §2.5)
    DateTime? since,                     // "waiting 4 min": KitSince(ticks: minutes) with KitSince.ageLabel; no escalation here
    Key? titleKey,
  });

  /// The words for [reason], for notification copy and the card header, so
  /// every surface says the same thing: "Needs your decision" / "Stuck:
  /// needs you" / "Needs your OK".
  static String reasonWord(BuildContext context, KitNeedsYouReason reason);
}
```

Notes:

- `row`, `reason` and `ifIgnored` are additions to K2 §1.21's three builders. The reason is G37 in STANDARDS §18 ("KitNeedsYou and KitRequestCard need `reason` and `ifIgnored`") together with LOOK-24, which makes the list form a `KitRow` carrying the mark and word. Putting that row in the kit is the only way the rule has one implementation. `mark()`, `span()` and `badge()` keep K2's signatures, with only an optional `key` added.
- `mark()` returns `KitTaskMark(state: KitTaskState.needsYou)`, and nothing else draws that mark.
- Counting, deduplication, ordering (oldest first) and clearing belong to the attention source (AUTO-11, AUTO-12; gate G38, wave 3). This part renders the count it is given.

## States

| Builder | States |
|---|---|
| `mark` | one state (needs you) |
| `span` | count 1 ("Needs you · "); count > 1 ("3 need you · ") |
| `badge` | hidden (0); a number (1–99); "99+" |
| `row` | waiting (with `since` age); pressed or hovered (KitRow); there is no answered state: when the request is answered anywhere, the source removes the row (AUTO-12), and the host folds it away with `KitAnimatedRows` |

Loading, empty and error belong to the host list (Inbox: STATE-20). There is no disabled state: a needs-you row is always openable. KIT-12 doc comment: "States: needs-you (mark, span), count (badge: hidden, n, 99+), row".

## Tokens

- **ThemeRoles:**
  - `attention` (mark glyph and span word; allowed by LOOK-4/LOOK-24);
  - `attentionFill` and `onAttentionFill` (badge; VL light: #FFB547 with #1A1000 text);
  - `text1` (row title), `text2` (row supporting remainder), `text3` (age);
  - the row on `surface1` with `hairline` separators (the host's panel).
- **KitText:** `caption` (badge number, tabular figures), `label` (the span word's weight), `rowTitle` and `secondary` (row).
- **KitTokens:** `smallIconSize`, `rowHeightTwoLine` (60), `gutter`, `space1`, `minTarget`.
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.badgeHeight` = 18 and `KitTokens.badgeMinWidth` = 18, drawn as `KitShape.pill` (LOOK-19 "chips and pills"; no radius number);
  - `KitTokens.badgeTextScaleMax` = 1.3 (the badge's clamp, allowed only in the kit with a named reason, A11Y-8: "badges and counts").

## Adaptive

- **compact:** the badge sits on the dock tab's icon and on the top bar's server pill. The row is a full-width `KitRow`.
- **medium:** the badge also sits on the rail destination (KitNav), and the rows are the same.
- **expanded / large:**
  - the badge sits on the rail or sidebar destination (§8.2: "also a count badge on the rail destination");
  - the row is the list-pane row in `KitScreen.twoPane`, and selecting it fills the detail pane with the conversation scrolled to the card instead of pushing a route. That is the host's `onOpen`; the row is unchanged.
- **Pointer and keyboard:** the row takes KitRow's hover highlight, focus ring and Enter to open. Right-click and long-press open no menu here (a pointing row has no row menu), and the semantics say so by having no custom actions. The badge is not focusable.

## Accessibility

- **The mark:** semantics "Needs you" (never colour alone, STATE-9). The span is part of the row's supporting text, so it is read with the words.
- **The badge:** excluded from semantics. The host's label gains ", 3 need you" through a merged label (§1.21: "the badge's count is part of its host's label").
- **The row:** one button node, "{title}, needs you, {who} on {server}, waiting 4 minutes, {ifIgnored}". Minimum height `rowHeightTwoLine`, target 48 dp or more.
- **Announcements:** a count change is announced once by the host's live region (the Inbox header or the tab), never by the badge or the row (A11Y-3).
- **200 % text:**
  - the row title wraps to 2 lines;
  - the supporting line wraps (up to 2 lines, with `ifIgnored` as the second sentence);
  - the badge text is clamped at `badgeTextScaleMax`, while the badge pill grows to fit.

## RTL

- The mark sits at the start. The badge sits on the child's top-end corner (`PositionedDirectional(end:)`) and mirrors.
- `who` and `server` are wrapped with `KitBidi.auto` by the row (these are names the person or server chose, COPY-30). The age comes from `intl`.
- The " · " separators sit between isolated runs.

## Motion and haptics

- A badge count change cross-fades on `KitMotion.quick`, and appearing or disappearing fades on `KitMotion.standard`. It never scales (MOT-2).
- Row insertion and removal is the host's `KitAnimatedRows`.
- **Reduced motion:** instant.
- **Haptics:** none. `send` fires when the person answers on the card, not here.

## Data safety and honest state

- **One source:** the count and the rows come from the attention source only (AUTO-11). The part has no way to add to or merge counts, so two surfaces cannot count differently if they pass the same number.
- **Words:** the row always carries the word and why (`reasonWord`) and what happens if ignored (AUTO-10). A green dot never marks a request.
- **Never answers:** the row has no answer buttons (LOOK-24, AUTO-17). Answering happens only on the KitRequestCard, and Inbox, Work and team rows point to it.

## Depends on

- **kit-KitStatusMark-v2** (C05, C25).
- **Existing:** `KitRow`, `kitCurrentSpan` (as the pattern for `span`), `KitAnimatedRows` (the host's).
- **kit-KitSince** (tier 1a; edge added, README.md): `KitSince(ticks: KitSinceTicks.minutes)` rebuilds the row's age once a minute, and `KitSince.ageLabel` gives the words ("4 min"), composed as `kitNeedsYouWaiting` "waiting {age}". No escalation happens here.

Depended on by: KitChecklist, KitTabSwitcher-v2, KitTopBar, KitNav, KitTaskCard, KitAgentStrip, KitRequestCard-v2 (C25).

## Tests required

In `test/kit/kit_needs_you_test.dart`:

1. `KitNeedsYou.mark()` is a `KitTaskMark` with `state: needsYou`, and its semantics label is "Needs you".
2. `span(count: 1)` is "Needs you · ". `span(count: 3)` is "3 need you · " (English plural). Arabic uses all six plural forms (COPY-23).
3. `badge(count: 0)` returns the child with no badge in the tree. At 5 it shows "5". At 120 it shows "99+". The host's merged semantics label ends with ", 5 need you".
4. `row(...)`: tapping calls `onOpen` once. There are no answer actions, no `KitRowMenu` and no custom semantic actions. The semantics include the reason word and `ifIgnored`.
5. `row` without `reason` or `ifIgnored` does not compile (they are required parameters). An empty `ifIgnored` asserts (G37).
6. `who` and `server` are bidi-isolated: in an Arabic locale, a Latin server name does not reorder the separators (golden plus text-run check).
7. Under reduced motion a badge change settles after one `pump()` (G8).
8. Keyboard (G14x, desktop capabilities): Tab reaches the row, Enter calls `onOpen`, and right-click opens no menu.

## Galleries required

`test/goldens/kit/kit_needs_you_golden_test.dart`, DPR 3, Android platform.

- **Declared states × dark and light at 412×915:**
  - marks and spans in a list of `KitRow`s;
  - badges on a dock-tab stub, a top-bar pill stub and a server row (0, 3, 99+);
  - the pointing row (single, and 2-line at a long title);
  - the three reason words.
- **Default (rows)** × dark and light at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Text 2.0 and Arabic** (rows, badges) at 412×915 and 1280×800.
- **Names:** `kit_needs_you_<state>…png`.

## Non-goals

- The attention source: counting, dedupe across servers, ordering and cancelling notifications (the wave-3 slices under G38).
- The request card and its answer (KitRequestCard-v2, KitRequestSheet).
- No notification rendering. Notifications reuse `reasonWord` and `span` words through l10n only.

## Open questions

None. The G37 fields (`reason`, `ifIgnored`) and the `row` builder are taken from STANDARDS §18 and LOOK-24, which outrank K2 §1.21. The coordinator should add `row` to K2 §1.21.
