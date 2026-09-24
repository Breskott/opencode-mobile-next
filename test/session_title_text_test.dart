import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/session_title_text.dart';
import 'package:opencode_mobile/ui/widgets/session_title.dart';

// The refinery session's title as the server stored it (Android 15
// emulator, 2026-09-24).
const _leaked =
    "I'll run the startup sequence to check for existing work and prime the "
    'merge queue.<tool_call><fu…';
const _clean =
    "I'll run the startup sequence to check for existing work and prime the "
    'merge queue.';

void main() {
  group('displaySessionTitleText', () {
    test('cuts the leaked tool call off the refinery title', () {
      expect(displaySessionTitleText(_leaked), _clean);
    });

    test('cuts at every kind of model markup', () {
      expect(
        displaySessionTitleText('Fix login <function=bash>{"cmd"'),
        'Fix login',
      );
      expect(displaySessionTitleText('Fix login<function_calls>'), 'Fix login');
      expect(
        displaySessionTitleText('Plan the release <|im_start|>assistant'),
        'Plan the release',
      );
      expect(displaySessionTitleText('Check tests</tool_call>'), 'Check tests');
      expect(
        displaySessionTitleText('Check tests <TOOL_CALL>{'),
        'Check tests',
      );
      expect(displaySessionTitleText('Review <tool_use>x'), 'Review');
    });

    test('drops a marker the server cut in half, with its ellipsis', () {
      expect(
        displaySessionTitleText('prime the merge queue.<tool_ca…'),
        'prime the merge queue.',
      );
      expect(
        displaySessionTitleText('prime the merge queue. <fu...'),
        'prime the merge queue.',
      );
      expect(
        displaySessionTitleText('prime the merge queue.<…'),
        'prime the merge queue.',
      );
    });

    test('ellipsis after cut markup goes too', () {
      expect(
        displaySessionTitleText('Refactor the parser …<tool_call>'),
        'Refactor the parser',
      );
    });

    test('ordinary titles are left as they are', () {
      for (final title in [
        'Refinery merge queue patrol',
        'Polecat startup: claim work and execute',
        'Compare a < b and c > d',
        'Explain the <details> element',
        'Use <f',
        'Summarise the long discussion…',
        'Why does 1 < 2…',
      ]) {
        expect(displaySessionTitleText(title), title, reason: title);
      }
      expect(displaySessionTitleText('  Padded  '), 'Padded');
    });

    test('nothing readable left is empty', () {
      expect(displaySessionTitleText('<tool_call><function=read>'), '');
      expect(displaySessionTitleText('   '), '');
      expect(displaySessionTitleText(null), '');
    });
  });

  group('presentedSessionTitle', () {
    test('every session list shows the cleaned title', () {
      expect(presentedSessionTitle(Session(id: 'r', title: _leaked)), _clean);
    });

    test('markup-only titles fall back to the untitled wording', () {
      expect(
        presentedSessionTitle(
          Session(id: 'r', title: '<tool_call><fu…'),
          fallback: 'Untitled conversation',
        ),
        'Untitled conversation',
      );
    });

    test('the stored title is not changed', () {
      final session = Session(id: 'r', title: _leaked);
      presentedSessionTitle(session);
      expect(session.title, _leaked);
    });
  });
}
