# Sweep of build 2310 on emulator-5554 (2026-10-14)

Checked, not changed. Real OpenCode 1.19.0 server on :4180 (scratch XDG dirs, scratch git project `proj`), mock model from `../notifications-2026-10-14/mock_llm.py` (copy with an added "edit" keyword). No crashes in `logcat -b crash`. Servers stopped by exact PID. System font scale restored to 1.0, night mode left at "no".

| Screen | Image | Result |
|---|---|---|
| Server not reachable (old profile) | (first screen, not saved) | OK |
| Add server, address step | s0_addr, s0_conn | PROBLEM: stale "Computer at 10.0.2.2 isn't answering" banner stays on top of the whole add flow; page is tall and scrolls under the Save button |
| Chats list | s1_chats | OK 2-line rows, chips on one line; "Running" chip is cut at the right edge with no fade |
| New conversation | s2_new | OK |
| Chat with tasks | s2_plan, s2_done | PROBLEM: header is 3 levels (title, server, project chip), plus banner above; tasks chip still spins "5/6" after the reply ended (mock never completes the last task) |
| Tasks sheet | s2_tasks_sheet | OK |
| Shell step, expanded | s2_shell_expanded | OK (raw npm output is the command's own output) |
| @ser suggestions | s3_mention | PROBLEM: 4th row has no file name (only "test", a folder); README.md listed for "ser" |
| + menu, File from the project | s3_plus, s3_filepicker, s3_filesearch | PROBLEM: list shows only README.md (no folders, cannot browse lib/ or test/); typing "server" finds the files |
| Prompt with attachment | s4_edit | PROBLEM (likely): the message appears twice in the transcript after one Send |
| Inline edit diff | s4_edit_expanded | PROBLEM: red "-1" count and red removed-line tint |
| Full diff page | s4_diffpage | PROBLEM: same red; three radio rows take about 40% of the screen above the diff |
| Settings | s5_settings | OK; "3 servers" counts two dead profiles |
| Providers, server list | s5_providers | PROBLEM: three identical names "Computer at 10.0.2.2" (no port) |
| Providers, list | s5_prov_list | PROBLEM: OpenAI subtitle cut with "(he..." |
| Connect OpenAI | s5_openai | OK (headless and browser share one icon) |
| Headless code sheet, Copy | s5_headless, s5_copy | OK |
| Cancel | s5_cancelled, s5_reopen, s5_cancelled2 | PROBLEM: "Cancel" only closes the sheet, sign-in stays "Waiting"/"Needs you"; later "Cancel OpenAI sign-in" gives "This sign-in has expired" (wrong words after cancelling) |
| Usage | s6_usage | PROBLEM: "Add a subscription" shown twice (button and row) |
| Alerts | s6_alerts | OK (nearly empty with no plans) |
| This phone | s6_thisphone | OK (offers install, 208 MB, memory warning) |
| Shade, running | s7_shade_running | OK silent row, Open and Stop |
| Shade, finished | s7_shade_done | OK "plan finished" alert plus "Ready" row |
| Dark chat | s8_dark | OK (app was already dark; light theme not checked) |
| Text size 2.0, chat | s8_font2 | PROBLEM: header title above back arrow, crowded |
| Text size 2.0, chats list | s8_font2_list | PROBLEM: "Conversation/s" breaks mid-word, server chip wraps to 3 lines over the status bar, chips cut |

Not checked: light theme, Needs-you permission alert in the shade (the mock's bash ran without asking), several chats in the shade, Arabic.
