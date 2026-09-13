# E7 + daily UI fixes

Finish line: system/English/Arabic selection survives restart, all app-authored UI is localized with readable Arabic/technical mixed-direction content, and each listed fix has a usable integrated flow and traceable verification.

Non-goals: new handoff, Quick Settings, ambient voice or quota backends; remote CI, public release and unrelated runtime pin changes.

| Slice | Finish line | Owner branch | Gate |
|---|---|---|---|
| E7 locale | persisted picker, system fallback, Arabic/RTL and native language plumbing | feature/e7-locale | restart/save failure and Arabic shell/layout |
| Chat/results | clear canonical child result cards, simpler menu, localized accessible chat | fix/e7-chat-results | child linkage/malformed results/menu/draft/RTL |
| Readers | remembered source-first ordering and consistent code wrap | feature/e7-reader-preferences | persistence/deletion, file/review/diff/RTL |
| Workspace/Activity | one understandable inventory state and localized daily navigation | fix/e7-workspace-clarity | partial/unknown/full inventories and retained context |
| Appearance | real component theme preview, locale discovery and localized settings | feature/e7-appearance-preview | apply/cancel/failure, light/dark/Arabic/2.5x |
| Setup | localized connection/Termux/terminal flows with simple technical guidance | fix/e7-setup-language | visible routes/credentials/RTL technical text |
| Library | localized provider/command/MCP/permissions journey | fix/e7-library-language | safe auth, scope, cancellation and Arabic controls |
| Arabic corpus | 1457 baseline keys fully translated with ICU parity | l10n/e7-arabic-core, l10n/e7-arabic-features | independent copy review + placeholder/plural validation |
| Shared/mobile evidence | remaining voice/common UI localization, async runtime, motion/accessibility | coordinator | owned server/AVD + physical phone when connected |

Every slice owns a dedicated worktree and local [skip ci] commits; heavy checks are serialized. Final complete source gets one analyzer/full recursive serial test manifest, local APK build, installed hash check and Android walkthrough. Physical hardware/provider-backed limitations remain explicit until actually verified. Credentials never enter audit files.
