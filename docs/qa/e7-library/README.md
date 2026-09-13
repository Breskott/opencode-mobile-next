# E7 library, sign-in and project tools

Finish line: all app-authored visible library, provider sign-in, MCP and project-tool messages are localized, with Arabic translations, directional layouts, readable technical values and the original capability/consent/cancellation behavior.

Non-goals: new providers, endpoints, account mutations, migration of server content, or translation of code, filenames, commands, provider names and model IDs.

## Implemented

- Localized library search/navigation, model/catalog states, provider and MCP status, OAuth prompts and recovery/error prose, skills/references/commands, saved grants, Git/worktrees, cloud workspaces, project health and MCP configuration forms.
- Includes indirect strings: snackbar results, loading states, confirmation warnings, errors and validators, semantic labels, context menus, reconnect messages and provider-disconnect environment warning.
- Added `messages_ar.json` for newly introduced keys only. Existing catalog translations are integrated separately. Grant/model/changed-file counts use ICU plural rules including Arabic zero/one/two/few/many/other forms.
- Arabic search aliases retain English aliases, so both languages can find library destinations.
- Insets follow start/end. At large text sizes, Tools moves Change below the model summary rather than squeezing the model name; MCP scope/type choices stack vertically; environment/worktree creation uses a wrapped bottom action instead of a clipped extended floating button. Saved-permission confirmation uses the shorter title “Revoke access?” while retaining the complete permission warning and explicit actions. Commands, URLs, code schemas, callback codes and technical resource inputs keep their own left-to-right ordering.
- Source content is preserved. No provider credentials, authorization URLs or real account data were used in evidence.

## Verification

Initial focused gate: 109 tests passed across 14 affected files. A subsequent visual review prompted two readability fixes; their exact affected tests and final scoped analyzer are pending. The new layout harness covers eight production screens and permission revocation confirmation at 320 logical pixels in light, dark, and RTL/2.5x text variants; captures use synthetic data. Arabic runtime validation belongs to the final integrated catalog, so branch RTL captures explicitly use English in RTL until integration.

Shared integration dependency: root localizes `Glossary` presentation and adds localized `permissionRequestTitle(..., l10n: ...)` to the two saved-permission title callsites. The onboarding owner supplies `connectMethodHint(method, l10n)`.
