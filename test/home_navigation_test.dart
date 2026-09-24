import 'package:flutter/material.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/activity_screen.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/widgets/glass_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ShellApi extends OpenCodeApi {
  _ShellApi() : super(baseUrl: 'http://localhost');

  @override
  Future<List<Session>> sessions() async => [];

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [];
}

class _LongFilesApi extends _ShellApi {
  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [
    for (var i = 0; i < 30; i++)
      FileNode(
        name: 'file-${i.toString().padLeft(2, '0')}.dart',
        path: 'file-${i.toString().padLeft(2, '0')}.dart',
        isDir: false,
      ),
  ];
}

class _NestedFilesApi extends _ShellApi {
  final paths = <String>[];

  @override
  Future<List<FileNode>> listFiles([String path = '']) async {
    paths.add(path);
    return switch (path) {
      '' => [FileNode(name: 'lib', path: 'lib', isDir: true)],
      'lib' => [FileNode(name: 'src', path: 'lib/src', isDir: true)],
      _ => [],
    };
  }

  @override
  Future<List<String>> findFile(String query) async => [];
}

class _ShellRepository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async => [];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => [];

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ShellProfileStore extends ProfileStore {
  final ServerProfile? profile;

  _ShellProfileStore({required super.prefs, this.profile});

  @override
  List<ServerProfile> get profiles => [?profile];

  @override
  String? get activeId => profile?.id;
}

Future<ConnectionController> _controller({String? profileName}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = _ShellProfileStore(
    prefs: prefs,
    profile: profileName == null
        ? null
        : ServerProfile(
            id: 'local',
            name: profileName,
            baseUrl: 'http://localhost:4096',
          ),
  );
  return ConnectionController(store)
    ..api = _ShellApi()
    ..repository = _ShellRepository()
    ..status = StreamStatus.connected;
}

