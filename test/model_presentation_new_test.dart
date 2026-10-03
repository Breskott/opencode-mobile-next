import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/widgets/pickers.dart';

CatalogModel _model(String id, DateTime? released) => CatalogModel(
  id: id,
  providerID: 'anthropic',
  name: id,
  enabled: true,
  status: 'active',
  contextLimit: 1000000,
  outputLimit: 128000,
  reasoning: true,
  attachments: true,
  tools: true,
  variants: const [],
  released: released,
);

void main() {
  test('a model out in the last 30 days is new', () {
    final now = DateTime(2026, 9, 23);
    expect(
      isNewModel(_model('claude-opus-5-5', DateTime(2026, 9, 22)), now: now),
      isTrue,
    );
    expect(
      isNewModel(_model('claude-opus-5', DateTime(2026, 7, 24)), now: now),
      isFalse,
    );
    expect(isNewModel(_model('unknown', null), now: now), isFalse);
    // A catalog date in the future is not "new", it is wrong.
    expect(isNewModel(_model('x', DateTime(2026, 12, 1)), now: now), isFalse);
  });

  test('effort levels read as words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(presentedEffort('xhigh', en), 'Extra high');
    expect(presentedEffort('none', en), 'No thinking');
    expect(presentedEffort('MAX', en), 'Max');
    expect(presentedEffort('fast', en), 'fast');
  });
}
