# UX system mapping — standard procedure (v2, after the coordinator's pilot, 2026-09-26)

The owner: "can you exercise that yourself before you dispatch agents? See images, read codes, use this run to fine tune agents and SOP."

The coordinator mapped three different pages by hand: `servers` (connect), `embedded-pending-sends-strip` (converse) and `team-home` (delegate). The worked examples are in `docs/ux-system/map/_pilot.json`. They changed the procedure as follows.

## What the pilot found

1. **The ledger is stale in places.** Take `team-home`: its ledger still lists `team-home-segments` and `team-home-host-chip`, both removed by the AI Team redesign. So **the code is the truth for elements**. List the ledger ids that no longer exist in `ledgerStale`.
2. **A census render shows one fixture, not every state.** The `servers` render has no phone server, yet the page has four state-dependent phone sections: `LocalAgentServerEntry` (l.265), `TermuxRunningServerEntry` (l.290), `PhoneServerCard` (l.803) and `_PhoneSetupEntry` (l.858). Derive states from the code's branches. For each state, say whether it was `rendered` (with its image path) or is `codeOnly`.
3. **The same job starts in several places, and they disagree.**
   - On `team-home`, "Give the team a task" calls `showStartRunSheet` (`team_home_screen.dart:177`), while Solo · Team and the board call `TeamConversation.start`, which opens the task conversation. The same job ends in two different places.
   - On `servers`, "Add server" and "Connect OpenCode 2" start the same job.

   Record every such entry in `sameJobElsewhere` with the element ids and **where each one lands**. `duplicates` alone was too coarse.
4. **Shared chrome repeats on many pages.** Examples are the brand header (logo with bell, info and help), the dock and the connection banner. Map these once as the `chrome` id they use (`brand-header`, `title-header`, `dock`, `connection-banner`, `composer`) and flag pages whose chrome differs from their siblings'.
5. **Gates need their behaviour, not just their condition.** For every capability in `needs`, record what the page does when it is missing in `whenMissing`: `hidden` | `disabled` | `explains` | `offers-enable:<flow>`. This feeds the "don't have X, want X" analysis directly.
6. **Kit mapping works at the pattern level.** Map composite patterns (for example "server row = KitRow + KitRowIcon current mark + KitRowMenu"), not every `Text`. Mark `kit` as `KitX`, `KitX+custom` (say what diverges) or `none`, and propose `kitGap` only for a reusable pattern (for example `KitQueuedMessage`, `KitBrandHeader`, `KitNowLine`).
7. **Automation first** (the owner: "Why manual, it's all about automated dev right"). For each manual action, record `couldBeAutomatic` as `no`, or `yes: <how>`.
8. **Personas differ in what they need, not only in whether they use the page.** Use `personaNotes: {persona: "what they need here that others don't"}`.
9. **Evidence.** Cite the code as `file:line` and the image path for every non-obvious claim (`evidence: [...]`), so the result can be audited.

## Record shape (replaces the one in the dispatch prompt)

```json
{"pageId","area","title","kind","file",
 "journey":["primary","second?"], "module":"…", "chrome":"…",
 "needs":["capability ids"], "whenMissing":{"<cap>":"hidden|disabled|explains|offers-enable:<flow>"},
 "personas":["…"], "personaNotes":{"<persona>":"…"},
 "states":[{"id":"…","how":"rendered:<image>|codeOnly:<file:line>"}], "statesMissing":["…"],
 "info":["…"], "infoMissing":["…"], "actions":["…"], "actionsMissing":["… incl. undo/recover"],
 "entry":["…"], "exit":["…"],
 "sameJobElsewhere":[{"job":"…","here":"<element id>","elsewhere":"<pageId>/<element id>","landsOn":"<pageId>"}],
 "elements":[{"id","kind","kit":"KitX|KitX+custom|none","kitGap":"…|null","couldBeAutomatic":"no|yes: …","note":"…"}],
 "ledgerStale":["…"],
 "proposal":"keep|fix|merge-into:<pageId>|remove|redesign",
 "rationale":"…",
 "verticals":{"<id>":"issue|ok"},
 "evidence":["file:line","docs/qa/screen-census/…png"]}
```

## Order of work per page

1. Read the owner's verdict or note, if there is one.
2. Look at every rendered image.
3. Read the page file and the widgets it builds (states, gates, actions).
4. Check the ledger (entry and exit, stale ids).
5. Grep for other places that start the same job.
6. Write the record.
