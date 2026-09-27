// Voice typing as an optional item in phone setup's Customize sheet and in
// This phone › Add tools (feat/voice-in-setup, 2026-09-27): offered only
// when this phone can have it, off by default with what it does and its
// size, shown installed when it is, and removable from the same place.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_customize_sheet.dart';

import 'support/fake_setup_engine.dart';
import 'support/voice_setup_fakes.dart';

class _Opened {
  Set<String>? result;
  var closed = false;
}

Future<_Opened> _open(
  WidgetTester tester,
  FakeSetupApp app, {
  bool addMode = false,
  Set<String> optionalInstalled = const {},
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final engine = FakeSetupEngine(
    registry: [...FakeSetupEngine.fakeRegistry, voiceSetupItem(app)],
  )..optionalInstalled = optionalInstalled;
  final opened = _Opened();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: KitButton.primary(
              label: 'open',
              expand: false,
              onPressed: () async {
                opened.result = await showSetupCustomizeSheet(
                  context,
                  engine: engine,
                  addMode: addMode,
                );
                opened.closed = true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return opened;
}

const _voice = ValueKey('phone-setup-customize-voice');

KitSwitchRow _row(WidgetTester tester) =>
    tester.widget<KitSwitchRow>(find.byKey(_voice));

Future<void> _done(WidgetTester tester) async {
  final done = find.byKey(const ValueKey('phone-setup-customize-done'));
  await tester.ensureVisible(done);
  await tester.tap(done);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // The sheet's pre-flight asks the device; this phone has room.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('oc/voice'), (
          call,
        ) async {
          if (call.method == 'getDeviceInfo') {
            return <String, Object?>{
              'availableStorageBytes': 20000000000,
              'memoryClassMb': 256,
              'totalMemoryMb': 8000,
              'supportedAbis': ['arm64-v8a'],
              'hasMicrophone': true,
            };
          }
          return null;
        });
  });

  testWidgets('first setup offers it off by default, saying what it does '
      'and its size; skipped, the selection is unchanged', (tester) async {
    final app = FakeSetupApp();
    final opened = await _open(tester, app);

    expect(find.byKey(_voice), findsOneWidget);
    expect(find.text('Voice typing'), findsOneWidget);
    final row = _row(tester);
    expect(row.value, isFalse);
    expect(row.onChanged, isNotNull);
    expect(
      row.supporting,
      'Speak instead of typing, even offline · ~160\u00A0MB',
    );

    await _done(tester);
    expect(opened.closed, isTrue);
    expect(opened.result, isNot(contains('voice')));
    expect(opened.result, contains('python'));
    expect(app.installs, 0);
  });

  testWidgets('turned on, it joins the selection and the totals', (
    tester,
  ) async {
    final app = FakeSetupApp();
    final opened = await _open(tester, app);
    String totals() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('phone-setup-customize-cost')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' ');
    final before = totals();

    await tester.tap(find.byKey(_voice));
    await tester.pumpAndSettle();
    expect(_row(tester).value, isTrue);
    expect(totals(), isNot(before));

    await _done(tester);
    expect(opened.result, contains('voice'));
  });

  testWidgets('a phone that cannot run any speech model is not offered it', (
    tester,
  ) async {
    final opened = await _open(tester, FakeSetupApp(offered: null));
    expect(find.byKey(_voice), findsNothing);
    expect(find.text('Voice typing'), findsNothing);
    await _done(tester);
    expect(opened.result, isNot(contains('voice')));
  });

  testWidgets('already on the phone, it shows as installed and can be '
      'removed from here after a question', (tester) async {
    final app = FakeSetupApp(installed: true);
    await _open(tester, app);

    final row = _row(tester);
    expect(row.value, isTrue);
    expect(row.locked, 'Installed');
    expect(row.supporting, 'Speak instead of typing, even offline');

    final remove = find.byKey(
      const ValueKey('phone-setup-customize-remove-voice'),
    );
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Remove voice typing?'), findsOneWidget);
    expect(
      find.textContaining('frees 160 MB', findRichText: true),
      findsOneWidget,
    );
    expect(app.removes, 0, reason: 'nothing is deleted before the answer');

    await tester.tap(
      find.byKey(const ValueKey('phone-setup-customize-remove-voice-confirm')),
    );
    await tester.pumpAndSettle();
    expect(app.removes, 1);
    final after = _row(tester);
    expect(after.locked, isNull);
    expect(after.value, isFalse);
    expect(after.onChanged, isNotNull);
  });

  testWidgets('Add tools offers it when it is not installed', (tester) async {
    final app = FakeSetupApp();
    final opened = await _open(
      tester,
      app,
      addMode: true,
      optionalInstalled: {'python'},
    );
    expect(_row(tester).value, isFalse);
    await tester.tap(find.byKey(_voice));
    await tester.pumpAndSettle();
    await _done(tester);
    expect(opened.result, {'voice'});
  });

  testWidgets('Add tools shows it installed with its removal', (tester) async {
    final app = FakeSetupApp(installed: true);
    await _open(
      tester,
      app,
      addMode: true,
      optionalInstalled: {'python', 'voice'},
    );
    expect(_row(tester).locked, 'Installed');
    expect(
      find.byKey(const ValueKey('phone-setup-customize-remove-voice')),
      findsOneWidget,
    );
    // Every optional tool is on the phone: nothing left to add.
    expect(
      find.text('Every optional tool is already on this phone.'),
      findsOneWidget,
    );
  });
}
