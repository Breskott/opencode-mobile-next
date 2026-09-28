# Fix backlog from emulator QA of build 2058 — 2026-09-28

Sources: the Codex (gpt-6-luna) emulator passes (README.md here, 141 screenshots) and the coordinator's own review of every screenshot. Build 2059 already contains the final-suite fixes; items below are open on 2059 unless marked.

## P1 — broken or blocking
| ID | Where | Problem | Evidence | Fix direction |
|---|---|---|---|---|
| B1 | Relaunch on the in-app server | After a cold relaunch the app tries to start OpenCode inside the app ("Starting…", 131/147) but ~18 s later lands on "OpenCode inside the app is stopped" and waits for a manual Start and connect (136/137/142). The automatic start fails silently. | 131, 133, 136, 137, 142, 147 | Find why the auto-start ends stopped (timeout? start refused? runtime not ready after process death); retry once automatically, and if it truly fails say why in plain words (Details) instead of the generic stopped page. |
| B2 | This phone setup gate | A nominal 2 GB device reports 1,972 MB and setup is refused ("needs at least 2048 MB"). Coordinator decision: accept nominal 2 GB — hard minimum 1,800 MB total RAM; between 1,800 MB and 3 GB allow with a plain "may be slow on this phone" note. Keep the gate on total RAM (never memoryClass). | 04, 05, 96 | Change the threshold + copy + tests. |

## P2 — visual / UX
| ID | Where | Problem | Evidence | Fix direction |
|---|---|---|---|---|
| B3 | Onboarding at 2.0 font | The row icon draws over the supporting text ("Connect~~to an~~agent"); the list is cut at the bottom. | 28, 29, 30 | Kit row leading-icon layout at large text; make the page scroll. |
| B4 | Add server, Back on step 1 | "Discard server changes? The server has not been saved." appears even when nothing was entered. | 19–25 | Only ask when the form is dirty. |
| B5 | App frame after cold relaunch | A thin bright green outline around the whole viewport (focus ring on the root?). Seen once, not reproduced in pass 2. | 51–53 | Find the focus owner at startup; never show a focus ring without keyboard navigation. |
| B6 | This phone during setup | The app-wide "127.0.0.1 isn't answering · Reconnect to 127.0.0.1" line sits on top of every setup step for a different server. | 97–117 | While the page is about the phone's own server, show that line compactly or only once (the status slot rule: page says it once). |
| B7 | Cold start on the in-app server | A washed-out/faded "stopped" page flashes before "Starting…" (133). | 133 | Don't render the stopped state while the auto-start is pending. |
| B8 | "Nothing is listening on this device" copy | "…reached through a tunnel that ends here. Neither answered." reads oddly. | 95, 106, 110 | Plain words: what was tried and what to do. |

## P3 — polish / copy
| ID | Where | Problem | Evidence |
|---|---|---|---|
| B9 | Server address error | "HTTP is allowed only for localhost, 127.0.0.1 or [::1]" and the Tailscale "Enter an HTTPS origin with a valid port (1–65535). Remove paths, credentials, query text and fragments" are jargon. | 18, 45, 57 |
| B10 | Providers list | Rows say "Server environment: 302AI_API_KEY" — env-var names on the first line; move under Details. | 78 |
| B11 | Tools tab | Raw tool descriptions ("Use this tool when you need to ask the user questions during execution…") shown as-is. | 87 |
| B12 | Demo chat | Typing "/" mid-text shows nothing (demo has no commands) — say so or offer the demo's actions. | 47–50 |

## Not covered yet (needs a third pass)
Inbox (incl. other servers), Project tab, every Settings page one level deep, Stop on an in-flight reply, host server stop → reconnect wording, airplane mode recovery, the new Move from Termux flow, AI setup with a real config, MCP catalogue toggle on/off against a real server. The emulator process exited several times under load (pass 2).
