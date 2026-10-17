# Audit slice: chatscreen (2026-10-14)

| ID | Verdict | Reason | Commit |
|----|---------|--------|--------|
| P1-4 | REAL (smaller than claimed) | The tip slot already gave way to a short window and, through `_nudgeSuppressed`, to any waiting request. It still showed over an open find. Now it also yields to the keyboard (`compactComposer`), an open find and a waiting request, explicitly. The three `Flexible(ListView)` wrappers are left: each is already bounded and the request card keeps its 30% floor. | 2bb702003 |
| P1-6 | FALSE | Send/Stop/Mic sit in a 48 dp `SizedBox` inside `KitTappable` (40 dp is only the painted disc), and `KitTappable` itself enforces `minTarget` 48 on the failed-send Retry and Details. A guard test now pins 48 dp for both. | 5e344e7c9 (test only) |
| P1-8 | REAL | `_hugWidth` measured the raw source. It now measures the drawn words (`kitMarkdownDisplay`: link label instead of address, marks dropped) and adds the chip inset (2 x space1) per file path in code. | 0bdb22762 |
| P2-4 | REAL (names differ) | The chat bar has no "New conversation" or "Review N files" action; the competing action was the running-work count, which came first and so took the phone bar's one slot. Collapse all steps now comes before it (after the transient Stop-reading). | 7814c873b |
| P2-6 | FALSE | A disc inset in the pill's corner cannot poke out of it (checked geometrically: the disc stays inside the 18 dp corner arc at the 4 dp inset). A circle is not meant to be concentric with the pill, and a square would change the composer look. No change. | none |
| P2-14 | REAL | Quote rail was a 1 px hairline at 7% white. Now `focusRingWidth` (2 dp) in `text3` at 45%. Goldens regenerated (six `kit_markdown_default_*`). | 0bdb22762 + goldens commit |
| P3-3 | FALSE | `onSwapProject` does not exist. The project chip in a chat is already tappable and opens a menu of project actions (Files, Terminal, Changes). Switching project would mean starting a new session in another project: a product decision, not a fix. | none |

Before and after (one screen each, dark, golden at phone size): `quote-rail-before-dark.png`, `quote-rail-after-dark.png`.

Revert checks: removing the fixes made the new tests fail for P1-4 (`nudge_moments_test`), P1-8 (`kit_message_test`) and P2-4 (`chat_shell_rows_test`).
