# FactsBook F4: proof on an emulator against the real node (2026-10-11)

Evidence record. Real `factsbook-node` (release build, api 1.1) serving a throwaway vault with synthetic data on `127.0.0.1:8787`, reached from an Android x86_64 emulator (AVD `FB_F4`, never the owner's phone) through `adb reverse`. App: release APK built from `feat/factsbook-ui` with `--dart-define=OC_FACTSBOOK=true`, dark theme, device PIN set. Screens are 720 px wide, one full phone screen per image. The device PIN prompt sets `FLAG_SECURE`, so it cannot be captured; where an approval needed it, the PIN was typed blind and the result is the next image.

## What worked end to end

Pairing with a one-time code and an owner key; Memory section on Chats home; About you (needs-you, list, thing page, search); Memory care approve (owner-signed, device PIN), edit-then-approve, reject, stale handling; Reminders list with a weekly repeating reminder; Areas and sharing toggle (signed); Settings cap (signed); Status including signed-history verification against the pinned fingerprint; capture while the node is down (kept on the phone), node restarted, the outbox drained to the node's own inbox; export of a node-held note; discard; the no-device-lock message; Arabic with RTL; cold start, chat screens and back navigation with the new `FlutterFragmentActivity`.

## Images

| File | What it shows |
| --- | --- |
| 01-set-up-factsbook.png | Set up FactsBook: the address and one-time code form before pairing. |
| 02-chats-home-memory.png | Chats home with the Memory section: two Needs-you rows, recent things, About you and Add something. |
| 03-about-you-needs-you.png | About you on its Needs you tab: changes to review and the note not saved yet. |
| 04-about-you-list.png | About you list with the Cards, People and Documents filters and the locked-notes line. |
| 05-thing-page.png | A thing page (Sam) with its fact, source line and the border legend. |
| 06-memory-care.png | Memory care: proposals with Approve, Edit, Reject and Skip. |
| 07-memory-care-edit.png | The edit-before-approving sheet. |
| 08-memory-care-stale.png | A proposal that changed after it was proposed: plain words, nothing applied. |
| 09-memory-care-rejected.png | After Reject: "It will not be proposed again." |
| 10-memory-care-approved.png | After an owner-signed Approve: "Approved." |
| 11-reminders.png | Reminders list: a one-off and a weekly repeating reminder. |
| 12-reminder-check-sheet.png | The check sheet for a new monthly reminder (title, repeat, day, time, zone, clock-change note). |
| 13-reminder-locked-by-node.png | The node refuses a sensitive-looking title; the app says it is in the locked folder. |
| 14-areas-and-sharing.png | Areas and sharing, with the per-area read toggle and storage line. |
| 15-settings.png | FactsBook settings. |
| 16-status.png | Status: modules, last check, cloud copy, signed history verified. |
| 17-not-saved-yet.png | Not saved yet with a note kept on the phone. |
| 18-discard-confirm.png | Discard confirmation: what is lost, in plain words. |
| 19-add-something.png | Add something, note typed while the node is down. |
| 20-saved-on-phone-node-down.png | The same note kept on the phone because the node is unreachable. |
| 21-not-saved-held-by-node.png | After the node came back the note drained and is now held by FactsBook. |
| 22-export-sheet.png | Export of a node-held note as an encrypted object. |
| 23-search-results.png | Search for "books" with the word-match caveat and source line. |
| 24-about-you-map.png | Map tab: says it is not available yet. |
| 25-about-you-watching.png | Watching tab: says it is not available yet. |
| ar-01-chats-home-memory.png | Arabic Chats home with the Memory section, right to left. |
| ar-02-memory-care.png | Arabic Memory care with mirrored actions. |
| ar-03-thing-page.png | Arabic thing page. |
| ar-04-about-you.png | Arabic About you. |
| ar-05-reminders.png | Arabic Reminders, repeating schedule in words. |
| ar-06-status.png | Arabic Status. |
| ar-07-no-device-lock.png | Approving with no device lock set: plain-words Arabic message and how to fix it. |

Images 24 and 25 were taken before item 10 below, so their heading still reads "Coming in a later slice". Image 01 was taken with an earlier build.

## Bugs in the app, found on the device and fixed (commit 30df2d10b and the follow-up)

1. Four parallel reads made the node answer 429; requests now go one at a time with up to three 429 retries.
2. Review list showed approved, rejected and stale items; it now shows only proposed ones.
3. Body-less POST (retry) got 400; non-GET writes now always send `{}` as JSON.
4. Capture event keys with long digit runs were refused by the node; keys are now letters only.
5. Needs-you rows showed a dangling "·" separator.
6. Stale "reviewing comes in a later slice" copy; wrong "stored on this phone only" intro and discard text for notes the node holds.
7. A 64-hex source was shown raw; area slugs and module names were shown raw; duplicate Cloud backup rows on Status.
8. "The reminder was not made. Try it again from the note." was misleading.
9. The node's always-present time adjustments forced a second Save tap with raw node text; they are now non-blocking and a clock-change note is always shown.
10. Follow-up: Status rows said "since 9 min ago" (and in Arabic "since ago"); now "updated ...". "Coming in a later slice" is now "Not available yet".

## Backend issues and contract mismatches (backend repo untouched)

a. `POST /v1/things` returns 423 `locked_no_key` for every title outside the synthetic whitelist and always for card, document, subscription, warranty, account, bill, invoice and health kinds, so Alex, [Bank A] Visa, Passport and Dentist could not be seeded as things. Arbitrary captures return 200 `queued` with reason `classification_failed`.
b. `POST /v1/reminders/parse` returns 200 for "Dentist" (confirmable) but `POST /v1/reminders` returns 423 `locked_no_key` (image 13).
c. Concurrent requests get 429 `slow_down` with `retry_after_s` 60 (node try-lock contention); indistinguishable from real rate limiting.
d. `POST /v1/outbox` event keys with long digit runs are refused (`status: refused`, key empty, `bad_request`): keys go through the content classifier. `cap-abc` is accepted, `cap-1791720000000001` is refused.
e. `GET /v1/review` includes approved, rejected and stale items; the contract lists no state filter.
f. Approving one proposal for a thing bumps its revision; sibling proposals for that thing then fail with 412 `stale_approval` (even Reject) and are not re-proposed (image 08).
g. Preview `adjustments` is always non-empty boilerplate (a DST note plus "Occurs at ..."), so it cannot signal a real adjustment.
h. `GET /v1/inbox/pending` shows only the calling client's entries.
i. A fact's `source` after approval is a 64-hex hash, not an `itm_` id.
j. `POST /v1/things` with a duplicate title returns 412; the contract implies conflict.
k. `/v1/areas` returns slugs beyond the contract's examples (general, home, travel, unsorted, id).
l. A POST or PATCH with no body and no content type returns 400.

## Not done

- Alex, [Bank A] Visa, Passport and Dentist as things (backend issue a); a repeating Dentist reminder (issue b). The repeating reminder shown is "Read books" (weekly).
- The device PIN prompt itself cannot be screenshotted (FLAG_SECURE).
- 24, 25 and the Status rows were not re-photographed after the last copy edits (item 10). A fresh APK is needed to see them.
- Thing page for a card, document and person with real data (issue a).
- Environment note: the host's global OpenCode config was invalid for this OpenCode build ("Unrecognized key: compaction"), which made the chat server answer 500 on `/session`; the demo server was started with a clean `XDG_CONFIG_HOME`. Not an app bug.
