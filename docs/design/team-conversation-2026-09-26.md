# The AI Team as a conversation (2026-09-26)

The owner, watching his team on his phone: "Why isn't these rendered as regular conversations in the already built glorious chat page in a way?" and "First think about sustainable discoverable UI that can fit our current pattern of main agent and sub agents". He asked the coordinator to decide "based on the UI ux rules and world top tier UI ux principles and personas".

## Decision

**An AI Team task is a conversation, and its workers are its sub-agents.**

- The team conversation is assembled by the app from the team's own data (option A).
- It is rendered on the chat page with the chat's own parts.
- A real "lead agent" (option B) can later replace the assembler without changing the screen.

### Why A (design standard §1–§10, `docs/design/principles.md`, ui-ux-pro-max)

- **One mental model** (consistency; Jakob's law).
  - The person already knows the chat: a prompt, a reply, steps folded under one line, a sub-agent card that opens its own conversation, question and permission cards, the family strip.
  - A separate "AI Team world" doubles what they must learn. This is ledger rows 5, 18, 20–22.
- **The persona.**
  - A developer on a phone, one hand, attention in bursts, delegating work while away.
  - Memory and battery are limited: the owner's phone runs `opencode serve` at about 410 MB and each worker at about 550 MB.
  - A lead agent (B) adds another cold agent before anything happens.
  - Speed and calm matter more than conversational flourish.
- **Truth over narration.**
  - A shows the team's real state (tasks, steps, sessions, gates) from Gas City.
  - A lead agent retells it and can be wrong. Ledger row 21 shows how quickly a wrong status destroys trust.
- **Progressive disclosure.**
  - The conversation is the surface.
  - A worker card opens that worker's real session.
  - Engine words, addresses and versions stay under Technical details.
- **Robustness.** Fewer moving parts on a phone. B remains a later swap of who writes the lead's lines.

## The model

| Chat concept | In a team conversation |
|---|---|
| Your prompt | The task you gave the team (its title and full text) |
| The reply | The **lead**: the team's plan and progress, written by the app. Examples: "Planned 5 steps", "Started a worker on Set up React", "Handed to review", "Merged into main". Each line comes from a real event, in plain words, with a time. |
| Steps (folded work) | The task's steps, shown with the same step marks as the task Overview (`KitTaskMark`/`KitStatusMark`) and folded under one line when there are many |
| Sub-agent card | One card per worker or reviewer session: role in plain words, name, what it works on, its state from the **session** (not the agents list), and elapsed time. Tap opens its conversation in **watching** mode (`feat/team-agent-chat`). |
| Family strip | The lead, plus every worker and reviewer on this task, marked as running, waiting or done |
| Question and permission cards | Gas City gates (choices, approvals, "Needs you"), answered in place with the existing cards |
| Review / merge | "Ready to merge · Review changes", with the existing merge flow and its receipt |
| Status line | One "Now" line: what is happening and what happens next ("furiosa is starting · usually under a minute", "Waiting for the next check · about every 2 min · waited 3 min"), honest after 8 s (§3) |
| Composer | "Message the team…". It goes to the planner or the task (the existing Gas City message/nudge path); nothing is typed into a worker's OpenCode session directly. |

## Discovery (with `ds/team-discover`)

- **New conversation offers "Solo · Team".**
  - Solo is today's chat.
  - Team starts a team conversation.
  - If the team isn't set up on this server kind, Team opens the short intro and its "Set it up" path.
  - The choice is remembered per server.
- **The Work tab and All conversations list team conversations** with a small team mark.
  - They carry the usual state line ("Working · 2 of 5 steps · 3 min", "Needs you").
  - They are no longer a separate card. The quiet discovery entry stays for people who have never used the team.
- **The AI Team page** becomes the team's own page, reached from a team conversation's header and from Settings. It covers:
  - agents,
  - where the team runs,
  - on/off,
  - speed and cost.

  It is no longer where work happens.

## Speed (separate track, same goal: "everything should be hot and in seconds")

Measured on the owner's phone (UTC, 2026-09-25):

| Time | Event |
|---|---|
| 19:49:03 | Task created |
| 19:51:05 | Worker session created (**2 min** waiting for the next check) |
| 19:51:07 | `opencode acp` process started (546 MB) |
| ~19:55 | First output (**~4 min** cold start plus the first model call) |

Targets:
- The task reaches a worker within **5 s**: dispatch at once instead of waiting for the patrol.
- First output within **~20 s**: workers run against the already-warm `opencode serve` instead of each starting a cold OpenCode, if `opencode acp` can attach; otherwise one pre-warmed worker, with its memory cost stated in the UI.

## Not in scope

- A real lead agent (B).
- Team conversations on a computer's Gas City without an OpenCode session store the app can read. They fall back to the assembled lead and Live output.
