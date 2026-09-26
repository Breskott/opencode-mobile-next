// KitStatusMark and KitTaskMark v2 (docs/ux-system/kit-api/KitStatusMark.md):
// a paused modifier and a word beside every mark, so no state is shown by
// colour alone (slice-P9.5). The reduced-motion samples (G8x, MOT-7) already
// live in test/kit_motion_test.dart (a shared file this unit does not
// touch); this file covers the rest of the K2 §7 contracts (KIT-12).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

const _enMarkWords = {
  KitMarkState.waiting: 'Waiting',
  KitMarkState.working: 'Working',
  KitMarkState.done: 'Done',
  KitMarkState.failed: 'Failed',
};

const _arMarkWords = {
  KitMarkState.waiting: 'بانتظار',
  KitMarkState.working: 'يعمل',
  KitMarkState.done: 'انتهى',
  KitMarkState.failed: 'فشل',
};

const _enTaskWords = {
  KitTaskState.waiting: 'Waiting',
  KitTaskState.working: 'Working',
  KitTaskState.done: 'Done',
  KitTaskState.failed: 'Failed',
  KitTaskState.needsYou: 'Needs you',
  KitTaskState.stopped: 'Stopped',
};

const _arTaskWords = {
  KitTaskState.waiting: 'بانتظار',
  KitTaskState.working: 'يعمل',
  KitTaskState.done: 'انتهى',
  KitTaskState.failed: 'فشل',
  KitTaskState.needsYou: 'يحتاجك',
  KitTaskState.stopped: 'متوقف',
};

void main() {
  group('default word in semantics (English and Arabic)', () {
    for (final MapEntry(key: state, value: word) in _enMarkWords.entries) {
      testWidgets('KitStatusMark $state announces "$word" in English', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_host(KitStatusMark(state: state)));
          expect(find.bySemanticsLabel(word), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
    for (final MapEntry(key: state, value: word) in _arMarkWords.entries) {
      testWidgets('KitStatusMark $state announces "$word" in Arabic', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _host(KitStatusMark(state: state), locale: const Locale('ar')),
          );
          expect(find.bySemanticsLabel(word), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
    for (final MapEntry(key: state, value: word) in _enTaskWords.entries) {
      testWidgets('KitTaskMark $state announces "$word" in English', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_host(KitTaskMark(state: state)));
          expect(find.bySemanticsLabel(word), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
    for (final MapEntry(key: state, value: word) in _arTaskWords.entries) {
      testWidgets('KitTaskMark $state announces "$word" in Arabic', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _host(KitTaskMark(state: state), locale: const Locale('ar')),
          );
          expect(find.bySemanticsLabel(word), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
  });

  group('label overrides the word; showLabel shows it', () {
    testWidgets('a custom label replaces the default word in semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            const KitStatusMark(
              state: KitMarkState.working,
              label: 'Installing',
            ),
          ),
        );
        expect(find.bySemanticsLabel('Installing'), findsOneWidget);
        expect(find.bySemanticsLabel('Working'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('showLabel draws the word as visible text beside the mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.done, showLabel: true)),
      );
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('without showLabel the word is not drawn as visible text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.done)),
      );
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('KitTaskMark showLabel draws needsYou\'s word', (tester) async {
      await tester.pumpWidget(
        _host(const KitTaskMark(state: KitTaskState.needsYou, showLabel: true)),
      );
      expect(find.text('Needs you'), findsOneWidget);
    });
  });

  group('paused (G37)', () {
    testWidgets('paused waiting shows the pause glyph and word "Paused"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            const KitStatusMark(
              state: KitMarkState.waiting,
              paused: true,
              showLabel: true,
            ),
          ),
        );
        expect(find.byIcon(AppIconography.pause), findsOneWidget);
        expect(find.text('Paused'), findsOneWidget);
        expect(find.bySemanticsLabel('Paused'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('paused working also shows the pause glyph', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.working, paused: true)),
      );
      expect(find.byIcon(AppIconography.pause), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('paused with done throws an AssertionError', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.done, paused: true)),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('paused with failed throws an AssertionError', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.failed, paused: true)),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('KitTaskMark paused with needsYou throws an AssertionError', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const KitTaskMark(state: KitTaskState.needsYou, paused: true)),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('KitTaskMark paused with stopped throws an AssertionError', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const KitTaskMark(state: KitTaskState.stopped, paused: true)),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('colour roles (LOOK-5, LOOK-6, STATE-9)', () {
    // A pack where accent is nowhere near success/attention/danger's hues
    // (the default "opencode" pack's accent and success happen to be the
    // same green, which would make a color-equality check meaningless), so
    // a role mix-up shows up as a real assertion failure.
    final roles = deriveRoles(
      accent: const Color(0xFF3B82F6),
      ground: const Color(0xFF0B0C0E),
      brightness: Brightness.dark,
    );
    final theme = AppTheme.fromRoles(roles);

    Color? iconColorIn(WidgetTester tester, Finder of) => tester
        .widget<Icon>(find.descendant(of: of, matching: find.byType(Icon)))
        .color;

    testWidgets('done paints success, never accent', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.done), theme: theme),
      );
      final color = iconColorIn(tester, find.byType(KitStatusMark));
      expect(color, AppTheme.successOf(theme));
      expect(color, isNot(roles.accent));
    });

    testWidgets('failed paints text1, never danger', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.failed), theme: theme),
      );
      final color = iconColorIn(tester, find.byType(KitStatusMark));
      expect(color, roles.text1);
      expect(color, isNot(roles.danger));
    });

    testWidgets('working paints accent', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.working), theme: theme),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, roles.accent);
    });

    testWidgets('needsYou paints attention', (tester) async {
      await tester.pumpWidget(
        _host(const KitTaskMark(state: KitTaskState.needsYou), theme: theme),
      );
      final color = iconColorIn(tester, find.byType(KitTaskMark));
      expect(color, roles.attention);
    });

    testWidgets('paused and stopped paint text2', (tester) async {
      await tester.pumpWidget(
        _host(
          const KitStatusMark(state: KitMarkState.waiting, paused: true),
          theme: theme,
        ),
      );
      expect(iconColorIn(tester, find.byType(KitStatusMark)), roles.text2);
      await tester.pumpWidget(
        _host(const KitTaskMark(state: KitTaskState.stopped), theme: theme),
      );
      expect(iconColorIn(tester, find.byType(KitTaskMark)), roles.text2);
    });
  });

  group('existing callers compile unchanged (KIT-43)', () {
    testWidgets('KitStatusMark with only state still renders', (tester) async {
      await tester.pumpWidget(
        _host(const KitStatusMark(state: KitMarkState.waiting)),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(KitStatusMark), findsOneWidget);
    });

    testWidgets('KitTaskMark with only state still renders', (tester) async {
      await tester.pumpWidget(
        _host(const KitTaskMark(state: KitTaskState.needsYou)),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(KitTaskMark), findsOneWidget);
    });
  });
}
