import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/setup/setup_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  test('native persistence failure maps to typed failure and plain words', () {
    final record = SetupJobRecord.parse(
      jsonEncode({
        'jobId': 'job',
        'state': 'failed',
        'errorCode': 'setup_persistence',
        'error': '/private/storage: raw exception details',
        'components': <String, Object>{},
      }),
    )!;
    expect(record.failureKind, SetupFailureKind.persistence);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final progress = progressFromRecord(
      record,
      const [],
      l10n,
      now: DateTime.fromMillisecondsSinceEpoch(1),
    );
    expect(progress.state, SetupState.failed);
    expect(progress.error, l10n.phoneSetupErrorInstall('OpenCode'));
    expect(progress.error, isNot(contains('/private/')));
    expect(progress.error, isNot(contains('setup_persistence')));
  });
}
