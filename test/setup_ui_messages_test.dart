import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/state/pairing.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/setup_ui_messages.dart';

void main() {
  test('English error presentation preserves actionable validation detail', () {
    final l10n = AppLocalizationsEn();
    final error = validateServerProfileUrl('http://remote.example');
    expect(error, isNotNull);
    expect(setupUiMessage(l10n, error!), error);
    expect(
      setupUiMessage(l10n, 'OpenCode server exited (code 17)'),
      'OpenCode server exited (code 17)',
    );
    expect(
      setupUiMessage(l10n, 'custom server detail: /work/hello'),
      'custom server detail: /work/hello',
    );
  });

  test(
    'Arabic localizes parser and manager facts while preserving status values',
    () {
      final l10n = lookupAppLocalizations(const Locale('ar'));
      final parsed = parsePairingPayload('not a pairing payload');
      final localized = setupUiMessage(l10n, parsed.error!);
      expect(localized, contains('رمز اقتران'));
      expect(localized, isNot(contains('not a pairing payload')));
      expect(setupUiMessage(l10n, 'Installing OpenCode'), contains('تثبيت'));
      expect(
        setupUiMessage(l10n, 'OpenCode server exited (code 17)'),
        contains('17'),
      );
      expect(
        l10n.e7SetupDeleteDisclosure(2, 2),
        allOf(contains('طلبان'), contains('مسودتان')),
      );
    },
    skip: !AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == 'ar',
    ),
  );
}
