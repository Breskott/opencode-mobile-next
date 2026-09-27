// Gallery (gate G4) for KitRequestSheet
// (docs/ux-system/kit-api/KitRequestSheet.md): every declared state with a
// picture — permission, permission-always, permission-change, question,
// question-many, form, form-discard, gate, gate-confirm and reply — at
// 412x915, plus permission (the 560 panel) and permission-change (the
// end-side sheet) at 1280x800, in light and dark. closed-elsewhere is a
// behaviour with no picture (test/kit/kit_request_sheet_test.dart).
//
// Owner decision 2026-09-27 drops Arabic and RTL review and narrows the
// sizes to the phone (412x915) and one wide size (1280x800), with no Arabic
// or 2.0-text variant (the frozen spec's larger grid does not apply; see
// docs/qa/revamp-kit-KitRequestSheet-2026-09-27).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_request_sheet_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_choice_list.dart';
import 'package:opencode_mobile/ui/kit/kit_diff_view.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';
import 'package:opencode_mobile/ui/kit/kit_needs_you.dart';
import 'package:opencode_mobile/ui/kit/kit_request_card.dart';
import 'package:opencode_mobile/ui/kit/kit_request_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart';
import 'package:opencode_mobile/ui/kit/kit_technical_value.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/widgets/request_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_gallery.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

const _command = 'flutter test --concurrency=1 test/offline_queue_test.dart';
const _switchKey = ValueKey('gallery-always');

DateTime _asked() => clock.now().subtract(const Duration(minutes: 4));

KitDraft _draft(String target) => KitDraft(
  target: target,
  profileId: 'gallery',
  controller: TextEditingController(),
);

RequestRoutes _routes() => RequestRoutes(isPending: () => true);

KitRequestCard _permissionCard() => KitRequestCard.ask(
  kind: KitRequestKind.permission,
  title: 'Run a shell command',
  who: 'fox',
  server: 'laptop',
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The agent waits; nothing is lost.',
  announcement: 'Permission needed: Run a shell command',
  summary: _command,
  since: _asked(),
  onDetails: () {},
  answers: KitRequestDecide(onAllow: () {}, onReject: () {}),
);

KitRequestCard _editCard() => KitRequestCard.ask(
  kind: KitRequestKind.permission,
  title: 'Edit a file',
  who: 'fox',
  server: 'laptop',
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The agent waits; nothing is lost.',
  announcement: 'Permission needed: Edit a file',
  summary: 'lib/state/storage.dart',
  since: _asked(),
  onDetails: () {},
  answers: KitRequestDecide(onAllow: () {}, onReject: () {}),
);

KitRequestCard _gateCard() => KitRequestCard.ask(
  kind: KitRequestKind.gate,
  title: 'Merge the storage migration',
  who: 'Reviewer',
  server: 'laptop',
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The team waits; nothing is lost.',
  announcement: 'Gate: Merge the storage migration',
  since: _asked(),
  onDetails: () {},
  answers: KitRequestDecide(onAllow: () {}, onReject: () {}),
);

KitRequestCard _formCard() => KitRequestCard.ask(
  kind: KitRequestKind.form,
  title: 'Fill in the release notes',
  who: 'Reviewer',
  reason: KitNeedsYouReason.decision,
  ifIgnored: 'The release waits; nothing is lost.',
  announcement: 'Form: Fill in the release notes',
  since: _asked(),
  onDetails: () {},
  answers: const KitRequestInSheet(),
);

const _options = [
  KitChoice(value: 'keep', title: 'Keep the old name'),
  KitChoice(value: 'rename', title: 'Rename it everywhere'),
  KitChoice(
    value: 'ask',
    title: 'Ask me per file',
    supporting: 'Three files read the old name',
  ),
];

KitDiffView _change() => KitDiffView(
  files: [
    KitDiffFile.fromTexts(
      'lib/state/storage.dart',
      before:
          'const storeKey = "oc.store";\n'
          'const version = 1;\n'
          '\n'
          'String keyFor(String id) => "\$storeKey.\$id";\n',
      after:
          'const storeKey = "oc.store.v2";\n'
          'const version = 2;\n'
          '\n'
          'String keyFor(String id) => "\$storeKey.\$id";\n',
    ),
  ],
);

/// [full]: with the reject note and Details; the unfolded risk step is
/// shown without them, so the whole step fits without scrolling.
Future<void> _permission(BuildContext context, {bool full = true}) =>
    showKitRequestSheet(
      context,
      card: _permissionCard(),
      routes: _routes(),
      fullText: _command,
      alwaysAllow: KitRequestAlwaysAllow(
        title: 'Always allow flutter test',
        scope:
            'In this conversation, on laptop. Every flutter test command runs '
            'without asking.',
        onLabel: 'flutter test is always allowed',
        switchKey: _switchKey,
        onAllowAlways: (_) {},
      ),
      message: full
          ? KitRequestMessage(
              fieldLabel: 'Tell the agent why (optional)',
              draft: _draft('request.g1.note'),
            )
          : null,
      details: full
          ? const [KitTechnicalValue('Request id', 'per_01HZX9K2')]
          : const [],
    );

Future<void> _permissionChange(BuildContext context) => showKitRequestSheet(
  context,
  card: _editCard(),
  routes: _routes(),
  fullText: 'lib/state/storage.dart',
  change: _change(),
  message: KitRequestMessage(
    fieldLabel: 'Tell the agent why (optional)',
    draft: _draft('request.g2.note'),
  ),
);

