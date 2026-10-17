// A switch gives this phone a different saved server (one per runtime). The
// AI Team that was on for the old one must follow, or "AI Team keeps
// working" would be false.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/state/move_to_opencode2.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store extends ProfileStore {
  _Store(SharedPreferences prefs, this.saved) : super(prefs: prefs);
  final List<ServerProfile> saved;
  @override
  List<ServerProfile> get profiles => List.unmodifiable(saved);
  @override
  Future<void> upsert(ServerProfile profile) async {
    saved
      ..removeWhere((p) => p.id == profile.id)
      ..add(profile);
  }
}

ServerProfile _p(String id, ServerFlavor flavor, {String url = ''}) =>
    ServerProfile(
      id: id,
      name: id,
      baseUrl: url.isEmpty ? BuiltinLinux.serverUrl : url,
      flavor: flavor,
    );

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  bool phoneOwn(ServerProfile p) => BuiltinLinux.managesServerUrl(p.baseUrl);

  test('the team and its engine credential move to the new server', () async {
    final old = _p('one', ServerFlavor.v1)
      ..orchestration = BuiltinTeam.config()
      ..teamEngineAuth = 'engine-secret';
    final next = _p('two', ServerFlavor.v2);
    final store = _Store(prefs, [old, next]);
    await teamFollowsRuntime(store, next, sameHost: phoneOwn);
    expect(BuiltinTeam.isBuiltinConfig(next.orchestration), isTrue);
    expect(next.teamEngineAuth, 'engine-secret');
    expect(old.orchestration, isNull);
    expect(old.teamEngineAuth, isEmpty);
  });

  test(
    'a target with its own team keeps it; a remote server is untouched',
    () async {
      final remote = _p('far', ServerFlavor.v1, url: 'https://box.example.com')
        ..orchestration = BuiltinTeam.config();
      final next = _p('two', ServerFlavor.v2);
      final store = _Store(prefs, [remote, next]);
      await teamFollowsRuntime(store, next, sameHost: phoneOwn);
      expect(next.orchestration, isNull);
      expect(remote.orchestration, isNotNull);

      final own = _p('three', ServerFlavor.v2)
        ..orchestration = BuiltinTeam.config();
      final old = _p('one', ServerFlavor.v1)
        ..orchestration = BuiltinTeam.config();
      await teamFollowsRuntime(
        _Store(prefs, [old, own]),
        own,
        sameHost: phoneOwn,
      );
      expect(old.orchestration, isNotNull);
    },
  );
}
