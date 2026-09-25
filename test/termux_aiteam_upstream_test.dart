// Issue #87, Termux path: turning the AI Team on must not depend on the
// never-published `aiteam-assets-1` release. What the app hands to Termux
// when a person taps Set up must name the upstream Linux builds the in-app
// Ubuntu installs (AiTeamPins), with their pinned checksums.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/aiteam_scripts.dart';
import 'package:opencode_mobile/termux/team_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Set up dispatches the upstream builds, never aiteam-assets-1',
    () async {
      final scripts = <String>[];
      Future<String> runner(String script, {Duration? timeout}) async {
        scripts.add(script);
        if (script.contains(r'exec bash "$AITEAM" status')) {
          return '{"phase":"installed","busy":false,"installed":true}';
        }
        return 'aiteam-started:7\n';
      }

      final runtime = TermuxTeamRuntime(
        runner: runner,
        archProbe: () async => 'aarch64',
        pollInterval: const Duration(milliseconds: 1),
      );
      expect(await runtime.supportsAiTeam, isTrue);
      await runtime.install();
      final dispatched = scripts.first;
      expect(dispatched, isNot(contains('aiteam-assets-1')));
      expect(dispatched, isNot(contains('opencode-mobile-next/releases')));
      for (final download in AiTeamPins.arm64) {
        expect(dispatched, contains(download.url), reason: download.tool);
        expect(dispatched, contains(download.sha256), reason: download.tool);
      }
    },
  );
}
