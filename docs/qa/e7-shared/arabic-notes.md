# Shared Arabic copy — initial 80 messages

Finish line: translate the coordinator's frozen initial shared fragment with exact key/placeholder parity and matching Arabic corpus terminology. Non-goals: editing the coordinator's checkout or app behavior, enabling the locale, or claiming rendered RTL verification.

[Source snapshot](messages_en-snapshot.json) preserves all original messages and metadata; [Arabic output](messages_ar.json) contains exactly 80 message keys. It covers connection failures/recovery, permission-request titles, glossary explanations and reconnect banners. No source changes were made. Later coordinator additions are outside this frozen snapshot.

Terminology follows the main corpus. A listener is described as «خدمة استقبال الاتصالات»; variant as «نمط النموذج» with the original speed/depth explanation. Commands (`opencode2 pair`, `opencode serve`, `adb reverse`), environment variables, protocols, product names and interpolated technical values remain literal. The attempts count uses a label («عدد المحاولات») to remain grammatical without changing its simple-placeholder signature. No directional control characters were introduced.

Verification: `python3 docs/qa/e7-shared/validate_arabic.py` and `git diff --check` passed. The validator reuses the corpus ICU parser, validates original metadata and argument/type parity, literal commands/URLs, exact key coverage, Arabic prose and directional-control absence. [Hash-bound result](arabic-validation.json) records both inputs. No Flutter, native, account, network or credential calls were made. The coordinator owns generation and actual UI/RTL verification.
