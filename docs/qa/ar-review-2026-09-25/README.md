# Arabic copy review — 2026-09-25

## Scope

Every Arabic value in `lib/l10n/app_ar.arb` that was added or changed between
`bd1692ac` and `2730891b` (integration head of `feat/phone-setup-v2`), compared with
its English source and `@key` description in `lib/l10n/app_en.arb`. Values only: no
keys added or removed, `app_en.arb` untouched. Generated `lib/l10n/*.dart` refreshed
with `flutter gen-l10n`.

- **Reviewed:** 185 values (36 changed, 149 added; 9 `teamUi*` keys were removed in
  the window and are not reviewed).
- **Changed by this review:** 35.

Checks per value: meaning against the English and the screen it shows on; plain
Modern Standard Arabic; the app's established vocabulary; placeholders intact; ICU
plural forms valid for Arabic where a count is shown; technical tokens (OpenCode,
Termux, Ubuntu, Git, Codex app-server, commands, field names) left in Latin script;
no Gas City engine words where the English avoids them.

## Established vocabulary kept

| English | Arabic used across the app |
|---|---|
| AI Team | فريق الذكاء الاصطناعي |
| computer / your computer | الحاسوب / حاسوبك |
| task · step · agent · worker | مهمة · خطوة · وكيل · عامل |
| terminal · shell (local terminal) | الطرفية · طرفية |
| Try again (button) | إعادة المحاولة |
| tap · touch and hold | اضغط · اضغط مطولًا |
| Usage | الاستخدام |
| blocked / held up | معطّل |
| Plugins | الإضافات |
| host (AI Team) | المضيف |
| Linux (phone setup) | لينكس |

## Changes

