# Chat performance handoff for Claude

Source baseline: `c8e02abf`, 2026-09-28. This slice changes only its synthetic
test and this report. Claude owns `lib/ui/screens/chat_screen.dart`, its
`chat/*.dart` parts, and `lib/ui/kit/chat/**`; no production chat file was edited.

## Measurement contract

`test/perf_chat_test.dart` pumps the real `ChatScreen`, real controller event bus,
real transcript list and real Markdown widgets with a fake history API. No network,
credentials, profile persistence, or production session is used. Fixtures cover
1,000 and 5,000 parts in two shapes: alternating one-part user/assistant messages,
and one assistant message containing all the text fragments. The latter matters:
message virtualization alone cannot bound the size of one message.

After hydration settles, each fixture receives ten deltas separated by 60ms of
test-clock time and one burst of 100 deltas. Existing `debugChatStreamFlushes`,
`KitMarkdown.debugParseCount`, and Flutter's `debugOnRebuildDirtyWidget` count the
work. `PERF_CHAT` output contains only synthetic sizes, counts and stopwatch times.
The standalone `PERF_CHAT_CACHE` case grows a tail ten times after a completed
heading, paragraph and fenced code block.

Stopwatch values measure **debug widget-test pump CPU/wall time**, including
framework layout and paint recording. They are not phone cold-start time, raster
frame timings, a 60Hz FPS claim, or profile-mode release evidence. Rebuild/parse
counts are the deterministic comparison; timing is informational and has no
flaky threshold. The tests assert no exceptions, bounded mounted message rows,
and reuse of settled Markdown/code. Parent release report records actual runs.

## Measured baseline

Root ran all five chat cases in `/tmp/oc-perf-baseline.log`; all passed. The
combined baseline command exited 1 because of two expected memory regression
assertions outside this chat suite. The following are the actual chat outputs,
rounded to milliseconds. One load is measured per fixture; the burst runs after
the ten spaced updates. These are single debug runs, not statistical estimates.

