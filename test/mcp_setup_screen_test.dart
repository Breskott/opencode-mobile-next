import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/diagnostics/app_diagnostics.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart' show KitButton;
import 'package:opencode_mobile/ui/screens/mcp_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/api2/gateway_mappers.dart';

import '../tool/capture/fixtures.dart'
    show capturePng, captureTheme, loadCaptureFonts;

class _McpRepository implements ProductRepository {
  McpServerDraft? addedDraft;
  McpConfigScope? addedScope;
  int addCalls = 0;
  Object? addError;

  @override
  Future<void> addMcpServer(
    McpServerDraft draft, {
    required McpConfigScope scope,
  }) async {
    addCalls += 1;
    if (addError case final error?) throw error;
    addedDraft = draft;
    addedScope = scope;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _McpController extends ConnectionController {
  _McpController(super.store, this.actionRepository);

  final ProductRepository actionRepository;
  int reloadCalls = 0;
  Object? reloadError;
  bool reloadReturnsDisconnected = false;
  Completer<ProductRepository?>? wake;
  ServerCapabilities serverCapabilities = ServerCapabilities.allV1;
  ServerProfile? activeProfile;

  @override
  ServerCapabilities get capabilities => serverCapabilities;

  void moveTo(String value) {
    directory = value;
    locationRevision++;
    notifyListeners();
  }

  @override
  ServerProfile? get profile => activeProfile;

  void switchProfile(String id) {
    activeProfile = ServerProfile(
      id: id,
      name: id,
      baseUrl: 'https://$id.example.com',
    );
    notifyListeners();
  }

  @override
  Future<ProductRepository?> prepareActionRepository() async =>
      wake == null ? actionRepository : await wake!.future;

  @override
  Future<void> reloadAfterConfigurationChange() async {
    reloadCalls += 1;
    if (reloadError case final error?) throw error;
    if (reloadReturnsDisconnected) {
      lastError = 'Endpoint is unavailable';
      notifyListeners();
    }
  }
}

class _SetupHost extends StatelessWidget {
  const _SetupHost({required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => McpSetupScreen(controller: controller),
          ),
        ),
        child: const Text('Open setup'),
      ),
    ),
  );
}

