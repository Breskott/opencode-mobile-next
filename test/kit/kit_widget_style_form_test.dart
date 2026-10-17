// KitWidgetStyleForm: the choices that style one home-screen widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _ids = ['wallpaper', 'app', 'green', 'teal', 'blue', 'amber'];

Widget _form({
  String size = 'card',
  String background = 'solid',
  String accent = 'green',
  bool locked = false,
  ValueChanged<String>? onSize,
  ValueChanged<String>? onBackground,
  ValueChanged<String>? onAccent,
}) => KitWidgetStyleForm(
  previewSize: size,
  background: background,
  accent: accent,
  accentIds: _ids,
  accentName: (id) => 'name $id',
  accentColor: (id) => Color(0xFF000000 + id.hashCode % 0xFFFFFF),
  onPreviewSize: onSize ?? (_) {},
  onBackground: onBackground ?? (_) {},
  onAccent: onAccent ?? (_) {},
  locked: locked,
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  kitMotionStillTests(
    'KitWidgetStyleForm',
    builds: {'default': () => _form(), 'locked': () => _form(locked: true)},
    changes: {
      'another accent is chosen': KitMotionChange(
        build: () => _form(),
        act: (tester, stage) => stage.rebuild(_form(accent: 'blue')),
        shows: 'name blue',
      ),
    },
  );

  testWidgets('each choice goes back to the host by id', (tester) async {
    final got = <String>[];
    await tester.pumpWidget(
      _app(
        _form(
          onSize: (v) => got.add('size:$v'),
          onBackground: (v) => got.add('bg:$v'),
          onAccent: (v) => got.add('accent:$v'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wide'));
    await tester.tap(find.text('Transparent'));
    await tester.tap(find.byKey(const ValueKey('widget-accent-blue')));
    expect(got, ['size:list', 'bg:transparent', 'accent:blue']);
  });

  testWidgets('locked: the ground and accent hold still', (tester) async {
    final got = <String>[];
    await tester.pumpWidget(
      _app(_form(locked: true, onBackground: got.add, onAccent: got.add)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tinted'));
    await tester.tap(find.byKey(const ValueKey('widget-accent-teal')));
    expect(got, isEmpty);
  });

  testWidgets('names the chosen accent', (tester) async {
    await tester.pumpWidget(_app(_form(accent: 'amber')));
    await tester.pumpAndSettle();
    expect(find.text('name amber'), findsOneWidget);
  });
}
