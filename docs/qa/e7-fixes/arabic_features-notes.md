# E7 Arabic feature corpus

Finish line: provide a complete, reviewable Arabic translation of all 727 assigned baseline feature messages, preserving their protocol text, placeholders, consent boundaries and recovery meaning.

Non-goals: enabling a locale, changing English copy or application behavior, translating server content, editing generated localization, or claiming rendered RTL verification. The coordinator integrates this corpus with the core catalog and the newly localized UI slices.

## Coverage and terminology

- Input: [arabic_features-source.json](arabic_features-source.json), including original placeholder types and descriptions.
- Output: [arabic_features.json](arabic_features.json), exactly 727 message keys, no metadata or additional keys.
- Coverage includes quota collectors/monitoring, managed Termux runtime and recovery, plugins and command links, web search, Codex connection/account, isolated Git worktrees, context collection, Tailscale, external A2A agents, file readers, project/session discovery, onboarding, background work and OC1/OC2 switching.
- Modern Standard Arabic uses direct action labels and retains explicit distinctions between confirmed, unknown, failed and stale states. Security and consent copy is translated in full rather than shortened by removing scope or recovery information.
- Shared corpus terminology: جلسة (session), خادم (server), وكيل (agent), وكيل فرعي (subagent), مساحة العمل (workspace), بيانات الاعتماد (credentials), طلب (prompt), مسودة (draft), مزوّد الخدمة (provider), نموذج (model), الطرفية (terminal), شيفرة (code), رقعة (patch), شجرة العمل (worktree), الخلفية (background).
- Additional feature terms: جامع البيانات (collector), حصة (quota), رصيد الاستخدام (allowance), بيئة التشغيل (runtime), حزمة السياق (context capsule). Search-provider compounds use مزوّد البحث.
- Technical names, code/command identifiers, URL examples, paths, file types, version strings and keyboard `Enter` stay literal. The 15 messages containing only technical text or placeholder combinations are explicitly listed in validation evidence; they are not English fallback prose.

## Counts and ICU

Seven original ICU plural messages use Arabic `zero`, `one`, `two`, `few`, `many`, and `other` forms. Original exact `=1` selectors remain intact. Argument names, expression types and metadata types are unchanged. Count-only English messages without plural expressions use natural Arabic count labels where needed (for example “الجلسات: {count}”) to avoid inventing incorrect singular/plural grammar or changing the callable localization contract.

No directional control characters or pseudo-localization are inserted. Layout direction and technical-value isolation remain UI responsibilities.

## Verification

Run:

```sh
python3 docs/qa/e7-fixes/validate_arabic_features.py
git diff --check
```

The [validation script](validate_arabic_features.py) checks duplicate keys, exact source parity, nonempty Arabic prose, intentional technical-only exceptions, balanced/parsed ICU expressions, argument/type identities, six Arabic plural categories, exact-selector preservation, original placeholder metadata, technical literals, URL preservation, and absence of hidden directional controls. [Validation result](arabic_features-validation.json) records source/output SHA-256 hashes.

Result: 727/727 messages, zero missing/extra keys or placeholder mismatches, seven plural expressions with all Arabic categories, zero directional controls. No Flutter, native, network, provider-authentication or account calls were needed. No credentials were read or included.

The structural validator is not a substitute for Flutter's ICU generator or native-language visual review. Final integration must generate the combined catalog and verify the actual Arabic UI, text scaling and accessibility. This commit provides the corpus, not an enabled-locale completion claim.

## Independent language spot review

The core Arabic corpus owner reviewed feature quota consent, runtime switching/shared data/missing credentials, external-agent boundaries/uncertain delivery, and provider-count plurals read-only. No blocking mistranslation was found. Incorporated two polish suggestions: explicitly name the origin address and make the zero-provider branch natural Arabic. This is an agent peer review, not a claim of human translation sign-off.
