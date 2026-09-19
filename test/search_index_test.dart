import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/api2/gateway_mappers.dart'
    show api2ServerCapabilities;
import 'package:opencode_mobile/codex/gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/paseo/gateway.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/desktop/shortcuts.dart';
import 'package:opencode_mobile/ui/screens/project_hub_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/search/search_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ledger pages of kind screen/tab that search deliberately does not list,
/// each with the reason. Everything else must be found by its title.
const _excluded = <String, String>{
  // Not reachable by choice: the app shows them on its own.
  'home-shell': 'the frame around the four tabs; each tab is found on its own',
  'root-connecting': 'shown automatically while a saved server connects',
  'bootstrap-gate': 'startup failure screen; nothing is connected yet',
  'servers-welcome': 'first run only, before any server exists',
  'demo': 'offered on the first-run welcome only; owned by phase 3b',
  // Need a conversation: the conversation menu and its command launcher are
  // their search (phase 4 adds them to this index through the registry).
  'chat': 'a conversation; opened from Work, Inbox or All conversations',
  'active-context': 'needs an open conversation',
  'active-context-message': 'needs an open conversation and a message',
  'prompt-editor': 'needs an open conversation (composer)',
  'context-capsule': 'needs an open conversation',
  'run-result': 'needs an open conversation',
  'session-context': 'needs an open conversation',
  'session-export': 'needs an open conversation',
  'session-note': 'needs an open conversation',
  'session-relations': 'needs an open conversation',
  'markdown-code-reader': 'needs a code block in a transcript',
  'web-sources': 'adds a source to the open conversation',
  'legacy-drafts': 'restores a draft into the open conversation',
  'staged-revert': 'needs a staged revert in an open conversation',
  // Need something picked first.
  'manage-project': 'needs a project; opened from the Work project header',
  'managed-workspaces': 'needs a project; opened from Manage project',
  'projects': 'a picker that returns the chosen project to Work',
  'workspace-folder-chooser': 'a state of the Work tab, not a place',
  'development-services': 'needs a project; opened from Manage project',
  'shell-output': 'the output of one command that was just run',
  'terminal-surface': 'one terminal process; opened from Terminal',
  'diff-view': 'one file of a review; opened from Changes',
  'external-agent-detail': 'one external agent; opened from External agents',
  'external-task': 'one task of one external agent',
  'add-agent': 'a form inside External agents',
  'profile-editor': 'a form inside Saved servers; owned by phase 3b',
  'pairing-scanner': 'a step of adding a server',
  'team-agent': 'one agent of one AI Team run',
  'team-agent-output': 'one agent of one AI Team run',
  'team-run': 'one AI Team run',
  'team-run-agents-tab': 'a tab of one AI Team run',
  'team-run-overview-tab': 'a tab of one AI Team run',
  'team-run-work-tab': 'a tab of one AI Team run',
  'team-run-timeline-tab': 'a tab of one AI Team run',
};

class _Api extends OpenCodeApi {
  _Api(this._capabilities) : super(baseUrl: 'http://localhost');

  final ServerCapabilities _capabilities;

  @override
  ServerCapabilities get capabilities => _capabilities;

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.23');
}

