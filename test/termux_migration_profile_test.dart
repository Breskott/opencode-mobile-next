import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/migration/migration_profile.dart';
import 'package:opencode_mobile/domain/termux_migration.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/termux_channel_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryProfileStore store;
  late ServerProfile source;
  late ServerProfile destination;
  late TermuxMigrationProfileSwitcher switcher;
  var connected = false;
  var starts = 0;
  var rejectConnect = false;
  var cancelAfterStart = false;
  var wanted = true;
  var secretFailure = false;
  var changeSelectionDuringStart = false;
  final connections = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = ServerProfile(
      id: 'termux',
      name: 'Termux',
      baseUrl: TermuxBridge.managedServerUrl,
      flavor: ServerFlavor.v2,
    );
    destination = ServerProfile(
      id: 'builtin',
      name: 'This phone',
      baseUrl: BuiltinLinux.serverUrl,
      flavor: ServerFlavor.v2,
    );
    store = MemoryProfileStore(
      prefs: await SharedPreferences.getInstance(),
      saved: [source],
    );
    await store.setActiveId(source.id);
    connected = false;
    starts = 0;
    rejectConnect = false;
    cancelAfterStart = false;
    wanted = true;
    secretFailure = false;
    changeSelectionDuringStart = false;
    connections.clear();
    switcher = TermuxMigrationProfileSwitcher.withCallbacks(
      store: store,
      ensureProfile: (flavor) async {
        expect(flavor, source.flavor);
        await store.upsert(destination);
        return destination;
      },
      start: (profile, stillWanted) async {
        starts++;
        if (changeSelectionDuringStart) await store.setActiveId('other');
        if (secretFailure) throw StateError('provider-token-do-not-expose');
        if (cancelAfterStart) wanted = false;
        return stillWanted();
      },
      connect: (profile) async {
        connections.add(profile.id);
        await store.setActiveId(profile.id);
        connected = !rejectConnect || profile.id == source.id;
      },
      isConnectedTo: (profile) => connected && store.activeId == profile.id,
      selectedProfileId: () => store.activeId,
    );
  });

  Future<String> run({Map<String, String> paths = const {}}) =>
      switcher.switchProfile(
        sourceProfileId: source.id,
        stillWanted: () => wanted,
        verifiedProjectPaths: paths,
      );

  Matcher failure(TermuxMigrationFailure code) =>
      isA<TermuxMigrationException>().having(
        (error) => error.code,
        'code',
        code,
      );

  test(
    'switch and repeat retain source and only map verified project location',
    () async {
      await store.setLocation(
        source.id,
        directory: '/root/projects/repo/src',
        workspace: 'old-workspace',
      );
      await store.prefs.setString(
        'oc.sessionPins.termux',
        '{"old": ["session"]}',
      );
      final sourcePins = store.prefs.getString('oc.sessionPins.termux');
      for (var repeat = 0; repeat < 2; repeat++) {
        expect(
          await run(
            paths: {'/root/projects/repo': '/root/projects/import/repo'},
          ),
          destination.id,
        );
      }
      expect(store.profiles.length, 2);
      expect(store.profiles.first, same(source));
      expect(store.locationFor(source.id)?.workspace, 'old-workspace');
      expect(
        store.locationFor(destination.id)?.directory,
        '/root/projects/import/repo/src',
      );
      expect(store.locationFor(destination.id)?.workspace, isNull);
      expect(store.prefs.getString('oc.sessionPins.termux'), sourcePins);
      expect(store.prefs.containsKey('oc.sessionPins.builtin'), isFalse);
      expect(starts, 2);
    },
  );

  test(
    'path matching respects boundaries and rejects destination traversal',
    () async {
      await store.setLocation(
        source.id,
        directory: '/root/projects/repository',
      );
      await run(paths: {'/root/projects/repo': '/root/projects/import/repo'});
      expect(store.locationFor(destination.id), isNull);
      await expectLater(
        run(paths: {'/root/projects/repo': '/root/projects/../secret'}),
        throwsA(failure(TermuxMigrationFailure.invalidSelection)),
      );
    },
  );

  test(
    'failed connect restores source selection and retains destination for retry',
    () async {
      rejectConnect = true;
      await expectLater(
        run(),
        throwsA(failure(TermuxMigrationFailure.profileSwitch)),
      );
      expect(connections, [destination.id, source.id]);
      expect(store.activeId, source.id);
      expect(store.profiles.length, 2);
    },
  );

  test('cancellation before start leaves profiles unchanged', () async {
    wanted = false;
    await expectLater(
      run(),
      throwsA(failure(TermuxMigrationFailure.cancelled)),
    );
    expect(starts, 0);
    expect(store.profiles, [source]);
  });

  test('cancellation during start never selects destination', () async {
    cancelAfterStart = true;
    await expectLater(
      run(),
      throwsA(failure(TermuxMigrationFailure.cancelled)),
    );
    expect(connections, isEmpty);
    expect(store.activeId, source.id);
  });

  test(
    'sensitive underlying exception is replaced by a fixed failure code',
    () async {
      secretFailure = true;
      try {
        await run();
        fail('Expected a switch failure');
      } on TermuxMigrationException catch (error) {
        expect(error.code, TermuxMigrationFailure.profileSwitch);
        expect(
          error.toString(),
          isNot(contains('provider-token-do-not-expose')),
        );
      }
      expect(store.activeId, source.id);
    },
  );

  test('a user selection during start wins over migration', () async {
    changeSelectionDuringStart = true;
    await expectLater(
      run(),
      throwsA(failure(TermuxMigrationFailure.profileSwitch)),
    );
    expect(connections, isEmpty);
    expect(store.activeId, 'other');
  });

  test('remote source is rejected before creating a destination', () async {
    source.baseUrl = 'https://example.com';
    await expectLater(
      run(),
      throwsA(failure(TermuxMigrationFailure.invalidSelection)),
    );
    expect(starts, 0);
    expect(store.profiles, [source]);
  });
}
