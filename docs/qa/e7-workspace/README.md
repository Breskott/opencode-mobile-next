# E7 Workspace and Activity clarity

Finish line: Arabic-ready Workspace, Activity and cross-project session search preserve truthful status and project/session context, show one inventory continuation notice, and keep actions reachable in narrow RTL and large-text layouts.

Non-goals: new server APIs, session lifecycle redesign, background execution implementation, or changes to the shared glass/motion design.

## Findings and changes

| Finding | Before | Result |
|---|---|---|
| WORKSPACE-07 / inventory density | The return brief, empty state and footer could each repeat that the same inventory was incomplete. The [last delivered Android capture](../oc2-setup/native/delivered-cold-restart-ready.png) shows repeated loaded states. | The footer owns loading, continuation and load-error copy. Empty recent lists offer context; return briefs preserve actions, stale status and unknown read state. Partial archive inventories do not claim a total. |
| WORKSPACE-08 / search scope | Search sat next to Recent sessions while querying titles across the server. | Its tooltip and spoken label explicitly say session titles across every project on this server. The destination retains its across-every-folder hint; folder chips filter loaded results. |
| WORKSPACE-06 / scrolling | A lazy recent-row child began an entrance reveal each time scrolling rebuilt it. | Rows render immediately, matching other session sections. The existing busy marker, reduced-motion behavior and glass dock are unchanged. |
| E7 / untranslated UI | Navigation, permission/question entry rows, menus, confirmations, project context and relative-time/session-title helpers included app-authored English. | Owned app copy uses generated localization. 94 new keys have matching Arabic messages and placeholder metadata. Server text, paths, commands and wire values are preserved. |
| WORKSPACE-09 / bidi paths | In a rendered RTL capture, `/work/shop` became visually `work/shop/`. | Path-only labels/details explicitly use LTR; UI labels and user/server titles keep their interface/content direction. |
| E7 / filter height | Global search filters assumed 48dp at all font scales. | Filter height grows with the real user text scale. |
| WORKSPACE-10 / stale state | Stale form loading/error flags could make an unsupported forms connection look stale. | Form status contributes only when forms are a supported capability. Permission, question, connection and inventory uncertainty remain visible. |

Activity's request status and saved-server monitoring describe different scopes. Their unknown, stale, disconnected and permission-failure states remain intact. This slice does not mark sessions read, answer requests, move projects or alter stored project selection implicitly.

## Evidence

Pinned Flutter 3.47.2 / Dart 3.13.2 from Shorebird cache `e16cf749ccaa38d7050335ff305def49b1c7c84c`.

- `flutter pub get` and `flutter gen-l10n`: passed.
- Scoped analyzer: clean after resolving async-context and brace diagnostics. [Final log](analyze-final.log).
- Notice/helper/Workspace checks: 53 cases passed initially; a new error-state test assumed the wrong retry label. Its correction asserts the enabled retry action and passes. [Initial log](focused-notice-tests.log), [exact retry](focused-retry.log).
- Existing Global sessions, Activity requests/screen and Home navigation checks: 56 passed. [Log](focused-journey-tests.log).
- Font-loaded capture case: passed. [Log](capture.log). Four 320dp captures inspect normal and 2.5x RTL Workspace/Activity plus reachable continuation controls.
- Final RTL-path/global-filter/unsupported-form checks and refreshed captures are pending the serialized slot at this intermediate checkpoint.

Capture fixtures use synthetic server metadata and English UI with explicit RTL. They verify bidi geometry and scale without pretending to be the complete Arabic application. Full Arabic corpus/picker and physical TalkBack testing are integration gates owned by the coordinator.

## Shared localization helpers

UI callers pass the active `AppLocalizations`; optional fallback preserves existing non-UI callers/tests:

```dart
relativeTimeLabel(int milliseconds, {DateTime? now, AppLocalizations? l10n})
presentedSessionTitle(Session? session, {String fallback = 'New session', AppLocalizations? l10n})
sessionUsageLabels(Session session, {AppLocalizations? l10n})
```

ISO-stamped server placeholders become localized “New session”; real titles pass through. Root integrates the shared permission-title helper and supplies localization at remaining call sites outside this ownership set.

The [Arabic fragment](messages_ar.json) contains only these new keys; [English fragment](messages_new_en.json) aids deterministic integration. No credentials or private server content were read or included. No dependencies, shared-storage formats, CI, signing, release or live-server actions changed.
