// Golden renders of shared-system-1's pages (wave 2a): the shared product
// states (embedded-product-states), the external-link gate
// (external-link-dialog) and the run-command sheet (run-command-dialog),
// now built from kit parts only. Phone 412x915 and one wide window
// (1280x800), dark and light (owner decision 2026-09-27: no Arabic), with
// the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_system_1_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_row_parts.dart';
import 'package:opencode_mobile/ui/widgets/external_link.dart';
import 'package:opencode_mobile/ui/widgets/product_states.dart';
import 'package:opencode_mobile/ui/widgets/run_command_dialog.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import 'shared_system_1_fixtures.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required Size size,
  Widget body = const SizedBox.expand(),
  FutureOr<void> Function(BuildContext context)? open,
  Future<void> Function()? then,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    late BuildContext context;
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
            body: SafeArea(
              child: Builder(
                builder: (inner) {
                  context = inner;
                  return body;
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (open != null) unawaited(Future.sync(() => open(context)));
    await tester.pumpAndSettle();
    if (then != null) {
      await then();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    for (final size in [_phone, _wide]) {
      final where = '$theme, ${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('product error, unexpected ($where)', (tester) async {
        await _shot(
          tester,
          'system_embedded-product-states_error',
          light: light,
          size: size,
          body: ProductErrorState(
            title: "Couldn't load skills",
            message: 'The server answered with something this app cannot read.',
            details: 'GET /skill 500\n{"error":"skills index corrupt"}',
            onRetry: () async {},
          ),
        );
      });

      testWidgets('product error, network ($where)', (tester) async {
        await _shot(
          tester,
          'system_embedded-product-states_network-error',
          light: light,
          size: size,
          body: ProductErrorState(
            message: 'OpenCode is unreachable. Try again.',
            error: const SocketException('Connection refused'),
            onSwitchServer: () {},
            onRetry: () async {},
          ),
        );
      });

      testWidgets('product empty ($where)', (tester) async {
        await _shot(
          tester,
          'system_embedded-product-states_empty',
          light: light,
          size: size,
          body: ProductEmptyState(
            icon: AppIconography.checklist,
            title: 'No skills yet',
            message: 'Skills this server knows show here.',
            actionLabel: 'Reload skills',
            onAction: () {},
          ),
        );
      });

      testWidgets('refresh notice, section, gated row, inline empty '
          '($where)', (tester) async {
        await _shot(
          tester,
          'system_embedded-product-states_rows',
          light: light,
          size: size,
          body: ProductRefreshBody(
            message: 'The server did not answer in 30 s.',
            onRetry: () {},
            child: ListView(
              children: const [
                SectionLabel('Server'),
                GatedRow(
                  feature: 'shell',
                  title: 'Default shell',
                  explainer: gatedOnV2Explainer,
                  leading: KitRowIcon(AppIconography.terminal),
                ),
                SectionLabel('Todos'),
                ProductInlineEmpty(
                  icon: AppIconography.checklist,
                  title: 'No todos in this conversation',
                  message:
                      'When the assistant plans work, the steps show here.',
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('external link, https ($where)', (tester) async {
        await _shot(
          tester,
          'system_external-link-dialog_https',
          light: light,
          size: size,
          open: (context) => openExternalLink(
            context,
            'https://docs.opencode.ai/guides/review?tab=cli',
            launcher: (_) async => true,
          ),
        );
      });

      testWidgets('external link, insecure http ($where)', (tester) async {
        await _shot(
          tester,
          'system_external-link-dialog_insecure-http',
          light: light,
          size: size,
          open: (context) => openExternalLink(
            context,
            'http://192.168.1.20:8080/status',
            launcher: (_) async => true,
          ),
        );
      });

      testWidgets('external link, blocked ($where)', (tester) async {
        await _shot(
          tester,
          'system_external-link-dialog_blocked',
          light: light,
          size: size,
          open: (context) => openExternalLink(context, 'intent://steal#end'),
        );
      });

      Future<void> openRun(
        WidgetTester tester,
        String shot, {
        Object? failure,
      }) async {
        final api = SystemCommandsApi()
          ..failure = failure
          ..seeded = [
            Session(id: 'recent', title: 'Fix the login redirect'),
            Session(id: 'old', title: 'Release notes for 1.0.44'),
          ];
        final controller = await systemController(api);
        addTearDown(controller.dispose);
        await _shot(
          tester,
          shot,
          light: light,
          size: size,
          open: (context) => showRunCommandDialog(
            context,
            controller: controller,
            command: const CommandInfo(
              name: 'review',
              description: 'Review the uncommitted changes',
              subtask: false,
            ),
          ),
          then: failure == null
              ? null
              : () async {
                  await tester.enterText(
                    find.byKey(const ValueKey('command-arguments')),
                    'staged only',
                  );
                  await tester.tap(
                    find.byKey(const ValueKey('command-submit')),
                  );
                },
        );
      }

      testWidgets('run command, idle ($where)', (tester) async {
        await openRun(tester, 'system_run-command-dialog_idle');
      });

      testWidgets('run command, run failed ($where)', (tester) async {
        await openRun(
          tester,
          'system_run-command-dialog_run-failed',
          failure: const ProductException(
            'The command review is not installed on this server.',
          ),
        );
      });
    }
  }
}