| Key | Old | New | Why |
|---|---|---|---|
| e7SetupPairingInstructions | شغّل «opencode2 pair» على الكمبيوتر، ثم … | شغّل «opencode2 pair» على حاسوبك، ثم … | English says "your computer"; setup and first-run copy use حاسوبك |
| teamUiStartRunFab | أعطِ الفريق مهمة | كلّف الفريق بمهمة | Literal "give"; كلّف … بمهمة is the natural MSA verb for assigning a task |
| teamUiStartRunTitle | أعطِ الفريق مهمة | كلّف الفريق بمهمة | Same as the button |
| teamUiStartRunPlanningHint | يحوّل المخطِّط المهمة إلى خطوات. تظهر المهمة في هذه القائمة بمجرد أن يفعل. | يقسّم المخطِّط المهمة إلى خطوات، ثم تظهر في هذه القائمة. | "بمجرد أن يفعل" is a literal "once it has"; shorter and plain |
| emptyTeachTeamRunsMessage | قل ما تحتاجه، وسيقسّمه الفريق … | اكتب ما تحتاج إليه، فيقسّمه الفريق … | قل is spoken-register; the person types the task |
| folderBrowserUp | مجلد واحد للأعلى | إلى المجلد الأعلى | Word-for-word "up one folder"; reads as a row that goes to the parent |
| folderBrowserEmptyBody | … أو اصعد مجلدًا واحدًا. | … أو انتقل إلى المجلد الأعلى. | Same wording as the Up row |
| folderBrowserProjectsHere | هنا مشاريعك. انقر على مشروع … | مشاريعك هنا. اضغط على مشروع … | The app says اضغط for tap, not انقر (click) |
| folderBrowserErrorTimedOut | لم يأتِ رد في الوقت المناسب. … | استغرق الرد وقتًا طويلًا. … | Matches the English "took too long", more natural |
| folderBrowserErrorLinked | إنه رابط. … | هذا رابط. … | إنه is a literal "It is" |
| folderBrowserRetry | حاول مرة أخرى | إعادة المحاولة | The app's Try again button is إعادة المحاولة everywhere (commonRetry, workRetry …) |
| localTerminalTryAgain | حاول مرة أخرى | إعادة المحاولة | Same |
| aiteamBringInDone | لدى {project} أحدث عمل للفريق ({commit}). | أصبح أحدث عمل للفريق ({commit}) في {project}. | "لدى المشروع" is a literal "has"; says what happened |
| aiteamBringInDirty | عمل الفريق ({commit}) ليس في {project} بعد: … فتُرك كما هو. | لم يُدخَل عمل الفريق ({commit}) إلى {project} بعد: … لذا تُرك كما هو. | Pairs with the "Bring in" action's verb (أدخل) |
| aiteamBringInDiverged | عمل الفريق ({commit}) ليس في {project}: … | لم يُدخَل عمل الفريق ({commit}) إلى {project}: … | Same |
| teamUiTaskSteps | {total, plural, =1{{done} من خطوة واحدة مكتملة} other{{done} من {total} خطوات مكتملة}} | =1 / two / few / many / other forms, e.g. اكتملت {done} من {total} خطوات (3–10), … خطوة (11+) | Only one/other: "من 12 خطوات" and "من 2 خطوات" were ungrammatical |
| teamUiHomeDoneMore | {count, plural, =1{عرض مهمة أخرى} other{عرض {count} أخرى}} | adds two / few / many forms: عرض مهمتين أخريين، عرض {count} مهام أخرى … | other had no noun, and Arabic needs the dual and 3–10 forms |
| teamUiHomeDoneToday | اكتملت اليوم | المكتملة اليوم | Section heading beside المهام and المكتملة; parallel noun phrase |
| teamUiAgentRolePlanner | المخطِّط | مخطِّط | The other role labels (عامل، مراجع، مشرف، مساعد، وكيل) have no article |
| teamUiRunStageDone | اكتملت | مكتملة | Stage label beside في الانتظار / قيد العمل / قيد المراجعة: a state, not a verb |
| teamUiRunDetailsUsage | الاستهلاك | الاستخدام | Usage is الاستخدام across the app (usageTitle, settingsHubGroupUsage) |
| teamUiRunDetailsCounts | … {blocked} متوقفة | … {blocked} معطّلة | "Blocked/held up" is معطّل in every other AI Team string; متوقفة reads as paused |
| phoneServerRowRestarting | تجري إعادة التشغيل | جارٍ إعادة التشغيل | The app's progress pattern is جارٍ … |
| managedRecoveryRowDetail | حتى 3 محاولات، فقط أثناء فتح هذا التطبيق. لا يثبّت ولا يحدّث أبدًا. | حتى 3 محاولات، وفقط أثناء فتح التطبيق. لا يثبّت شيئًا ولا يحدّثه. | Verbs had no object; smoother |
| pluginsSectionMore | إجراءات إضافية للإضافات | المزيد من إجراءات الإضافات | "إضافية للإضافات" is a clumsy echo |
| pluginsRowMore | إجراءات إضافية لهذه الإضافة | المزيد من إجراءات هذه الإضافة | Same |
| localTerminalShellName | الطرفية {number} | طرفية {number} | A name in a list: "طرفية 2", no article |
| localTerminalEndedBody | خرجت بالرمز {code}. | انتهت برمز الخروج {code}. | "خرجت بالرمز" is a literal "exited with code"; names the exit code |
| localTerminalFailedBody | … إن تكرر الفشل، تجد السبب في التفاصيل. | … إن تكرر الفشل، فستجد السبب في «التفاصيل». | Missing ف of the answer clause; «» marks the Details control |
| localTerminalCost | كل طرفية تشغّل {perShell} برامج. مع تشغيل الفريق الذكي، … إذا تجاوزت {limit}. | عدد البرامج لكل طرفية: {perShell}. مع تشغيل فريق الذكاء الاصطناعي، … إذا تجاوز عددها {limit}. | perShell is 2 in code, so "2 برامج" was wrong; the label form needs no agreement. AI Team term |
| localTerminalCostNow | كل طرفية تشغّل {perShell} برامج. مع تشغيل الفريق الذكي، … | عدد البرامج لكل طرفية: {perShell}. مع تشغيل فريق الذكاء الاصطناعي، … | Same |
| localTerminalSemantics | … انقر للكتابة، والمس مطولًا لتحديد النص. | … اضغط للكتابة، واضغط مطولًا لتحديد النص. | App-wide tap / long-press wording |
| addServerTypeOpenCode | OpenCode على كمبيوتر | OpenCode على حاسوب | حاسوب is the term in setup, first run and AI Team |
| addServerTypeCodexDetail | خادم تطبيق Codex على الكمبيوتر | Codex app-server على حاسوبك | "app-server" is a product term, kept Latin as in firstRunAgentCodexDetail; "your computer" |
| addServerTypePaseoDetail | عبر Paseo على الكمبيوتر | عبر Paseo على حاسوبك | "your computer" |

