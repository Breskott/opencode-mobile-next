// The "This phone" page (ThisPhoneScreen) for OpenCode running inside the
// app, over a stood-in Linux. Nothing here starts a process.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/domain/opencode_history_copy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';

/// The in-app Linux, stood in for: installed, with the server running.
class _FakeLinux extends BuiltinLinux {
  _FakeLinux({this.recovery = false, this.separateHistory = false});
  final bool recovery;
  final bool separateHistory;

  @override
  Future<BuiltinLinuxStatus> status() async => BuiltinLinuxStatus(
    installed: true,
    phase: BuiltinLinuxPhase.ready,
    serverRunning: !recovery,
    serverPort: BuiltinLinux.serverPort,
    bytesUsed: 734003200,
  );

  @override
  Future<BuiltinLinuxRunResult> run(
    String script, {
    Duration timeout = const Duration(minutes: 2),
  }) async =>
      separateHistory && script.contains(openCode1HistorySwitchCheckScript)
      ? const BuiltinLinuxRunResult(
          exitCode: 74,
          output: openCode1HistorySwitchBlockedMessage,
        )
      : const BuiltinLinuxRunResult(exitCode: 0, output: '1.18.29\n');

  @override
  Future<void> startServer(
    String script, {
    int port = 4097,
    BuiltinServerRestoreRecipe? restoreRecipe,
  }) async {
    if (recovery) {
      throw const BuiltinLinuxException(
        'The app cannot safely identify previous work.',
        code: 'runtime_ownership_unknown',
      );
    }
  }

  @override
  Future<void> stopServer() async {}

  @override
  Future<String> serverLog({int tailBytes = 32768}) async => '';

  @override
  Future<BuiltinProjectStorage> projectStorage() async =>
      const BuiltinProjectStorage(
        runtimeBytes: 734003200,
        projectsBytes: 52428800,
        measuredAtMilliseconds: 0,
      );
}

Widget _scene({bool recovery = false, bool separateHistory = false}) =>
    FakeAppScene<FakeApp>(
      autoTap: recovery ? 'this-phone-start' : null,
      platform: FakePlatform.android,
      create: () => FakeApp.create(
        profiles: [
          FakeProfile(
            'phone',
            'This phone, built-in (OpenCode 1)',
            url: BuiltinLinux.serverUrl,
          ),
        ],
      ),
      builder: (context, app) {
        app.store.profiles.first.password = 'catalog-only-password';
        final linux = _FakeLinux(
          recovery: recovery,
          separateHistory: separateHistory,
        );
        return ProviderScope(
          overrides: [
            bootstrapProvider.overrideWithValue(AppBootstrap(app.store)),
            connProvider.overrideWithValue(app.connection),
            builtinLinuxProvider.overrideWithValue(linux),
          ],
          child: const ThisPhoneScreen(kind: PhoneHostKind.inApp),
        );
      },
    );

CatalogComponent thisPhoneScreen() => catalogComponent(
  area: 'Servers',
  screen: 'ThisPhoneScreen',
  name: 'This phone',
  useCases: [
    WidgetbookUseCase(
      name: 'OpenCode running in the app',
      builder: (_) => _scene(),
    ),
    WidgetbookUseCase(
      name: 'OpenCode 2 has separate conversations',
      builder: (_) => _scene(separateHistory: true),
    ),
    WidgetbookUseCase(
      name: 'Previous work needs Android recovery',
      builder: (_) => _scene(recovery: true),
    ),
  ],
);
