# E7 Arabic baseline core corpus

Finish line: supply natural Arabic for all 730 assigned baseline messages with
unchanged message identity and interpolation contracts, ready for root locale
integration. Non-goals: enabling a partial locale, changing product behavior,
editing generated localization code, or claiming rendered RTL verification.

Base: `a4b2433` on branch `l10n/e7-arabic-core`, dedicated worktree
`oc_app-e7-arabic-core`. Owned files are this note and the `arabic_core*` /
`validate_arabic_core.py` files under `docs/qa/e7-fixes/`.

- [Baseline English source and metadata](../e7-fixes/arabic_core-source.json)
- [Arabic message fragment](../e7-fixes/arabic_core.json)
- [Structural validation evidence](../e7-fixes/arabic_core-validation.json)
- [Repeatable validation script](../e7-fixes/validate_arabic_core.py)

The fragment covers development services, model/task controls, draft reuse,
background controls, staged revert, session notes, usage and cost, MCP, export and
import, saved prompts, run results, handoff, connection help, voice and account
management, context inspection, draft/photo recovery, and the start of quota
setup. All 730 keys have a translation. Eight entries intentionally match the
English source because they consist entirely of a product name, abbreviation,
or interpolated label template. The validation report names those entries.
There is no untranslated English prose and no pseudo-localization.

## Terminology and language review

Use concise Modern Standard Arabic and keep technical proper names, commands,
URLs, IP addresses, identifiers, unit symbols and keyboard combinations literal.
The paired feature-corpus owner aligned these terms before final review:

| Meaning | Arabic |
| --- | --- |
| Session / chat | جلسة / محادثة |
| Server / provider | خادم / مزوّد الخدمة |
| Agent / subagent | وكيل / وكيل فرعي |
| Model / prompt / draft | نموذج / طلب / مسودة |
| Workspace / project | مساحة العمل / مشروع |
| Credentials | بيانات الاعتماد |
| Background / queue | الخلفية / قائمة الانتظار |
| Code / patch / working tree | شيفرة / رقعة / شجرة العمل |
| Terminal / shell | الطرفية / الصدفة |
| Compaction | اختصار السياق |
| Stash | الطلبات المحفوظة |
| Staged revert | التراجع المبدئي |
| Remaining usage | رصيد الاستخدام المتبقي |

Staged-revert copy preserves immediate file effects during staging, hidden
conversation history, permanent-commit irreversibility, possible replacement of
subsequent file changes on clearing, and queued-work resumption. “Initial” here
means the reviewable stage, not a promise that files are unchanged. Usage and
digest copy preserves unknown results, loaded-history limits and server-reported
estimates; idle never becomes a successful-completion claim in translation.

All 12 ICU plurals retain the original exact selectors and provide Arabic zero
(or `=0`), one (or `=1`), two, few, many and other forms. Count-bearing placeholders
whose source type is already formatted `String` use a label plus value rather
than inventing numeric plural semantics. No direction-control characters are
embedded: layout and LTR isolation for paths/code remain UI responsibilities.

The feature-corpus owner performed a read-only language spot review of staged
revert, private HTTPS/tunnel instructions, digests and plural branches. No
blocking mistranslation was found. Their one glossary correction—using
`المهام في قائمة الانتظار` in revert-clear copy—was applied. Core also reviewed
the other corpus's quota consent, runtime-switch boundaries, A2A uncertainty and
model-provider plural copy, reporting minor wording suggestions to its owner.
This is a peer language review, not a claim of external translator certification.

## Verification

Run from the worktree root:

```sh
python3 docs/qa/e7-fixes/validate_arabic_core.py
git diff --check
```

The Python check passes: 730/730 keys, no extras, no duplicate JSON keys,
placeholder parity for every message, 51 source placeholder-metadata contracts,
12 structurally parsed ICU plurals with original selectors and Arabic forms,
no format controls, no ICU apostrophe hazards, and no untranslated prose.
Source and translation SHA-256 hashes are recorded in the evidence JSON. Target
metadata is omitted intentionally; root must preserve the original English
placeholder names/types when merging the Arabic messages.

No Flutter, build, network, account, provider-config, or credential calls were
needed. No secrets were read. Root still owns merged `gen-l10n`, activation,
localized widget/runtime checks, screenshots and final RTL/layout verification.
