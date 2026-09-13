# E7 chat, background results and CHAT-08

Finish line: the existing chat journey is localized, readable in RTL and large text, with canonical background results presented as outcomes and everyday menu actions available before secondary preferences/mutations.

Non-goals: no new background execution protocol, fabricated parent reply, model/provider request, server mutation, cross-device handoff, or APK publication.

Scope: the chat library and its part files; tool/agent/transcript widgets; narrow notice metadata preservation in the domain Part and OC2 mapper; focused tests and captures. This worktree owns the complete journey. Source base a4b2433; branch fix/e7-chat-results. Other agents own other worktrees.

## Findings and behavior

- CHAT-08: the previous sheet placed always-visible display toggles between six view chips and up to ten session operations. The new first group keeps Results, Find and conversation views; Display and context and Session actions expand progressively. Capabilities still gate all operations. Opening/grouping does not submit or clear the composer draft.
- Background result presentation: only canonical OC2 synthetic notices with allowlisted source/child/agent/state metadata and an exact matching wrapper receive a result card. The actual server result is shown without its wrapper; state and agent stay visible. Original text remains under Server message details. Unknown or malformed messages retain the original generic notice. No message is created and parent output remains separate.
- Child links require a known child-parent relation; async navigation rechecks that relation and existing profile/location/draft protections.
- E7: app-authored labels, summaries, errors, command descriptions and accessibility labels are moved into ARB. User/server text, code, file paths, slash commands, IDs and wire enums are not translated. Separate frozen Arabic translation fragments preserve placeholder contracts.
- Direction: chrome uses directional padding/alignment. Commands/protocol details remain LTR. Running agent chips grow with text scaling instead of clipping inside a fixed 48dp strip.

## Verification

In progress. No test or complete-localization claim yet. Heavy checks are serialized by the coordinator. Canonical contract is documented in ../daily-flow-repair/async-agent-contract.md; the pinned beta18600 synthetic metadata is retained without passing arbitrary metadata to UI.
