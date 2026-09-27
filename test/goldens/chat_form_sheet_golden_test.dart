// Golden renders of the form sheet rebuilt from kit parts (unit
// shared-chat-2; map pages form-sheet, form-sheet-date-picker and
// form-sheet-dismiss-confirm-sheet): the content-height sheet, the
// full-height sheet with every field kind, the send failure, the Dismiss
// question asked in place and the date picker, at 412x915 and 1280x800,
// dark and light, with the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/chat_form_sheet_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/widgets/form_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

Api2FormInfo _shortForm(String id) => Api2FormInfo(
  id: id,
  sessionID: 'ses_1',
  title: 'Release checklist',
  fields: [
    Api2FormField(
      key: 'env',
      type: Api2FormFieldType.string,
      title: 'Environment',
      required: true,
      defaultValue: 'staging',
      options: [
        Api2FormOption(
          value: 'production',
          label: 'Production',
          description: 'Live traffic',
        ),
        Api2FormOption(value: 'staging', label: 'Staging'),
      ],
    ),
    Api2FormField(
      key: 'deploy',
      type: Api2FormFieldType.string,
      format: 'date',
      title: 'Deploy day',
      defaultValue: '2026-03-10',
    ),
    Api2FormField(
      key: 'notify',
      type: Api2FormFieldType.boolean,
      title: 'Tell the team when it ships',
      defaultValue: true,
    ),
  ],
);

Api2FormInfo _longForm(String id) => Api2FormInfo(
  id: id,
  sessionID: 'ses_1',
  title: 'Connect to Sentry',
  fields: [
    Api2FormField(
      key: 'org',
      type: Api2FormFieldType.string,
      title: 'Organization slug',
      description: 'The slug shown in your Sentry organization settings.',
      required: true,
      maxLength: 40,
      defaultValue: 'acme-mobile',
    ),
    Api2FormField(
      key: 'retention',
      type: Api2FormFieldType.integer,
      title: 'Retention in days',
      defaultValue: 30,
      minimum: 1,
      maximum: 90,
    ),
    Api2FormField(
      key: 'envs',
      type: Api2FormFieldType.multiselect,
      title: 'Environments to watch',
      minItems: 1,
      maxItems: 3,
      defaultValue: ['prod', 'stage'],
      options: [
        Api2FormOption(value: 'prod', label: 'Production'),
        Api2FormOption(value: 'stage', label: 'Staging'),
        Api2FormOption(value: 'dev', label: 'Development'),
      ],
    ),
    Api2FormField(
      key: 'region',
      type: Api2FormFieldType.string,
      title: 'Data region',
      defaultValue: 'eu',
      options: [
        for (final region in ['us', 'eu', 'ap', 'sa', 'af'])
          Api2FormOption(value: region, label: region.toUpperCase()),
      ],
    ),
    Api2FormField(
      key: 'connect',
      type: Api2FormFieldType.external,
      title: 'Authorize Sentry',
      description: 'Grants read access to issues.',
      url: 'https://sentry.io/oauth/authorize',
    ),
    Api2FormField(
      key: 'note',
      type: Api2FormFieldType.string,
      title: 'Anything the agent should know',
      placeholder: 'Optional',
    ),
  ],
);

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required bool light,
  required Api2FormInfo form,
  Size size = const Size(412, 915),
  FormRendererSubmit? onSubmit,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final host = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            key: host,
            body: const SafeArea(child: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      presentForm(
        host.currentContext!,
        form: form,
        onSubmit: onSubmit ?? (_) async {},
        onCancel: () async {},
      ),
    );
    await tester.pumpAndSettle();
    if (then != null) await then(tester);
    expect(tester.takeException(), isNull);
    final sized = size == const Size(412, 915)
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('$name${sized}_${light ? 'light' : 'dark'}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(debugForgetFormAnswers);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('form sheet · content height · $mode', (tester) async {
      await _golden(
        tester,
        'chat_form_sheet',
        light: light,
        form: _shortForm('frm_short'),
      );
    });

    testWidgets('form sheet · full height · $mode', (tester) async {
      await _golden(
        tester,
        'chat_form_full',
        light: light,
        form: _longForm('frm_long'),
      );
    });

    testWidgets('form sheet · send failed · $mode', (tester) async {
      await _golden(
        tester,
        'chat_form_sendfailed',
        light: light,
        form: _shortForm('frm_fail'),
        onSubmit: (_) async =>
            throw Exception('The server did not accept these answers.'),
        then: (tester) async {
          await tester.tap(find.byKey(const Key('form-submit')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('form sheet · dismiss question · $mode', (tester) async {
      await _golden(
        tester,
        'chat_form_dismiss',
        light: light,
        form: _shortForm('frm_dismiss'),
        then: (tester) async {
          await tester.tap(find.byKey(const Key('form-cancel')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('form sheet · date picker · $mode', (tester) async {
      await _golden(
        tester,
        'chat_form_datepicker',
        light: light,
        form: _shortForm('frm_date'),
        then: (tester) async {
          await tester.tap(find.byKey(const Key('form-field-deploy-pick')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('form sheet · content height · 1280x800 · $mode', (
      tester,
    ) async {
      await _golden(
        tester,
        'chat_form_sheet',
        light: light,
        size: const Size(1280, 800),
        form: _shortForm('frm_short_wide'),
      );
    });

    testWidgets('form sheet · full height · 1280x800 · $mode', (tester) async {
      await _golden(
        tester,
        'chat_form_full',
        light: light,
        size: const Size(1280, 800),
        form: _longForm('frm_long_wide'),
      );
    });
  }
}