class _Repository
    implements ProductRepository, SessionImportGateway, UsageStatisticsGateway {
  @override
  bool get sessionImportSupported => true;

  @override
  bool get usageStatisticsSupported => true;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<TerminalShellSettings> loadTerminalShellSettings() async =>
      const TerminalShellSettings(selected: '', options: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller({
  ServerCapabilities capabilities = ServerCapabilities.allV1,
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Workstation',
        'baseUrl': 'http://localhost:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  await store.load();
  return ConnectionController(store)
    ..api = _Api(capabilities)
    ..repository = _Repository()
    ..status = StreamStatus.connected;
}

final _en = lookupAppLocalizations(const Locale('en'));

/// Records what the shell is asked for, the way HomeScreen would.
class _Shell extends StatefulWidget {
  const _Shell({required this.child, required this.seen});
  final Widget child;
  final List<Intent> seen;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with AppShortcutSurface<_Shell> {
  @override
  bool onAppShortcut(Intent intent) {
    widget.seen.add(intent);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _app(
  ConnectionController controller, {
  Locale locale = const Locale('en'),
  List<Intent>? shell,
}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: shell == null
      ? null
      : (context, child) => AppShortcutScope(signals: _signals, child: child!),
  home: shell == null
      ? SettingsScreen(controller: controller)
      : _Shell(
          seen: shell,
          child: SettingsScreen(controller: controller),
        ),
);

final _signals = AppShortcutSignals();

Finder _key(String key) => find.byKey(ValueKey(key));

Set<String> _ids(Iterable<SearchEntry> entries) => {
  for (final entry in entries) entry.id,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() => debugPlatformCapabilities = null);

  group('ledger coverage', () {
    final ledger =
        jsonDecode(File('docs/design/ui-ledger/ledger.json').readAsStringSync())
            as Map<String, dynamic>;
    final pages = [
      for (final page in ledger['pages'] as List)
        if (const {'screen', 'tab'}.contains((page as Map)['kind']))
          page.cast<String, dynamic>(),
    ];
    final entries = allSearchEntries(_en);

    /// A title as a person would type it: one alternative of "A | B", without
    /// a trailing "({count})".
    List<String> titles(String title) => [
      for (final part in title.split(' | '))
        part.replaceAll(RegExp(r'\s*\(\{[a-z]+\}\)$'), '').trim(),
    ];

    test('every screen and tab is found by its title, or is excluded', () {
      final missing = <String>[];
      var findable = 0;
      for (final page in pages) {
        final id = page['id'] as String;
        if (_excluded.containsKey(id)) continue;
        final failed = [
          for (final title in titles(page['title'] as String))
            if (!entries.any(
              (entry) => entry.pages.contains(id) && entry.matches(title),
            ))
              title,
        ];
        if (failed.isEmpty) {
          findable++;
        } else {
          missing.add('$id: ${failed.join(' / ')}');
        }
      }
      expect(missing, isEmpty, reason: 'not findable by title');
      // The numbers the phase report quotes.
      expect(findable + _excluded.length, pages.length);
      // ignore: avoid_print
      print(
        'search coverage: $findable findable + ${_excluded.length} excluded '
        '= ${pages.length} screen/tab pages',
      );
    });

    test('exclusions are real pages, have a reason, and are not indexed', () {
      final ids = {for (final page in pages) page['id'] as String};
      for (final excluded in _excluded.entries) {
        expect(ids, contains(excluded.key), reason: 'stale exclusion');
        expect(excluded.value.trim(), isNotEmpty);
        expect(
          entries.where((entry) => entry.pages.contains(excluded.key)),
          isEmpty,
          reason: '${excluded.key} is indexed; drop the exclusion',
        );
      }
    });

    test('every indexed page id exists in the ledger', () {
      final ids = {
        for (final page in ledger['pages'] as List) (page as Map)['id'],
      };
      for (final entry in entries) {
        for (final page in entry.pages) {
          // The capability list is added to the ledger with its own step.
          expect(ids, contains(page), reason: '${entry.id} -> $page');
        }
      }
    });

    test('ids are unique and every entry can be found by its own title', () {
      expect(_ids(entries).length, entries.length);
      for (final entry in entries) {
        expect(entry.matches(entry.title), isTrue, reason: entry.id);
        expect(entry.title.trim(), isNotEmpty, reason: entry.id);
      }
      final ar = allSearchEntries(lookupAppLocalizations(const Locale('ar')));
      expect(_ids(ar), _ids(entries));
      for (final entry in ar) {
        expect(entry.matches(entry.title), isTrue, reason: 'ar ${entry.id}');
      }
    });
  });

  group('gates: a result the server or device cannot open is absent', () {
    SearchScope scope(
      ConnectionController controller, {
      PlatformCapabilities platform = const PlatformCapabilities.android(),
      bool hasShell = true,
      bool hasTeam = false,
      bool desktop = false,
    }) => SearchScope(
      controller: controller,
      platform: platform,
      hasShell: hasShell,
      hasTeam: hasTeam,
      desktop: desktop,
    );

    test(
      'OpenCode 1 on a phone has everything but desktop and AI Team',
      () async {
        final controller = await _controller();
        addTearDown(controller.dispose);
        final ids = _ids(searchIndex(_en, scope(controller)));
        expect(
          ids,
          containsAll([
            'tab-work',
            'tab-inbox',
            'tab-project',
            'project-files',
            'project-changes',
            'project-terminal',
            'project-health',
            'project-worktrees',
            'project-search',
            'all-conversations',
            'settings-mcp',
            'inside-capabilities-tools',
            'inside-notifications-quiet',
            'inside-phone-running-now',
            'settings-on-this-phone',
          ]),
        );
        expect(ids, isNot(contains('ai-team')));
        expect(ids, isNot(contains('library-keyboard-shortcuts')));
        expect(ids, isNot(contains('settings-accounts')));
        expect(
          _ids(searchIndex(_en, scope(controller, hasTeam: true))),
          contains('ai-team'),
        );
      },
    );

    for (final backend in {
      'Codex': codexServerCapabilities,
      'Paseo': paseoServerCapabilities,
    }.entries) {
      test('${backend.key} drops the catalog and the Project tools', () async {
        final capabilities = backend.value;
        final controller = await _controller(capabilities: capabilities);
        addTearDown(controller.dispose);
        final index = searchIndex(_en, scope(controller));
        final ids = _ids(index);
        for (final id in [
          'settings-models',
          'settings-providers',
          'settings-mcp',
          'settings-commands-tools',
          'inside-capabilities-commands',
          'inside-capabilities-tools',
          'inside-capabilities-skills',
          'inside-capabilities-references',
        ]) {
          expect(ids, isNot(contains(id)), reason: id);
        }
        final tools = ProjectHub.toolsFor(capabilities);
        for (final tool in ProjectTool.values) {
          expect(
            ids.contains('project-${tool.name}'),
            tools.contains(tool),
            reason: tool.name,
          );
        }
        expect(ids.contains('tab-project'), tools.isNotEmpty);
        expect(
          ids.contains('all-conversations'),
          capabilities.globalSessionSearch,
        );
        expect(ids.contains('settings-accounts'), capabilities.agentAccount);
        // Typing the name of something absent finds nothing that opens it.
        expect(
          searchEntries(
            _en,
            scope(controller),
            _en.libraryMcpTitle,
          ).where((entry) => entry.pages.contains('integrations')),
          isEmpty,
        );
        // What is about the app, not the server, survives.
        expect(
          ids,
          containsAll([
            'settings-category-appearance',
            'inside-appearance-language',
            'tab-work',
            'tab-inbox',
          ]),
        );
      });
    }

    test('OpenCode 2 keeps the catalog', () async {
      final controller = await _controller(
        capabilities: api2ServerCapabilities,
      );
      addTearDown(controller.dispose);
      final ids = _ids(searchIndex(_en, scope(controller)));
      expect(
        ids.contains('settings-mcp'),
        api2ServerCapabilities.serverCatalog,
      );
      expect(ids.contains('project-terminal'), api2ServerCapabilities.terminal);
      expect(
        ids.contains('inside-capabilities-tools'),
        api2ServerCapabilities.serverCatalog &&
            api2ServerCapabilities.toolInventory,
      );
    });

    test('a desktop has no phone-only results and gains shortcuts', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final ids = _ids(
        searchIndex(
          _en,
          scope(
            controller,
            platform: const PlatformCapabilities(
              platform: TargetPlatform.linux,
            ),
            desktop: true,
          ),
        ),
      );
      for (final id in [
        'settings-on-this-phone',
        'inside-phone-running-now',
        'inside-phone-storage',
        'settings-tailscale',
        'settings-voice',
        'settings-voice-notices',
        'inside-notifications-quiet',
        'inside-notifications-background',
      ]) {
        expect(ids, isNot(contains(id)), reason: id);
      }
      expect(ids, contains('library-keyboard-shortcuts'));
    });

    test('without the shell, what lives in its tabs is absent', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final ids = _ids(searchIndex(_en, scope(controller, hasShell: false)));
      for (final id in [
        'tab-work',
        'tab-inbox',
        'tab-project',
        'tab-settings',
        'project-files',
        'project-search',
      ]) {
        expect(ids, isNot(contains(id)), reason: id);
      }
      // Tools that are screens of their own still open from anywhere.
      expect(ids, containsAll(['project-terminal', 'project-changes']));
    });

    test('title matches rank above keyword matches', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final results = searchEntries(_en, scope(controller), 'terminal');
      expect(results.first.id, 'project-terminal');
      expect(_ids(results), contains('default-shell-settings-entry'));
      expect(searchEntries(_en, scope(controller), '   '), isEmpty);
    });
  });

  group('Settings search', () {
    testWidgets(
      'finds a setting inside a screen and opens it at that section',
      (tester) async {
        tester.view.physicalSize = const Size(390, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = await _controller();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('library-search')),
          'quiet hours',
        );
        await tester.pump();
        // The door and the thing itself.
        expect(_key('settings-category-background'), findsOneWidget);
        final result = _key('search-result-inside-notifications-quiet');
        expect(result, findsOneWidget);
        expect(
          find.descendant(of: result, matching: find.text('In Notifications')),
          findsOneWidget,
        );
        expect(_key('search-results-inside'), findsOneWidget);

        await tester.tap(result);
        await tester.pumpAndSettle();
        expect(_key('notifications-settings'), findsOneWidget);
        // On a 500 dp tall phone Quiet hours starts below the fold; the result
        // opens the screen already scrolled to it.
        final section = tester.getRect(_key('notifications-section-quiet'));
        expect(section.top, greaterThanOrEqualTo(0));
        expect(section.top, lessThan(500));
        expect(
          tester.getRect(_key('notifications-section-what')).top,
          lessThan(section.top),
        );
        expect(
          tester
              .state<ScrollableState>(
                find.descendant(
                  of: _key('notifications-settings'),
                  matching: find.byType(Scrollable),
                ),
              )
              .position
              .pixels,
          greaterThan(0),
        );
      },
    );

    testWidgets('language and theme open Appearance', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      for (final entry in {
        'language': 'search-result-inside-appearance-language',
        'theme': 'search-result-inside-appearance-theme',
      }.entries) {
        await tester.enterText(
          find.byKey(const Key('library-search')),
          entry.key,
        );
        await tester.pump();
        expect(_key(entry.value), findsOneWidget, reason: entry.key);
      }
      await tester.tap(_key('search-result-inside-appearance-theme'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
      expect(_key('theme-pack-${'opencode'}'), findsWidgets);
    });

    testWidgets('budget and always allowed are found', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('library-search'));
      await tester.enterText(search, 'budget');
      await tester.pump();
      expect(_key('search-result-inside-usage-budgets'), findsOneWidget);
      expect(_key('settings-category-usage'), findsOneWidget);
      await tester.enterText(search, 'always allowed');
      await tester.pump();
      expect(_key('saved-permissions-entry'), findsOneWidget);
    });

    testWidgets('a tab result asks the shell for that tab', (tester) async {
      final seen = <Intent>[];
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, shell: seen));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('library-search'));

      await tester.enterText(search, _en.shellTabInbox);
      await tester.pump();
      expect(_key('search-results-places'), findsOneWidget);
      await tester.tap(_key('search-result-tab-inbox'));
      await tester.pump();
      expect(seen.single, isA<SelectDestinationIntent>());
      expect((seen.single as SelectDestinationIntent).index, 1);

      seen.clear();
      await tester.enterText(search, _en.readerUiFiles);
      await tester.pump();
      await tester.tap(_key('search-result-project-files'));
      await tester.pump();
      expect((seen.single as OpenProjectToolIntent).tool, ProjectTool.files);
      // The hub never offers a way to itself.
      await tester.enterText(search, _en.librarySettingsTitle);
      await tester.pump();
      expect(_key('search-result-tab-settings'), findsNothing);
    });

    testWidgets('without a shell the tabs are not offered; tools still are', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('library-search'));
      await tester.enterText(search, _en.shellTabInbox);
      await tester.pump();
      expect(_key('search-result-tab-inbox'), findsNothing);
      await tester.enterText(search, 'terminal');
      await tester.pump();
      expect(_key('search-result-project-terminal'), findsOneWidget);
    });

    testWidgets('Codex: absent results stay absent in the hub', (tester) async {
      final controller = await _controller(
        capabilities: codexServerCapabilities,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, shell: []));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('library-search'));
      for (final query in ['terminal', 'skills', 'worktrees', 'files']) {
        await tester.enterText(search, query);
        await tester.pump();
        expect(_key('search-results-places'), findsNothing, reason: query);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'search-result-inside-capabilities',
                ),
          ),
          findsNothing,
          reason: query,
        );
      }
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('results fit 320 dp at 2.5x text in ${locale.languageCode}', (
        tester,
      ) async {
        const phone = Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        addTearDown(tester.view.reset);
        final controller = await _controller();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: phone,
              textScaler: TextScaler.linear(AppTheme.maxTextScale),
            ),
            child: _app(controller, locale: locale, shell: []),
          ),
        );
        await tester.pumpAndSettle();
        // One letter matches nearly the whole index: every kind of result
        // row is laid out.
        await tester.enterText(find.byKey(const Key('library-search')), 'e');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        for (final section in ['inside', 'places']) {
          await tester.scrollUntilVisible(
            _key('search-results-$section'),
            300,
            scrollable: scrollable,
          );
          expect(tester.takeException(), isNull, reason: section);
        }
        await tester.scrollUntilVisible(
          find.byKey(const Key('library-search-summary')),
          300,
          scrollable: scrollable,
        );
        expect(tester.takeException(), isNull);
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
          final box = tester.renderObject<RenderBox>(find.byWidget(tile));
          expect(box.size.width, lessThanOrEqualTo(phone.width));
        }
      });
    }
  });

  group('desktop command palette', () {
    testWidgets('finds a command by a keyword that is not shown', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCommandPalette(context, [
                DesktopCommand(
                  label: 'Notifications',
                  icon: Icons.notifications,
                  keywords: 'quiet hours battery',
                  onInvoke: () => opened++,
                ),
                DesktopCommand(
                  label: 'Appearance',
                  icon: Icons.palette,
                  keywords: 'theme language',
                  onInvoke: () {},
                ),
              ]),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: _key('desktop-command-palette'),
          matching: find.byType(TextField),
        ),
        'quiet',
      );
      await tester.pump();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Appearance'), findsNothing);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });
}