| Shape | Parts | Mounted turns after settling | Hydration + initial pumps (ms) | Ten spaced delta pumps (ms) | 100-delta burst pumps (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| One part per message | 1,000 | 5 | 700.723 | 1,003.090 | 96.267 |
| One part per message | 5,000 | 5 | 369.645 | 947.444 | 87.719 |
| One fragmented assistant message | 1,000 | 1 | 967.936 | 1,033.294 | 104.588 |
| One fragmented assistant message | 5,000 | 1 | 9,939.781 | 15,987.840 | 1,997.980 |

| Shape / batch | Screen builds | Turn build callbacks | Markdown build callbacks | Markdown parses | Stream flush callbacks | Global controller notifications |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Separate messages, ten spaced deltas (both sizes) | 10 | 190 | 190 | 10 | 10 | 0 |
| Separate messages, 100-delta burst (both sizes) | 1 | 19 | 19 | 1 | 2 | 0 |
| Fragmented message, ten spaced deltas (both sizes) | 10 | 10 | 10 | 10 | 10 | 0 |
| Fragmented message, 100-delta burst (both sizes) | 1 | 1 | 1 | 1 | 2 | 0 |

The framework hook counts element build callbacks, including any newly created
elements; 19 callbacks per screen build does not mean 19 distinct visible turns.
The settled viewport contains five turns in the separate-message cases, and
offscreen/cache work may build additional elements. Two burst flush callbacks
collapse into one observed screen build in this pump sequence; neither counter
should be presented as one callback per burst. The cache probe separately shows
ten growing-tail parses with **zero settled code or heading rebuilds**.

The largest observed problem is the single 5,000-fragment reply: about 15.5 times
the 1,000-fragment spaced-batch time, despite the same ten screen builds and ten
Markdown parses. A giant row defeats the benefit of mounting only one turn.
Source inspection identifies both repeated prefix materialization in text
merging and full-source parsing/layout of the Markdown block column as plausible
contributors. These timings do **not** isolate their individual costs or prove
that one proposed fix removes the whole regression. Separate-message timing is
slightly lower for 5,000 than 1,000 in this single run, illustrating why timings
must not be treated as a linear scaling estimate or device latency.

No chat production optimization is included in this job because these files
remain Claude-owned. These numbers are the baseline for the fixes below; there
is no claimed chat before/after speedup. Re-run the same test after each owner
change and record results in the release report.

The post-restart final run passed all five chat cases again, within the 19-test
performance manifest (`/tmp/oc-perf-final-probes-resumed.log`). Counters matched
the baseline. The unchanged 5,000-fragment fixture measured 6,575.114 ms loading,
13,851.556 ms for ten spaced pumps and 1,600.724 ms for the burst. Those repeated
samples show the same hotspot; their lower times do not establish an improvement
because this job changes none of the chat production paths.

## Existing safeguards confirmed in source

- `lib/state/connection.dart:3345` deliberately avoids global notifications for
  text part updates and forwards events on its bus at line 3371. Do not add
  controller-wide notifications to optimize chat.
- `lib/api2/gateway_events.dart:338` maps typed v2 text/reasoning events to neutral
  part events; `_ordinalPart` at line 662 emits incremental deltas. The test starts
  at this neutral event boundary, not at HTTP/SSE decoding.
- `lib/ui/screens/chat_screen.dart:1598` coalesces a synchronous delta burst then
  flushes at most once per 50ms while deltas keep arriving. Model mutations and
  event versions stay synchronous; changing this ordering risks lost hydration
  races. `message.part.updated` still invokes screen `setState` at line 1423.
- `lib/ui/screens/chat_screen.dart:6809` already uses a reversed
  `ScrollablePositionedList.builder`, with a repaint boundary. The cost is not
  mounting 5,000 ordinary message rows; the whole-history derived work still runs
  before the builder and a single huge message remains one large row.
- `lib/ui/kit/chat/kit_markdown.dart:273` caches identical Markdown and reuses
  settled block widgets by source. Open fences defer syntax highlighting until
  closure (line 352). Preserve those behaviors.
- `lib/ui/kit/kit_code_block.dart:105` has a 48-entry grammar-node cache and a
  20,000-character grammar limit. Spans are recolored for the current theme.
  `lib/ui/kit/kit_diff_view.dart:374` caches file indices weakly by `KitDiffFile`
  identity (`Expando` at line 435); reuse immutable file instances to hit it.

## Exact changes for the chat owner, in priority order

1. **Make fragmented text merging linear.**
   `lib/ui/screens/chat/message_view.dart:665` (`_mergeTextParts`) calls
   `buffer.toString().endsWith('\n')` for each fragment at line 673. Repeatedly
   materializing the full prefix makes many-fragment merging quadratic in total
   text. Keep an explicit `hasContent` / `endsWithNewline` state updated from the
   last nonempty fragment; materialize the buffer once at the end. Preserve the
   existing whitespace-only skip, separator, first-part identity and folded-work
   mark exactly. Add parity cases for whitespace-only fragments, CRLF, explicit
   newline edges and synthetic IDs, then rerun both fragmented fixtures. This is
   the smallest localized first fix; no rendered output needs to change.

2. **Cache transcript derivation by changed turn, not by list identity.**
   `chat_screen.dart:7325` calls `_timelineDisplayParts` for every screen rebuild;
   `message_view.dart:581` folds/scans every loaded part and allocates display
   lists. `_turnActionOwners` at line 62 rescans every message. Build a turn index
   at hydration/insert/remove boundaries, invalidate the changed turn and any
   adjacent turn whose ownership can change, and retain the settled prefix.
   A busy/idle change must invalidate the live tail's folding and footer; inbox
   visibility, error/finish metadata, timestamp preferences, compaction,
   history reset, deletion, prepend and pending-message reconciliation also
   invalidate their affected derived state. Do not memoize on `_messages`
   identity: parts and the list are mutated in place. Feed immutable snapshots
   or explicit per-message/turn revisions into the derived cache.

3. **Index delta targets and narrow notification scope.**
   `chat_screen.dart:1665` linearly finds a message; line 1821 linearly finds its
   part on every delta, before any 50ms UI coalescing. Maintain message-ID and
   part-ID/call-ID indices, rebuilt on authoritative hydration and updated on
   insert/remove/reconcile. Preserve type-aware matching, deferred deltas,
   hydration versions, profile/location guards and duplicate identities. After
   the turn cache is in place, publish the changed row/turn to a listenable and
   stop rebuilding the entire `ChatScreen` and composer for text-only changes.
   An unknown part must still queue until its message/part arrives. Do not simply
   drop/coalesce model events or postpone their version updates.

4. **Bound a single giant reply.**
   `lib/ui/kit/chat/kit_markdown.dart:299` reparses/splits the entire growing
   source, even though it reuses settled block widgets; line 488 mounts every
   Markdown block in one `Column`. For thousands of paragraphs this defeats
   message-level virtualization. A future owner change can expose stable parsed
   block segments to the transcript's lazy list, keeping streaming-tail parsing
   separate. Preserve cross-block selection, copy/export exact text, scroll
   anchors, find hits, accessibility traversal, code fences/tables and action
   ownership. This is a larger structural change; first land linear merge and
   derived-state caching and remeasure. A nested shrink-wrapped list would still
   lay out all blocks and does not solve this.

5. **Keep cache boundaries truthful.**
   The Markdown cache already avoids settled heading/code rebuilds. Do not replace
   it with an unbounded process-global transcript cache. If adding append-only
   parsing, retain a complete-parse fallback for edits earlier than the tail,
   CRLF changes, an open fence/table becoming complete, language changes and
   block-builder changes. Code grammar nodes may be shared independently of
   theme; theme-colored spans cannot use a source-only cache key. Diff-file
   indices depend on immutable file identity and must not survive in-place
   segment mutation. Clear any new profile-owned cache on profile deletion.

## Verification recipe for owner changes

Run the pinned Flutter command through the shared machine lock:

```sh
OC_TEST_SLOTS=1 tool/qa/machine_lock.sh test -- \
  "$HOME/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter" \
  test --no-pub --concurrency=1 test/perf_chat_test.dart --reporter expanded
```

Compare the same fixtures and viewport, with ten spaced tokens and 100 burst
tokens, before/after each owner change. Record mounted rows, screen/turn/Markdown
rebuilds, Markdown parses and stream flushes alongside stopwatch values. For the
localized text merge, expect the exact same counters and text with lower
fragmented CPU cost; for row-level notification, require settled turns and the
composer to rebuild zero times for text-only deltas. Test bursts, background
events for other sessions, late hydration, part removal, history prepend/reset,
find, selection, scrolling away from latest, reduced motion and disposal. Existing
focused suites include `chat_live_events_test.dart`, `markdown_streaming_test.dart`,
`chat_transcript_placement_test.dart`, `stable_chat_layout_test.dart`,
`v2_transcript_rows_test.dart`, `kit/kit_markdown_test.dart` and
`kit/kit_diff_view_test.dart`.