Future<_McpController> _controller(
  ProductRepository repository, {
  String? directory,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return _McpController(ProfileStore(prefs: preferences), repository)
    ..directory = directory;
}

Future<void> _open(
  WidgetTester tester,
  ConnectionController controller, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: _SetupHost(controller: controller),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open setup'));
  await tester.pumpAndSettle();
}

/// Brings the field with [key] on screen. It moves the form's own scroll
/// position rather than dragging, so a multiline field under the drag point
/// cannot swallow the gesture, and it looks both ways (a field may sit
/// above the current position).
Future<void> _reveal(WidgetTester tester, Key key) async {
  // A focused field keeps scrolling its caret back into view; let go first.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final target = find.byKey(key);
  final position = tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('mcp-setup-form')),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;
  for (final step in const [150.0, -150.0]) {
    while (target.evaluate().isEmpty) {
      final next = (position.pixels + step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) break;
      position.jumpTo(next);
      await tester.pump();
    }
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.3);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('What is MCP? explains the term in a bubble, in the app\'s '
      'copy (slice-P3.1: the info-label sheet is gone)', (tester) async {
    final repository = _McpRepository();
    final controller = await _controller(repository)
      ..serverCapabilities = api2ServerCapabilities;
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await tester.tap(find.byKey(const ValueKey('mcp-glossary')));
    await tester.pumpAndSettle();
    final bubble = find.byKey(const ValueKey('kit-term-bubble'));
    expect(bubble, findsOneWidget);
    expect(
      find.descendant(
        of: bubble,
        matching: find.textContaining('every conversation can use them'),
      ),
      findsOneWidget,
    );
    expect(find.text('Got it'), findsNothing);
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    expect(bubble, findsNothing);
  });

  testWidgets('v2 shows its location and adds without configuration reload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _McpRepository();
    final controller = await _controller(repository, directory: '/work/mobile')
      ..serverCapabilities = api2ServerCapabilities
      ..workspace = 'workspace-mobile';
    addTearDown(controller.dispose);
    final preview = Platform.environment['OC_MCP_CAPTURE'];
    if (preview != null) await loadCaptureFonts();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: true),
          home: _SetupHost(controller: controller),
        ),
      ),
    );
    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mcp-scope')), findsNothing);
    expect(find.text('All projects'), findsNothing);
    expect(find.text('Until server restart'), findsOneWidget);
    expect(
      find.textContaining('Cloud environment: workspace-mobile'),
      findsOneWidget,
    );
    if (preview != null) {
      File(
        preview,
      ).writeAsBytesSync(await capturePng(tester, boundary, pixelRatio: 1));
    }
    await _reveal(tester, const ValueKey('mcp-name'));
    await tester.enterText(find.byKey(const ValueKey('mcp-name')), 'docs');
    await _reveal(tester, const ValueKey('mcp-url'));
    await tester.enterText(
      find.byKey(const ValueKey('mcp-url')),
      'https://mcp.example.com',
    );
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pumpAndSettle();
    expect(repository.addedScope, McpConfigScope.runtimeLocation);
    expect(controller.reloadCalls, 0);
    expect(find.byType(McpSetupScreen), findsNothing);
  });

  testWidgets('connection change during wake retains draft without writing', (
    tester,
  ) async {
    final repository = _McpRepository();
    final controller = await _controller(repository, directory: '/work/mobile')
      ..serverCapabilities = api2ServerCapabilities
      ..wake = Completer<ProductRepository?>();
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await tester.enterText(find.byKey(const ValueKey('mcp-name')), 'my-draft');
    await _reveal(tester, const ValueKey('mcp-url'));
    await tester.enterText(
      find.byKey(const ValueKey('mcp-url')),
      'https://mcp.example.com',
    );
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pump();
    controller.moveTo('/work/elsewhere');
    controller.wake!.complete(repository);
    await tester.pumpAndSettle();
    expect(repository.addedDraft, isNull);
    expect(controller.reloadCalls, 0);
    expect(find.byType(McpSetupScreen), findsOneWidget);
    expect(
      tester
          .widget<KitButton>(find.byKey(const ValueKey('mcp-save')))
          .onPressed,
      isNull,
    );
    await _reveal(tester, const ValueKey('mcp-name'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('mcp-name')))
          .controller!
          .text,
      'my-draft',
    );
  });

  testWidgets('saves a project remote MCP with exact advanced fields', (
    tester,
  ) async {
    final repository = _McpRepository();
    final controller = await _controller(repository, directory: '/work/mobile');
    addTearDown(controller.dispose);
    await _open(tester, controller);
    expect(find.byKey(const ValueKey('mcp-scope')), findsOneWidget);
    expect(find.text('This project'), findsOneWidget);
    expect(find.text('All projects'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('mcp-name')),
      'remote-docs',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mcp-url')),
      'https://mcp.example.com/rpc',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mcp-header-key-0')),
      'Authorization',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mcp-header-value-0')),
      'Bearer test-token',
    );
    // The rarer settings are folded under Advanced (map proposal).
    await _reveal(tester, const ValueKey('mcp-advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await _reveal(tester, const ValueKey('mcp-oauth-detection'));
    await tester.tap(find.byKey(const ValueKey('mcp-oauth-detection')));
    await _reveal(tester, const ValueKey('mcp-timeout'));
    await tester.enterText(find.byKey(const ValueKey('mcp-timeout')), '12000');
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pumpAndSettle();

    expect(repository.addedScope, McpConfigScope.project);
    expect(repository.addedDraft?.normalizedName, 'remote-docs');
    expect(repository.addedDraft?.kind, McpServerKind.remote);
    expect(repository.addedDraft?.url, 'https://mcp.example.com/rpc');
    expect(repository.addedDraft?.headers, {
      'Authorization': 'Bearer test-token',
    });
    expect(repository.addedDraft?.detectOAuth, isFalse);
    expect(repository.addedDraft?.timeoutMs, 12000);
    expect(controller.reloadCalls, 1);
    expect(find.byType(McpSetupScreen), findsNothing);
  });

  testWidgets('saves a global local MCP on a compact large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _McpRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _open(tester, controller, textScale: 2);

    await tester.tap(find.text('Local command'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mcp-name')),
      'local-tools',
    );
    await _reveal(tester, const ValueKey('mcp-command'));
    await tester.enterText(
      find.byKey(const ValueKey('mcp-command')),
      'npx\n-y\n@example/mcp-server',
    );
    await _reveal(tester, const ValueKey('mcp-advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await _reveal(tester, const ValueKey('mcp-cwd'));
    await tester.enterText(
      find.byKey(const ValueKey('mcp-cwd')),
      '/work/mobile',
    );
    await _reveal(tester, const ValueKey('mcp-environment'));
    await tester.enterText(
      find.byKey(const ValueKey('mcp-environment')),
      'LOG_LEVEL=warn',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pumpAndSettle();

    expect(repository.addedScope, McpConfigScope.global);
    expect(repository.addedDraft?.kind, McpServerKind.local);
    expect(repository.addedDraft?.command, [
      'npx',
      '-y',
      '@example/mcp-server',
    ]);
    expect(repository.addedDraft?.cwd, '/work/mobile');
    expect(repository.addedDraft?.environment, {'LOG_LEVEL': 'warn'});
    expect(controller.reloadCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps validation and server errors inline without saving', (
    tester,
  ) async {
    final repository = _McpRepository();
    final controller = await _controller(repository);
    addTearDown(controller.dispose);
    await _open(tester, controller);

    await tester.enterText(find.byKey(const ValueKey('mcp-name')), 'duplicate');
    await tester.enterText(
      find.byKey(const ValueKey('mcp-url')),
      'https://mcp.example.com',
    );
    // A value with no header name: the same "line, use KEY=VALUE" error the
    // old single free-text field gave for a line with no '='.
    await tester.enterText(
      find.byKey(const ValueKey('mcp-header-value-0')),
      'without a name',
    );
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pump();

    expect(find.textContaining('Use KEY=VALUE'), findsOneWidget);
    expect(repository.addedDraft, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('mcp-header-key-0')),
      'Authorization',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mcp-header-value-0')),
      'token',
    );
    repository.addError = const ProductException(
      'An MCP server named "duplicate" already exists',
    );
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pumpAndSettle();

    // The failure sits on the status line; the draft stays.
    expect(find.text("Couldn't add the MCP server"), findsOneWidget);
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(controller.reloadCalls, 0);
    expect(find.byType(McpSetupScreen), findsOneWidget);
  });

  testWidgets('retries reconnect without duplicating a saved MCP server', (
    tester,
  ) async {
    final repository = _McpRepository();
    final controller = await _controller(repository)
      ..reloadError = const ProductException('Endpoint is unavailable');
    addTearDown(controller.dispose);
    await _open(tester, controller);

    await tester.enterText(find.byKey(const ValueKey('mcp-name')), 'docs');
    await tester.enterText(
      find.byKey(const ValueKey('mcp-url')),
      'https://mcp.example.com',
    );
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pumpAndSettle();

    expect(repository.addedDraft?.normalizedName, 'docs');
    expect(repository.addCalls, 1);
    expect(controller.reloadCalls, 1);
    // The saved state replaces the form: what happened and what is left.
    expect(find.text('Saved docs on this server'), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-saved-status')), findsOneWidget);
    expect(find.textContaining("didn't reconnect"), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-retry-reconnect')), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-name')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mcp-retry-reconnect')));
    await tester.pumpAndSettle();
    expect(repository.addCalls, 1);
    expect(controller.reloadCalls, 2);
    expect(find.byType(McpSetupScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-retry-reconnect')), findsOneWidget);

    controller.reloadError = null;
    controller.reloadReturnsDisconnected = true;
    await tester.tap(find.byKey(const ValueKey('mcp-retry-reconnect')));
    await tester.pumpAndSettle();
    expect(repository.addCalls, 1);
    expect(controller.reloadCalls, 3);
    expect(find.byType(McpSetupScreen), findsOneWidget);
    expect(find.textContaining('still disconnected'), findsOneWidget);

    controller.reloadReturnsDisconnected = false;
    controller.lastError = null;
    await tester.tap(find.byKey(const ValueKey('mcp-retry-reconnect')));
    await tester.pumpAndSettle();
    expect(repository.addCalls, 1);
    expect(controller.reloadCalls, 4);
    expect(find.byType(McpSetupScreen), findsNothing);
  });

  testWidgets('keeps reconnect disabled after the saved profile changes', (
    tester,
  ) async {
    final repository = _McpRepository();
    final controller = await _controller(repository)
      ..reloadError = const ProductException('Endpoint is unavailable');
    addTearDown(controller.dispose);
    await _open(tester, controller);

    await tester.enterText(find.byKey(const ValueKey('mcp-name')), 'docs');
    await tester.enterText(
      find.byKey(const ValueKey('mcp-url')),
      'https://mcp.example.com',
    );
    await tester.tap(find.byKey(const ValueKey('mcp-save')));
    await tester.pumpAndSettle();

    controller.switchProfile('other-server');
    await tester.pump();
    final retry = tester.widget<KitButton>(
      find.byKey(const ValueKey('mcp-retry-reconnect')),
    );
    expect(retry.onPressed, isNull);
    expect(repository.addCalls, 1);
    expect(controller.reloadCalls, 1);

    await tester.tap(find.byKey(const ValueKey('mcp-retry-reconnect')));
    await tester.pumpAndSettle();
    expect(repository.addCalls, 1);
    expect(controller.reloadCalls, 1);
    expect(find.byKey(const ValueKey('mcp-saved-status')), findsOneWidget);
  });

  group('P0.1: header values are secrets', () {
    bool obscured(WidgetTester tester, String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
          ),
        )
        .obscureText;

    testWidgets(
      'masks the value, key stays visible, reveal on press, never prefilled',
      (tester) async {
        final repository = _McpRepository();
        final controller = await _controller(repository);
        addTearDown(controller.dispose);
        await _open(tester, controller);

        // Never prefilled: the Add form always starts with one empty row.
        // There is no edit-existing-server entry point in this app (only
        // McpSetupScreen is Add-only; see docs/qa/p0-secure-settings-
        // 2026-09-26/README.md), so nothing saved could be shown here.
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('mcp-header-key-0')),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('mcp-header-value-0')),
              )
              .controller!
              .text,
          isEmpty,
        );

        // Fill the fields above the headers block first: scrolling down to
        // reach the reveal toggle can carry fields far above it out of the
        // list's cache extent.
        await tester.enterText(find.byKey(const ValueKey('mcp-name')), 'docs');
        await tester.enterText(
          find.byKey(const ValueKey('mcp-url')),
          'https://mcp.example.com',
        );

        const fakeToken = 'sekret-abc123XYZ';
        await tester.enterText(
          find.byKey(const ValueKey('mcp-header-key-0')),
          'Authorization',
        );
        await tester.enterText(
          find.byKey(const ValueKey('mcp-header-value-0')),
          'Bearer $fakeToken',
        );

        // Masked by default.
        expect(obscured(tester, 'mcp-header-value-0'), isTrue);

        // Reveal on press, and hide it again — the point of the toggle,
        // not something the value should stay stuck at.
        await _reveal(tester, const ValueKey('mcp-header-reveal-0'));
        await tester.tap(find.byKey(const ValueKey('mcp-header-reveal-0')));
        await tester.pump();
        expect(obscured(tester, 'mcp-header-value-0'), isFalse);
        await tester.tap(find.byKey(const ValueKey('mcp-header-reveal-0')));
        await tester.pump();
        expect(obscured(tester, 'mcp-header-value-0'), isTrue);

        // Every rendered string except the still-mounted, editable input
        // itself (which necessarily holds what the person typed, obscured
        // or not — that is a live field, not a leak).
        List<String> renderedTexts() => tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .toList();

        // The save (error) path: the fake token must not surface anywhere.
        repository.addError = const ProductException(
          'An MCP server named "docs" already exists',
        );
        await tester.tap(find.byKey(const ValueKey('mcp-save')));
        await tester.pumpAndSettle();
        expect(find.text("Couldn't add the MCP server"), findsOneWidget);
        for (final text in renderedTexts()) {
          expect(text, isNot(contains(fakeToken)));
        }

        // The save (success) path: still nowhere, and the real value did
        // reach the draft that is sent to the server.
        repository.addError = null;
        await tester.tap(find.byKey(const ValueKey('mcp-save')));
        await tester.pumpAndSettle();
        for (final text in renderedTexts()) {
          expect(text, isNot(contains(fakeToken)));
        }
        expect(repository.addedDraft?.headers, {
          'Authorization': 'Bearer $fakeToken',
        });
      },
    );

    testWidgets('adds and removes header rows', (tester) async {
      final repository = _McpRepository();
      final controller = await _controller(repository);
      addTearDown(controller.dispose);
      await _open(tester, controller);

      expect(find.byKey(const ValueKey('mcp-header-key-1')), findsNothing);
      // A lone row has no remove button; nothing to remove down to.
      expect(find.byKey(const ValueKey('mcp-header-remove-0')), findsNothing);

      await _reveal(tester, const ValueKey('mcp-header-add'));
      await tester.tap(find.byKey(const ValueKey('mcp-header-add')));
      await tester.pump();
      expect(find.byKey(const ValueKey('mcp-header-key-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mcp-header-remove-1')), findsOneWidget);

      await _reveal(tester, const ValueKey('mcp-header-remove-1'));
      await tester.tap(find.byKey(const ValueKey('mcp-header-remove-1')));
      await tester.pump();
      expect(find.byKey(const ValueKey('mcp-header-key-1')), findsNothing);
      expect(find.byKey(const ValueKey('mcp-header-remove-0')), findsNothing);
    });
  });

  test(
    'diagnostics also redact an Authorization=Bearer header value (P0.1)',
    () {
      final diagnostics = AppDiagnosticsController();
      addTearDown(diagnostics.dispose);
      const fakeToken = 'p0-1-bearer-abcXYZ';
      diagnostics.record(
        StateError('MCP save failed: Authorization=Bearer $fakeToken'),
        StackTrace.fromString(
          'at _save (lib/ui/screens/mcp_setup_screen.dart:1:1)',
        ),
        source: 'mcp',
      );
      expect(diagnostics.reportText(), isNot(contains(fakeToken)));
    },
  );
}