Future<void> _question(BuildContext context) => showKitRequestSheet(
  context,
  card: KitRequestCard.ask(
    kind: KitRequestKind.question,
    title: 'Rename the storage key?',
    who: 'fox',
    reason: KitNeedsYouReason.decision,
    ifIgnored: 'The agent waits; nothing is lost.',
    announcement: 'Question: Rename the storage key?',
    since: _asked(),
    onDetails: () {},
    answers: KitRequestChoose<String>(
      choices: _options,
      onChosen: (_) {},
      other: KitChoiceOther(
        label: 'Something else',
        fieldLabel: 'Your answer',
        onSubmitted: (_) {},
        draft: _draft('request.g3.other'),
      ),
    ),
  ),
  routes: _routes(),
  fullText:
      'The store key "oc.store" is read in three files. Should I rename it '
      'to "oc.store.v2" everywhere?',
);

Future<void> _questionMany(BuildContext context) => showKitRequestSheet(
  context,
  card: KitRequestCard.ask(
    kind: KitRequestKind.question,
    title: 'Which checks should run?',
    who: 'fox',
    reason: KitNeedsYouReason.decision,
    ifIgnored: 'The agent waits; nothing is lost.',
    announcement: 'Question: Which checks should run?',
    since: _asked(),
    onDetails: () {},
    answers: KitRequestChooseMany<String>(
      choices: const [
        KitChoice(value: 'analyze', title: 'Analyzer'),
        KitChoice(value: 'unit', title: 'Unit tests'),
        KitChoice(
          value: 'goldens',
          title: 'Goldens',
          supporting: 'Takes about 6 minutes',
        ),
      ],
      onSend: (_) {},
    ),
  ),
  routes: _routes(),
  fullText: 'Pick every check to run before the merge.',
);

Future<void> _form(BuildContext context, {ValueNotifier<bool>? dirty}) =>
    showKitRequestSheet(
      context,
      card: _formCard(),
      routes: _routes(),
      dirty: dirty,
      body: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KitField(label: 'Version', hint: '1.0.45'),
          SizedBox(height: KitTokens.of(context).space4),
          const KitField(
            label: 'Highlights',
            kind: KitFieldKind.multiline,
            helper: 'One line per change.',
          ),
        ],
      ),
      // Enabled: the disabled primary's text3 on surface3 is 4.44:1 in
      // dark, a known theme near-miss G5 fails (QA record); the disabled
      // submit and its reason are covered by the behaviour test.
      submit: KitAction(label: 'Send answers', onPressed: () {}),
    );

Future<void> _gate(BuildContext context) => showKitRequestSheet(
  context,
  card: _gateCard(),
  routes: _routes(),
  fullText:
      'Move the store key to v2, migrate existing entries on first launch, '
      'and keep the old key readable for one release.',
  message: KitRequestMessage(
    fieldLabel: 'Notes for the team (optional)',
    draft: _draft('request.g4.note'),
  ),
  details: const [KitTechnicalValue('Branch', 'team/storage-v2')],
);

Future<void> _reply(BuildContext context) => showKitRequestSheet(
  context,
  card: KitRequestCard.ask(
    kind: KitRequestKind.reply,
    title: 'What should the changelog say?',
    who: 'Release task',
    reason: KitNeedsYouReason.decision,
    ifIgnored: 'The task waits; nothing is lost.',
    announcement: 'Reply needed: What should the changelog say?',
    since: _asked(),
    answers: KitRequestReply(
      fieldLabel: 'Your reply',
      draft: _draft('request.g5.reply'),
      onSend: (_) {},
    ),
  ),
  routes: _routes(),
  fullText:
      'The release is built and signed. What should the changelog say '
      'about the storage change?',
);

typedef _Shot = ({
  Future<void> Function(BuildContext) open,
  Future<void> Function(WidgetTester)? then,
});

Map<String, _Shot> _states() => {
  'permission': (open: _permission, then: null),
  'permission_always': (
    open: (context) => _permission(context, full: false),
    then: (tester) async {
      await tester.tap(find.byKey(_switchKey));
    },
  ),
  'permission_change': (open: _permissionChange, then: null),
  'question': (open: _question, then: null),
  // One chosen, so Send is live: the disabled primary is the theme's known
  // 4.44:1 near-miss in dark (QA record); the disabled Send and its reason
  // are covered by the behaviour test.
  'question_many': (
    open: _questionMany,
    then: (tester) async {
      await tester.tap(find.text('Unit tests'));
    },
  ),
  'form': (open: (context) => _form(context), then: null),
  'form_discard': (
    open: (context) => _form(context, dirty: ValueNotifier(true)),
    then: (tester) async {
      await tester.binding.handlePopRoute();
    },
  ),
  'gate': (open: _gate, then: null),
  'gate_confirm': (
    open: _gate,
    then: (tester) async {
      showKitConfirm(
        tester.element(find.byType(KitSheet)),
        title: 'Merge into main?',
        body:
            'The team merges the storage migration now. You can revert it '
            'from the task.',
        confirmLabel: 'Merge',
      );
    },
  ),
  // Typed, so Send is live (as 'question_many').
  'reply': (
    open: _reply,
    then: (tester) async {
      await tester.enterText(
        find.byType(EditableText),
        'Storage moves to v2; old data migrates on first launch.',
      );
    },
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: state, value: shot) in _states().entries) {
      testWidgets('$state · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_request_sheet_$state',
            _phone,
            light: light,
          ),
          size: _phone,
          light: light,
          open: shot.open,
          then: shot.then,
        );
      });
    }
    for (final (state, open) in [
      ('permission', _permission),
      ('permission_change', _permissionChange),
    ]) {
      testWidgets('$state · 1280x800 · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_request_sheet_$state', _wide, light: light),
          size: _wide,
          light: light,
          open: open,
        );
      });
    }
  }
}
