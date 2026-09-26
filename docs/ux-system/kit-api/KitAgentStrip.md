# KitAgentStrip — frozen API (wave 0, 2026-09-26)

Group: chat. Unit `kit-KitAgentStrip` (wave 1, tier 1c; after kit-KitStatusMark-v2 and kit-KitNeedsYou, C25, plus the edges in README.md). In wave 2c `lib/ui/kit/chat/kit_agent_strip.dart` joins chain link chat-4 (C03, C38). Spec: kit-v2.md §9.2 (chat parts; §5 "team conversation: used once (agent strip)", overridden by §9 kit-only); cut review C24 (`lib/ui/widgets/agent_color.dart`, 14 `Colors` literals, moves into this unit: "moves onto theme roles inside the kit"); team-conversation-2026-09-26 (the family strip: "the lead, plus every worker and reviewer on this task, marked as running, waiting or done"; a tap opens the worker's conversation in watching mode; state from the session, not the agents list). Rules: STATE-9, LOOK-4, LOOK-6, LOOK-24, COPY-13, A11Y-8, KIT-3.

## Purpose

The row of who is working on a team task, under the conversation's header: the lead, then each worker and reviewer, each with its state mark and word, so the person sees at a glance who is running, who is waiting, who needs them and who is done, and can open any worker's own conversation with one tap.

## Replaces

- **Map:** `team-conversation#team-conversation-family` (kit-v2.json module:team conversation; kitGap KitAgentStrip; note "KitStatusMark scaled .8") (1 element).
- **Code:** `_TeamFamilyStrip` in `lib/ui/screens/chat/team_conversation_view.dart` (:828, chat-4), with its `Transform.scale(scale: .8)` mark, the hand-built `InkWell` + `Container` stadium chips and the `ListView` strip (part of that file's G16 count of 26: Transform 1, InkWell 2, Container 1, Text, Icon; brought to zero by chat-4). Its exhaustive `switch (mark)` word mapping (:884) becomes `KitTaskMark.wordFor`.
- **Colours:** `lib/ui/widgets/agent_color.dart` (in this unit's write set; 14 `Colors.*` literals, a G17 ratchet entry): `agentColor`, `AgentColorScope`, `agentColorFor` and `agentFallbackColor` keep their signatures (R11, KIT-43, no `@Deprecated`; `/// Retired by kit-KitAgentStrip: use KitAgentTint`) and forward to `KitAgentTint`, so `command_launcher.dart:535`, `tool_card.dart:1462` and `pickers.dart:794` keep compiling. The file's `Colors` count goes to zero.

## File

`lib/ui/kit/chat/kit_agent_strip.dart` (new). `lib/ui/widgets/agent_color.dart` becomes a forwarding layer.

## Public API

```dart
/// One agent on a task: the lead, a worker or a reviewer.
@immutable
class KitAgent {
  const KitAgent({
    required this.id,
    required this.name,       // the short name ("furiosa"), or the role word when it has none
    required this.state,      // from the agent's session (the team decision), never the agents list
    this.role,                // "Lead", "Worker", "Reviewer" (team_vocabulary words, COPY-13)
    this.paused = false,      // a heat pause or a force stop the app can resume (waiting or working only)
    this.onOpen,              // opens its conversation in watching mode; null: not tappable (the lead)
    this.key,                 // today's ValueKey('team-conversation-family-<id>' | '-lead')
  }) : assert(!paused || state == KitTaskState.waiting || state == KitTaskState.working);
  final Object id;
  final String name;
  final KitTaskState state;   // waiting, working, needsYou, done, failed, stopped
  final String? role;
  final bool paused;
  final VoidCallback? onOpen;
  final Key? key;
}

/// Who is working on a team task, in order: the lead, then workers and
/// reviewers as they joined. A team conversation arranges it under its
/// header (team-conversation-2026-09-26); each agent opens its own
/// conversation. Chat parts follow the transcript turn model (STATE-16,
/// KIT-41): this strip sits outside the turns and never inside one.
///
/// States: mixed, all working, needs you, paused, all done, lead only,
/// overflowing, empty (KIT-12).
class KitAgentStrip extends StatelessWidget {
  const KitAgentStrip({
    super.key,
    required this.agents,     // empty renders nothing
    this.semanticsLabel,       // the group's name; null: "Agents on this task"
    this.stripKey,            // today's ValueKey('team-conversation-family')
  });

  final List<KitAgent> agents;
  final String? semanticsLabel;
  final Key? stripKey;
}

/// An agent's identity tint, moved from widgets/agent_color.dart onto the
/// theme's roles. Identity is carried by the name, never by colour (VL §1
/// "one accent"; KitAvatar's rule), so every agent gets the same quiet
/// role until the owner decides otherwise (Open question 1).
abstract final class KitAgentTint {
  /// `text2` for every agent. [serverColor] (the OpenCode agent's
  /// configured colour) is accepted and ignored for now.
  static Color of(BuildContext context, {required String name, String? serverColor});

  /// The same without a context, for the ColorScheme-only wrappers:
  /// `scheme.onSurfaceVariant`, which ThemeRoles sets from `text2`.
  static Color ofScheme(ColorScheme scheme, {required String name, String? serverColor});
}
```

**Frozen behaviour.**

- **Chips.** Each agent is a pill (`KitShape.pill`, `surface3`) at least 48 dp tall: its state mark (`KitTaskMark(state:, paused:)`; `needsYou` is exactly `KitNeedsYou.mark()`, the only attention look here, LOOK-24) at its designed size (no scaling transform), then the name in `label`/`text1`, one line (A11Y-8: a chip may truncate; the full name and role are in semantics and the tooltip). An agent with `onOpen` is a `KitTappable` with a hover step; the lead (no `onOpen`) is plain.
- **Order and count.** Agents keep the given order. There is no cap: the strip scrolls (compact, medium) or wraps (expanded, large), and never hides an agent behind "+3".
- **Words.** Each state's word comes from `KitTaskMark.wordFor` (Waiting · Working · Needs you · Done · Failed · Stopped · Paused), shown in semantics and in the tooltip; the visible chip shows the mark and the name (the mark is never the only carrier: its word is always in semantics, STATE-9).

**Kit copy** (ARB, `kit` prefix, en + ar): `kitAgentStripLabel` "Agents on this task", `kitAgentOpen` "Open {name}'s conversation" (hint), `kitAgentLabel` "{name}, {role}, {state}" (semantics; the role part is dropped when null). State words are KitTaskMark's.

## States

Declared (KIT-12): **mixed** (lead working, a worker waiting, a reviewer done), **all working**, **needs you** (one agent's mark is KitNeedsYou's), **paused**, **all done**, **lead only**, **overflowing** (more chips than fit: scrolling or wrapping), **empty** (renders nothing, no semantics node). No loading (the host shows the conversation's loading), no error (the conversation's not-answering state is the host's), no disabled (an agent that cannot be opened is simply not a button).

## Tokens

- ThemeRoles: `surface3` (chips), `text1` (names), `text2` (the tint, `KitAgentTint`), `accent` (the working mark and focus ring, via KitTaskMark and KitTappable), `attention` roles only through `KitNeedsYou.mark()`.
- KitText roles: `label` (names).
- KitTokens: `minTarget` (48), `space2` (between chips and mark-to-name), `space3` (chip side padding), `gutter` (the strip's side inset, from the host), `focusRingWidth(context)` (§0.5 step 2 seam). Shape `KitShape.pill` (pre-wave seam enum). Both are listed in `_new-tokens.md`.
- No new token.

## Adaptive

| Window | Layout |
|---|---|
| compact | one line, scrolling sideways inside the strip (never the page); the first chip starts at the gutter |
| medium | the same one-line scroller |
| expanded / large | chips wrap (KitChipWrap spacing) within the conversation pane |

- **Fine pointer:** hover step on tappable chips; a visible horizontal scrollbar on the scroller (`KitScrollbar` once kit-KitScrollbar merges; KIT-6); the tooltip repeats "{name}, {role}, {state}".
- **Keyboard:** each tappable chip is a Tab stop in order; Enter and Space open; focus scrolls the chip into view; the lead chip is not a Tab stop.

## Accessibility

- The strip is a group named `semanticsLabel`; each chip reads "{name}, {role}, {state}", tappable chips as buttons with the hint "Open {name}'s conversation".
- State changes are not announced by the strip (not a live region); the conversation's status line announces them once (A11Y-3).
- 48 dp chip height and targets, 8 dp apart; at 200 % text the chips grow in height, names truncate at the end with full names in semantics, the scroller keeps working and nothing overflows at 320 dp.

## RTL

- Chips run from the start edge (right under Arabic); the scroller starts at the start edge; marks sit before names, mirrored by directional padding.
- Names are data and are isolated with KitBidi.auto (COPY-30), so a Latin agent name keeps its order inside Arabic semantics.

## Motion and haptics

- A chip whose state changes swaps its mark (`KitSwap`, `KitMotion.quick`); a joining agent's chip appears at the end with a `KitMotion.quick` fade (paint only; no size animation). The working mark's own motion is KitTaskMark's.
- Reduced motion: nothing moves; one `pump()` settles (G8x).
- Haptics: none (MOT-11).

## Data safety and honest state

- Each chip shows the state the host read from the agent's session (the team decision: the agents list lagged on the owner's phone); the strip never infers a state.
- "Needs you" appears only through `KitNeedsYou.mark()` and only when the host says a request waits on that agent (LOOK-4, AUTO-9).
- A paused agent says "Paused", never "Working" (COPY-17 contradiction pairs).
- Identity colour is dropped rather than drawn in a role that means something else (an accent-coloured agent would read as "working", an amber one as "needs you"; LOOK-4, LOOK-6). The server's configured colour is kept in the data and can be restored by the owner's decision without an API change.

## Depends on

- **kit-KitStatusMark-v2** (C25): `KitTaskMark`, `paused`, `wordFor`.
- **kit-KitNeedsYou** (C25): `KitNeedsYou.mark()`.
- **kit-KitTappable** (tier 1b), kit-KitChip (`KitChipWrap` spacing; tier 1a), kit-KitMotionParts (`KitSwap`; tier 1a): edges added to the cut (README.md), no tier change. Existing `KitText`, `KitMotion`.
- Pre-wave seams: `KitShape.pill`, `KitTokens.focusRingWidth`, `KitBidi.auto`.

## Tests required

`test/kit/kit_agent_strip_test.dart`:

1. Agents render in the given order; empty renders nothing and no semantics node.
2. Each `KitTaskState` shows `KitTaskMark` with that state; `needsYou` shows exactly `KitNeedsYou.mark()`; no `Transform` scales a mark.
3. A chip with `onOpen` calls it once on tap, Enter and Space; the lead (no `onOpen`) is not a button and not a Tab stop.
4. Semantics: group label; chip labels "{name}, {role}, {state}" (role omitted when null); hint on tappable chips; not a live region; chips ≥ 48 dp tall.
5. `paused: true` with `done` asserts; with `working` reads "Paused".
6. compact (412 dp) with 8 agents scrolls sideways inside the strip with no overflow; expanded (1280 dp) wraps; nothing is hidden behind a count.
7. `KitAgentTint.of` returns `text2` for any name and server colour; the wrappers `agentColor`, `agentColorFor` and `agentFallbackColor` return the same neutral and compile with their old signatures; `agent_color.dart` contains no `Colors.` and no `Color(0x` (G17).
8. Desktop capabilities: Tab moves through tappable chips and scrolls each into view; the tooltip shows the chip's words.
9. Reduced motion: a state change settles after one `pump()`.
10. 200 % text at 320 dp, LTR and RTL: no overflow (G6).

## Galleries required

`test/goldens/kit/kit_agent_strip_golden_test.dart`, DPR 3, Android (TEST-9, TEST-20), under a KitTopBar-height header:

- States at 412×915, dark and light: `kit_agent_strip_mixed`, `kit_agent_strip_needs_you`, `kit_agent_strip_paused`, `kit_agent_strip_done`, `kit_agent_strip_lead_only`, `kit_agent_strip_overflow` (8 agents).
- Default (mixed) at 360×800, 915×412, 800×1280, 1280×800 (wrapping) and 1600×1000, dark and light.
- Default at text 2.0 and Arabic RTL (Latin agent names) at 412×915 and 1280×800, dark.
- About 26 PNGs.

## Non-goals

- Reading agents, sessions or states from Gas City (the host, chat-4; ARCH-1).
- The worker lines inside the conversation (`KitToolRow.agent`) and the team's settings page.
- Session families outside a team task (`session_relations_screen.dart`'s `_SessionFamilyHeader` may adopt the strip later; not in this unit).
- Choosing agent colours (see Open question 1).

## Open questions

1. **Agent colours (owner).** OpenCode lets a person give each agent a colour (`agent.color`), and today the app shows it (pickers, the sub-agent chip). The visual language keeps one accent, attention means only "needs you" and danger only destroy or stop, and KitAvatar says colour never encodes identity, so no theme role can carry an arbitrary agent colour without borrowing another role's meaning. Interim (this API): every agent is `text2`, and the server colour is accepted and ignored. The owner decides whether configured agent colours come back (for example as a small dot beside the name, never on text or marks), which would change only `KitAgentTint`'s body.