Future<void> _pumpShell(
  WidgetTester tester,
  ConnectionController controller, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connProvider.overrideWithValue(controller)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final (width, locale) in [
    (320.0, const Locale('en')),
    (390.0, const Locale('en')),
    (320.0, const Locale('ar')),
  ]) {
    testWidgets('navigation stays inside its glass surface at $width and 2.5x '
        '(${locale.languageCode})', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(controller)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: locale,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.5)),
              child: child!,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dock = tester.getRect(find.byType(GlassSurface));
      final icon = tester.getRect(
        find.byIcon(AppIconography.workspaceSelected),
      );
      expect(icon.top, greaterThanOrEqualTo(dock.top + 4));
      final copy = lookupAppLocalizations(locale);
      final labels = [
        copy.shellTabWork,
        copy.shellTabInbox,
        copy.shellTabProject,
        copy.librarySettingsTitle,
      ];
      if (locale.languageCode == 'en') {
        expect(labels, ['Work', 'Inbox', 'Project', 'Settings']);
      } else {
        expect(labels, ['العمل', 'الوارد', 'المشروع', 'الإعدادات']);
        expect(
          Directionality.of(tester.element(find.byType(NavigationBar))),
          TextDirection.rtl,
        );
      }
      for (final label in labels) {
        final rect = tester.getRect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
            matching: find.byType(RichText),
          ),
        );
        final lines = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            )
            .map((box) => box.top)
            .toSet();
        expect(lines, hasLength(1), reason: '$label stays on one line');
        expect(rect.bottom, lessThanOrEqualTo(dock.bottom - 4));
        expect(rect.left, greaterThanOrEqualTo(dock.left));
        expect(rect.right, lessThanOrEqualTo(dock.right));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Files Back clears search, ascends folders, returns home, then guards exit',
    (tester) async {
      final api = _NestedFilesApi();
      final controller = await _controller()
        ..api = api;
      addTearDown(controller.dispose);
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpShell(tester, controller);
      await tester.tap(find.byIcon(AppIconography.files));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project-hub-files')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('lib'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('src'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.widgetWithText(ActionChip, 'Project root'))
            .label,
        contains('Project root'),
      );
      final search = find.byKey(const ValueKey('files-search-field'));
      await tester.enterText(search, 'needle');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(api.paths.last, 'lib/src');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.paths.last, 'lib');
      expect(exits, 0);
      expect(find.text('Press back again to exit'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.paths.last, '');
      await tester.tap(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsNothing);
      expect(exits, 0);
      expect(tester.widget<TextField>(search).focusNode?.hasFocus, isFalse);
      tester.view.resetViewInsets();
      await tester.pump();
      // At the root of Files, Back returns to the Project hub first.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('current-tab-title')))
            .data,
        'Project',
      );
      expect(
        find.byKey(const ValueKey('project-hub-files')).hitTestable(),
        findsOneWidget,
      );
      expect(search.hitTestable(), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('current-tab-title')))
            .data,
        'Work',
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(exits, 0);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits, 1);
    },
  );

  testWidgets('inactive Files tab does not consume Back', (tester) async {
    final api = _NestedFilesApi();
    final controller = await _controller()
      ..api = api;
    addTearDown(controller.dispose);
    await _pumpShell(tester, controller);
    await tester.tap(find.byIcon(AppIconography.files));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-hub-files')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lib'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIconography.settings));
    await tester.pumpAndSettle();
    final loads = api.paths.length;
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-tab-title'))).data,
      'Work',
    );
    expect(api.paths.length, loads);
  });

  testWidgets('switching destinations preserves Files search and folder', (
    tester,
  ) async {
    final api = _NestedFilesApi();
    final controller = await _controller()
      ..api = api;
    addTearDown(controller.dispose);
    await _pumpShell(tester, controller);
    await tester.tap(find.byIcon(AppIconography.files));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-hub-files')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lib'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('files-search-field'));
    await tester.enterText(search, 'needle');
    await tester.pump(const Duration(milliseconds: 400));
    final loads = api.paths.length;
    await tester.tap(find.byIcon(AppIconography.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIconography.files));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, 'needle');
    expect(api.paths.last, 'lib');
    expect(api.paths.length, loads);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inbox Back returns Work before offering exit', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpShell(tester, controller);
    await tester.tap(find.byIcon(AppIconography.activity));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-tab-title'))).data,
      'Work',
    );
    expect(find.text('Press back again to exit'), findsNothing);
  });

  testWidgets('reduced motion switches destinations without animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpShell(tester, controller, disableAnimations: true);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .animationDuration,
      Duration.zero,
    );
    await tester.tap(find.byIcon(AppIconography.settings));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-tab-title'))).data,
      'Settings',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'frosted dock preserves last file reachability and yields to keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final controller = await _controller()
        ..api = _LongFilesApi();
      addTearDown(controller.dispose);
      await _pumpShell(tester, controller);
      await tester.tap(find.byIcon(AppIconography.files));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project-hub-files')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
        isTrue,
      );
      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -2200));
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('project-file-file-29.dart'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      // End-of-list scrolling includes the dock inset, not merely the viewport.
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(GlassSurface)).top),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
        isFalse,
      );
      final search = find.byKey(const ValueKey('files-search-field'));
      expect(tester.getRect(search).bottom, lessThanOrEqualTo(544));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone shell uses product bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await _pumpShell(tester, controller);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(GlassSurface), findsOneWidget);
    final dock = tester.getRect(find.byType(GlassSurface));
    expect(dock.left, 16);
    expect(dock.right, 374);
    expect(dock.height, 72);
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final navigationContext = tester.element(find.byType(NavigationBar));
    for (final states in [
      <WidgetState>{},
      {WidgetState.selected},
    ]) {
      expect(
        navigation.labelTextStyle!.resolve(states)!.color,
        GlassSurface.foregroundColor(Theme.of(navigationContext)),
      );
      expect(
        NavigationBarTheme.of(
          navigationContext,
        ).iconTheme!.resolve(states)!.color,
        GlassSurface.foregroundColor(Theme.of(navigationContext)),
      );
    }
    for (final glyph in [
      AppIconography.workspaceSelected,
      AppIconography.files,
    ]) {
      final iconFinder = find.byIcon(glyph);
      expect(tester.widget<Icon>(iconFinder).color, isNull);
      expect(
        IconTheme.of(tester.element(iconFinder)).color,
        GlassSurface.foregroundColor(Theme.of(navigationContext)),
      );
    }
    final icon = tester.getRect(find.byIcon(AppIconography.workspaceSelected));
    expect(icon.top - dock.top, greaterThanOrEqualTo(8));
    final label = tester.getRect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Work'),
      ),
    );
    expect(dock.bottom - label.bottom, greaterThanOrEqualTo(4));

    expect(find.byType(NavigationRail), findsNothing);
    // UX plan 5.1: one tab per noun, in this order.
    final navigationLabels = tester
        .widgetList<NavigationDestination>(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(NavigationDestination),
          ),
        )
        .map((destination) => destination.label)
        .toList();
    expect(navigationLabels, ['Work', 'Inbox', 'Project', 'Settings']);
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Activity'), findsNothing);
    expect(find.text('Files'), findsNothing);
    expect(find.text('Terminal'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('More'), findsNothing);
    expect(find.text('API'), findsNothing);
    expect(find.text('Guide'), findsNothing);
  });

  testWidgets('one pending badge, on the Inbox destination', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await _pumpShell(tester, controller);
    expect(find.byType(Badge), findsNothing);

    controller.permissions = {
      'perm-1': PermissionRequest(
        id: 'perm-1',
        sessionID: 'session-1',
        permission: 'edit',
        patterns: const ['lib/main.dart'],
      ),
    };
    controller.notifyListeners();
    await tester.pump();

    // UX-P0-01: exactly one global badge, and the duplicate app-bar entry
    // points are gone.
    final badge = find.byKey(const ValueKey('activity-pending-badge'));
    expect(badge, findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: badge),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: badge,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is NavigationDestination && widget.label == 'Inbox',
        ),
      ),
      findsOneWidget,
    );

    // The badge counts everything waiting on the person, not just "some".
    controller.permissions = {
      for (final id in ['perm-1', 'perm-2', 'perm-3'])
        id: PermissionRequest(
          id: id,
          sessionID: 'session-1',
          permission: 'edit',
          patterns: const ['lib/main.dart'],
        ),
    };
    controller.notifyListeners();
    await tester.pump();
    expect(
      find.descendant(of: badge, matching: find.text('3')),
      findsOneWidget,
    );
    controller.permissions = {'perm-1': controller.permissions['perm-1']!};
    controller.notifyListeners();
    await tester.pump();
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
    expect(find.byTooltip('Mission Control'), findsNothing);
    expect(find.byTooltip('Pending requests'), findsNothing);
    // The model lives on the composer; the shell has no overflow menu left.
    expect(find.byTooltip('Model / agent'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      ),
      findsNothing,
    );
  });

  testWidgets('the Inbox tab shows cross-session sections', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await _pumpShell(tester, controller);
    await tester.tap(find.byIcon(AppIconography.activity));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-tab-title'))).data,
      'Inbox',
    );
    // An empty inbox reads as success, not as a missing feature.
    expect(find.text('All clear here'), findsWidgets);
  });

  group('cold start opens where the person is needed', () {
    PermissionRequest permission(String id) => PermissionRequest(
      id: id,
      sessionID: 'session-1',
      permission: 'edit',
      patterns: const ['lib/main.dart'],
    );

    String title(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('current-tab-title')))
        .data!;

    Future<void> pump(
      WidgetTester tester,
      ConnectionController controller, {
      int? initialTab,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(controller)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(initialTab: initialTab),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('nothing waiting: Work', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await pump(tester, controller);
      expect(title(tester), 'Work');
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('something waiting: Inbox, on the request itself', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.permissions = {'perm-1': permission('perm-1')};
      await pump(tester, controller);
      expect(title(tester), 'Inbox');
      expect(
        find.byKey(const ValueKey('activity-permission-perm-1')).hitTestable(),
        findsOneWidget,
      );
      // Back still leads to Work, then to the exit guard.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Work');
    });

    testWidgets('the first read of pending requests decides, once', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      // Connect starts this read before the shell mounts.
      controller.permissionsLoading = true;
      await pump(tester, controller);
      expect(title(tester), 'Work');

      controller
        ..permissions = {'perm-1': permission('perm-1')}
        ..permissionsLoading = false;
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Inbox');

      // Decided. Returning to Work and getting a second request only moves
      // the badge.
      await tester.tap(find.byIcon(AppIconography.workspace));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      controller.permissions = {
        'perm-1': permission('perm-1'),
        'perm-2': permission('perm-2'),
      };
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Work');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('activity-pending-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a read that finds nothing leaves Work, and a late request '
        'does not move the person', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller
        ..permissionsLoading = true
        ..questionsLoading = true;
      await pump(tester, controller);
      controller.permissionsLoading = false;
      controller.notifyListeners();
      await tester.pump();
      // Questions are still being read: not decided yet.
      controller.questionsLoading = false;
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Work');

      controller.permissions = {'perm-late': permission('perm-late')};
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Work');
      expect(
        find.byKey(const ValueKey('activity-pending-badge')),
        findsOneWidget,
      );
    });

    testWidgets('picking a tab during the read is final', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.permissionsLoading = true;
      await pump(tester, controller);
      await tester.tap(find.byIcon(AppIconography.settings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Settings');

      controller
        ..permissions = {'perm-1': permission('perm-1')}
        ..permissionsLoading = false;
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(title(tester), 'Settings');
    });

    testWidgets('an explicit destination is respected', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.permissions = {'perm-1': permission('perm-1')};
      await pump(tester, controller, initialTab: 0);
      expect(title(tester), 'Work');
      expect(
        find.byKey(const ValueKey('activity-pending-badge')),
        findsOneWidget,
      );
    });
  });

  testWidgets('Inbox order: waiting on you, then running, then finished', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.sessionsById = {
      'running': Session(id: 'running', title: 'Running conversation'),
      'finished': Session(
        id: 'finished',
        title: 'Finished conversation',
        time: SessionTime(created: 1, updated: 2, idle: 3),
      ),
    };
    controller.busySessions.add('running');
    controller.permissions = {
      for (final id in ['perm-old', 'perm-new'])
        id: PermissionRequest(
          id: id,
          sessionID: 'running',
          permission: 'edit',
          patterns: const ['lib/main.dart'],
        ),
    };
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ActivityScreen(controller: controller, embedded: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final order = [
      find.text('Needs attention'),
      find.byKey(const ValueKey('activity-permission-perm-old')),
      find.byKey(const ValueKey('activity-permission-perm-new')),
      find.text('Running'),
      find.byKey(const ValueKey('activity-running-running')),
      find.text('Completion digests'),
    ];
    for (final item in order) {
      expect(item, findsOneWidget);
    }
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i - 1]), lessThan(top(order[i])), reason: 'item $i');
    }
    // Finished work is listed under its heading once opened.
    await tester.tap(find.text('Completion digests'));
    await tester.pump();
    expect(find.text('Finished conversation'), findsOneWidget);
    expect(
      top(find.text('Finished conversation')),
      greaterThan(top(find.text('Completion digests'))),
    );
  });

  testWidgets('failed reconnect keeps the product shell and location visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(profileName: 'This device (Termux)')
      ..api = null
      ..repository = null
      ..status = StreamStatus.disconnected
      ..lastError = 'Endpoint is unavailable';
    addTearDown(controller.dispose);

    await _pumpShell(tester, controller);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey('connection-status-banner')),
      findsOneWidget,
    );
    expect(find.text('Connection lost'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('connection-status-banner')),
        matching: find.text('Try again'),
      ),
      findsOneWidget,
    );
    // The raw error and the secondary action live behind Details.
    await tester.tap(find.byKey(const ValueKey('connection-banner-details')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Endpoint is unavailable'), findsOneWidget);
    expect(find.text('Change server'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('recovery banner fits a 320dp phone with 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(profileName: 'This device (Termux)')
      ..api = null
      ..repository = null
      ..status = StreamStatus.disconnected
      ..lastError = 'Endpoint is unavailable';
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [connProvider.overrideWithValue(controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: const HomeScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('connection-status-banner')),
        matching: find.text('Try again'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('connection-banner-details')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('automatic SSE reconnect still offers a manual retry', (
    tester,
  ) async {
    final controller = await _controller(profileName: 'This device (Termux)')
      ..status = StreamStatus.reconnecting;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [connProvider.overrideWithValue(controller)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final retry = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Try again'),
    );
    expect(retry.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('connection-banner-details')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Change server'), findsOneWidget);
  });

  testWidgets('phone header separates long local server and workspace labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(profileName: 'This device (Termux)');
    addTearDown(controller.dispose);

    await _pumpShell(tester, controller);

    final profile = find.byKey(const ValueKey('server-profile-title'));
    final tab = find.byKey(const ValueKey('current-tab-title'));
    expect(profile, findsOneWidget);
    expect(tab, findsOneWidget);
    expect(tester.getRect(profile).bottom, lessThan(tester.getRect(tab).top));
    expect(
      tester.getSemantics(profile).label,
      contains('Server: This device (Termux)'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet shell switches to navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await _pumpShell(tester, controller);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final profile = tester.getRect(
      find.byKey(const ValueKey('server-profile-title')),
    );
    final tab = tester.getRect(find.byKey(const ValueKey('current-tab-title')));
    expect((profile.center.dy - tab.center.dy).abs(), lessThan(2));
  });
}
