import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_markdown.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SkillsRepository implements ProductRepository {
  const _SkillsRepository(this.skills);

  final List<SkillInfo> skills;

  @override
  Future<List<SkillInfo>> listSkills() async => skills;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller(ProductRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ConnectionController(ProfileStore(prefs: preferences))
    ..repository = repository
    ..status = StreamStatus.connected;
}

Widget _app(ConnectionController controller) =>
    MaterialApp(home: SkillsScreen(controller: controller));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('skill content uses the shared Markdown and code renderer', (
    tester,
  ) async {
    final controller = await _controller(
      const _SkillsRepository([
        SkillInfo(
          name: 'release-check',
          description: 'Verify a release',
          location: '/work/.opencode/skills/release-check/SKILL.md',
          content: '''# Release check

| Gate | Command |
| --- | --- |
| Tests | `flutter test` |

```sh
flutter analyze
```''',
          slashCommand: true,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('release-check'));
    await tester.pumpAndSettle();

    // The one skill sheet (cf8f5eda): the kit's Markdown renderer, with
    // Rendered / Raw; the heading that only repeats the skill's name is
    // stripped (the sheet title says it).
    final preview = find.byKey(const Key('skill-content-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.byType(KitMarkdown)),
      findsOneWidget,
    );
    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Raw'), findsOneWidget);
    expect(find.text('Release check'), findsNothing);
    expect(find.text('Gate'), findsOneWidget);
    expect(find.text('Tests'), findsOneWidget);
    expect(find.text('flutter analyze'), findsOneWidget);
    expect(find.textContaining('| Gate | Command |'), findsNothing);

    await tester.tap(find.text('Raw'));
    await tester.pumpAndSettle();

    // Raw is the file as it is, in the kit's code block named SKILL.md.
    expect(
      find.descendant(of: preview, matching: find.byType(KitCodeBlock)),
      findsOneWidget,
    );
    expect(
      find.textContaining('| Gate | Command |', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('SKILL.md'), findsOneWidget);
  });

  testWidgets('skill preview fits a narrow large-text phone', (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _controller(
      const _SkillsRepository([
        SkillInfo(
          name: 'mobile-skill',
          location: '/work/.opencode/skills/mobile-skill/SKILL.md',
          content: '# Mobile skill\n\nUse **careful** rendering.',
          slashCommand: false,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    // 200 % text from the device, so the app keeps the real screen size
    // (the full-height skill sheet measures it).
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mobile-skill'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The heading repeats the name, so the prose starts under it.
    expect(find.text('Mobile skill'), findsNothing);
    expect(
      find.textContaining('rendering', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Raw'), findsOneWidget);
  });

  testWidgets('standalone references copy their exact OpenCode mention', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final controller = await _controller(
      const _ReferencesRepository([
        ReferenceInfo(
          name: 'platform-docs',
          path: '/references/platform',
          description: 'Platform guidance',
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ReferencesScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    // A reference opens its sheet, whose one action copies the mention
    // (cf8f5eda); the button itself says it copied, no snackbar.
    await tester.tap(find.byKey(const Key('reference-platform-docs')));
    await tester.pumpAndSettle();
    expect(copiedText, isNull);
    await tester.tap(find.byKey(const Key('reference-copy')));
    await tester.pump();

    expect(copiedText, '@platform-docs');
    expect(
      find.descendant(
        of: find.byKey(const Key('reference-copy')),
        matching: find.text('Copied'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpAndSettle();
  });
}

class _ReferencesRepository implements ProductRepository {
  const _ReferencesRepository(this.references);

  final List<ReferenceInfo> references;

  @override
  Future<List<ReferenceInfo>> listReferences() async => references;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
