import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/local_agent_server.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/widgets/termux_running_server_entry.dart';

ServerProfile _paseo(String id, String url, {String name = 'This phone'}) =>
    ServerProfile(
      id: id,
      name: name,
      baseUrl: url,
      backend: ServerBackend.paseo,
    );

void main() {
  test('every loopback name of the daemon endpoint is the same server', () {
    for (final url in [
      'ws://127.0.0.1:6767',
      'ws://localhost:6767',
      'ws://[::1]:6767',
    ]) {
      expect(isLocalAgentProfile(_paseo('a', url)), isTrue, reason: url);
    }
  });

  test('another port, scheme, host or backend is a different server', () {
    expect(isLocalAgentProfile(_paseo('a', 'ws://localhost:6768')), isFalse);
    expect(isLocalAgentProfile(_paseo('a', 'wss://localhost:6767')), isFalse);
    expect(isLocalAgentProfile(_paseo('a', 'ws://100.64.0.2:6767')), isFalse);
    expect(
      isLocalAgentProfile(
        ServerProfile(id: 'a', name: 'x', baseUrl: 'http://localhost:6767'),
      ),
      isFalse,
    );
  });

  test('the name never decides, the endpoint does', () {
    expect(
      isLocalAgentProfile(
        _paseo('a', 'ws://100.64.0.2:6767', name: 'Claude Code on this phone'),
      ),
      isFalse,
    );
  });

  test('with two saved for the endpoint, the connected one is the row', () {
    final profiles = [
      _paseo('stale', 'ws://127.0.0.1:6767', name: 'Claude Code on this phone'),
      _paseo('live', 'ws://localhost:6767'),
    ];
    expect(savedLocalAgentProfile(profiles)?.id, 'stale');
    expect(savedLocalAgentProfile(profiles, preferID: 'live')?.id, 'live');
    expect(savedLocalAgentProfile(profiles, preferID: 'other')?.id, 'stale');
  });

  test('only one profile per endpoint folds into the phone row', () {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    addTearDown(() => debugPlatformCapabilities = null);
    final first = _paseo('first', 'ws://127.0.0.1:6767');
    final second = _paseo('second', 'ws://localhost:6767');
    final all = [first, second];
    bool folded(ServerProfile p, {String? live}) =>
        shownAsPhoneRow(p, among: all, preferID: live);
    // Not connected: the first folds, the other stays a normal row.
    expect(folded(first), isTrue);
    expect(folded(second), isFalse);
    // Connected: the connected one folds, the first becomes a normal row.
    expect(folded(second, live: 'second'), isTrue);
    expect(folded(first, live: 'second'), isFalse);
  });
}