Reviewed and kept as is (150 values), among them: the pairing-code errors (the
switch from backticks to «» around commands and JSON field names is fine), the new
AI Team task wording (مهمة، خطوة، بانتظارك، قيد المراجعة), the plural rules of
`teamUiRunBlockedByDeps`, `teamUiWorkWaitsOn` and `teamUiHomeAgentsRowCount`
(already complete), the folder browser, the server rows and the local terminal
menus and keys.

## English source strings that look unclear (reported, not edited)

- `teamUiRunTermBatch` / `teamUiRunTermFormula` — "Task · convoy" / "Task · formula"
  show Gas City's own words on the task screen. Allowlisted in
  `test/ui_glossary_test.dart`, so Arabic keeps them; worth asking whether a person
  needs them at all.
- `localTerminalCost` / `localTerminalCostNow` — "Each shell runs {perShell}
  programs" does not say why the count matters until the second sentence, and
  "programs" means processes.
- `localTerminalFailedBody` — "Details says why": nothing on that state is labelled
  Details unless a Details control sits next to it.
- `teamUiStartRunPlanningHint` — "once it has" dangles (has what?).
- `folderBrowserNoProjectsBody` — "Name one below to make it here." is terse; "Type
  a name below to make a project here" would be clearer.
- `teamUiAgentRoleReviewer` — "Reviewer (merges)" puts behaviour in a role label.
- `e7SetupPairingPhoneHint` — "until you bridge it" is jargon ahead of the commands.

Outside this window, and not changed: the `aiteamComponent*` strings use
الفريق الذكي for AI Team, while every `teamUi*` string and the Plugins row use
فريق الذكاء الاصطناعي. One of the two should win in a later pass.

## Runs

1. `flutter gen-l10n` — regenerated `lib/l10n/app_localizations_ar.dart`; the new
   plural forms compile to `Intl.pluralLogic` with one/two/few/many/other. PASS.
2. `flutter test -j 2` on `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart`,
   `test/app_locale_test.dart`, `test/language_picker_test.dart`,
   `test/folder_browser_test.dart`, `test/local_terminal_screen_test.dart`,
   `test/terminal_accessibility_test.dart`, `test/team_run_screen_test.dart`,
   `test/team_home_test.dart`, `test/phone_server_card_test.dart`,
   `test/plugins_screen_test.dart`, `test/text_scale_overflow_test.dart`,
   `test/goldens/folder_browser_golden_test.dart`. First run: 173 passed, 2 failed —
   `folder_browser_compact_ar` light and dark (0.74 % pixels), which render
   `folderBrowserUp` and `folderBrowserProjectsHere`, changed here.
3. `--update-goldens --plain-name folder_browser_compact_ar` regenerated both PNGs.
   Looked at each: 320 × 640 dp at text scale 2, the three-line hint wraps inside
   the sheet, the path stays left to right, no overflow stripe. Rerun of the golden
   file with `test/l10n_coverage_test.dart`: all 16 passed. PASS.

## How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
git diff bd1692ac 2730891b -- lib/l10n/app_ar.arb   # the reviewed set
$F pub get && $F gen-l10n
$F test -j 2 test/l10n_coverage_test.dart test/ui_glossary_test.dart …   # list above
```

## NOT proven

- No device run: the wording was not read on a phone with TalkBack.
- Only the folder browser has an Arabic golden; the AI Team, terminal and Add
  server strings changed here are not rendered in Arabic by any golden.
