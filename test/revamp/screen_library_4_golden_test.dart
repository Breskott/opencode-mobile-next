// Golden renders of screen-library-4's pages (wave 2b): Server commands,
// References (list, details sheet, empty) and Skills (list, the skill sheet
// as a preview and from a conversation after a failed add). Phone 412x915
// and one wide window (1280x800) for the lists, dark and light (owner
// decision 2026-09-27: no Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_library_4_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

class _Repository extends ProductRepository implements SessionSkillGateway {
  List<CommandInfo> commands = const [];
  List<ReferenceInfo> references = const [];
  List<SkillInfo> skills = const [];
  Object? loadFailure;
  Object? activationFailure;
  Session session = Session(id: 'ses_test', title: 'Composer improvements');

  Future<T> _answer<T>(T value) async {
    final failure = loadFailure;
    if (failure != null) throw failure;
    return value;
  }

  @override
  Future<List<CommandInfo>> listCommands() => _answer(commands);

  @override
  Future<List<ReferenceInfo>> listReferences() => _answer(references);

  @override
  Future<List<SkillInfo>> listSkills() => _answer(skills);

  @override
  bool get sessionSkillsSupported => true;

  @override
  Future<Session> getSessionDetails(String id) async => session;

  @override
  Future<void> activateSessionSkill(
    String sessionID,
    String skillID, {
    required bool resume,
  }) async {
    final failure = activationFailure;
    if (failure != null) throw failure;
  }

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;
}

const _commands = [
  CommandInfo(
    name: 'review',
    description: 'Review the working tree for bugs and risky changes',
    agent: 'plan',
    subtask: false,
  ),
  CommandInfo(
    name: 'release-notes',
    description: 'Draft release notes from merged changes',
    subtask: false,
  ),
  CommandInfo(
    name: 'test',
    description: 'Run the focused tests for the files you changed',
    agent: 'build',
    subtask: true,
  ),
  CommandInfo(name: 'init', subtask: false),
];

const _references = [
  ReferenceInfo(
    name: 'platform-docs',
    path: '/work/references/platform-docs',
    description: 'Android platform guidance the app follows',
  ),
  ReferenceInfo(
    name: 'design-system',
    path: '/work/references/design-system',
    description: 'The kit contracts and the visual language',
  ),
  ReferenceInfo(name: 'opencode', path: '/work/references/opencode'),
];

const _skills = [
  SkillInfo(
    id: 'focused-review',
    name: 'focused-review',
    description: 'Review a change for correctness and readability',
    location: '/work/.opencode/skills/focused-review/SKILL.md',
    content:
        '---\nname: focused-review\ndescription: Review a change\n---\n'
        '# Focused review\n\nReview the current change before it is '
        'merged.\n\n## Steps\n\n- Explain concrete issues with file and '
        'line.\n- Keep the patch **focused**.\n- Preserve the author’s '
        'intent.\n\n```sh\nflutter analyze\n```',
    slashCommand: true,
  ),
  SkillInfo(
    name: 'release-check',
    description: 'Verify a release candidate before it ships',
    location: '/work/.opencode/skills/release-check/SKILL.md',
    content: '# Release check\n\nRun the gates.',
    slashCommand: false,
  ),
  SkillInfo(
    name: 'translate',
    location: '/home/me/.config/opencode/skills/translate/SKILL.md',
    content: 'Translate the copy.',
    slashCommand: false,
  ),
];

Future<(_Controller, _Repository)> _server() async {
  SharedPreferences.setMockInitialValues({});
  final repository = _Repository()
    ..commands = _commands
    ..references = _references
    ..skills = _skills;
  final controller = _Controller(
    ProfileStore(prefs: await SharedPreferences.getInstance()),
  )..repository = repository;
  controller.sessionsById['ses_test'] = repository.session;
  return (controller, repository);
}

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
  required Widget home,
  Size size = _phone,
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) {
      await act();
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final tone = light ? 'light' : 'dark';

    group('commands ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('loaded ${size.width.toInt()}', (tester) async {
          final (controller, _) = await _server();
          addTearDown(controller.dispose);
          await _shot(
            tester,
            'library_commands_loaded',
            light: light,
            size: size,
            home: CommandsScreen(controller: controller),
          );
        });
      }

      testWidgets('load failed', (tester) async {
        final (controller, repository) = await _server();
        addTearDown(controller.dispose);
        repository.loadFailure = const ProductException(
          'Laptop did not answer. Check that OpenCode is running.',
        );
        await _shot(
          tester,
          'library_commands_failed',
          light: light,
          home: CommandsScreen(controller: controller),
        );
      });
    });

    group('references ($tone)', () {
      testWidgets('loaded', (tester) async {
        final (controller, _) = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_references_loaded',
          light: light,
          home: ReferencesScreen(controller: controller),
        );
      });

      testWidgets('details sheet', (tester) async {
        final (controller, _) = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_references_sheet',
          light: light,
          home: ReferencesScreen(controller: controller),
          act: () async {
            await tester.tap(
              find.byKey(const ValueKey('reference-platform-docs')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('kit-details-toggle')));
          },
        );
      });

      testWidgets('empty', (tester) async {
        final (controller, repository) = await _server();
        addTearDown(controller.dispose);
        repository.references = const [];
        await _shot(
          tester,
          'library_references_empty',
          light: light,
          home: ReferencesScreen(controller: controller),
        );
      });
    });

    group('skills ($tone)', () {
      for (final size in [_phone, _wide]) {
        testWidgets('loaded ${size.width.toInt()}', (tester) async {
          final (controller, _) = await _server();
          addTearDown(controller.dispose);
          await _shot(
            tester,
            'library_skills_loaded',
            light: light,
            size: size,
            home: SkillsScreen(controller: controller),
          );
        });
      }

      testWidgets('preview sheet', (tester) async {
        final (controller, _) = await _server();
        addTearDown(controller.dispose);
        await _shot(
          tester,
          'library_skill_sheet_preview',
          light: light,
          home: SkillsScreen(controller: controller),
          act: () =>
              tester.tap(find.byKey(const ValueKey('skill-focused-review'))),
        );
      });

      testWidgets('add sheet after a failed add', (tester) async {
        final (controller, repository) = await _server();
        addTearDown(controller.dispose);
        repository.activationFailure = const SessionSkillException(
          SessionSkillFailure.busy,
        );
        await _shot(
          tester,
          'library_skill_sheet_add_failed',
          light: light,
          home: SkillsScreen(controller: controller, sessionID: 'ses_test'),
          act: () async {
            await tester.tap(
              find.byKey(const ValueKey('skill-focused-review')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('skill-activate')));
          },
        );
      });
    });
  }
}
