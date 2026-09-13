import 'dart:convert';

import 'support/complete_message_history.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/background/attention_tile_snapshot.dart';
import 'package:opencode_mobile/background/pinned_session_shortcuts.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The controller keeps two launch surfaces in step with connection truth:
/// the launcher's pinned-session shortcuts (published over `oc/shortcut`)
/// and the Quick Settings tile's cached needs-attention count. Both are
/// derived on every notification, published only when changed, and
/// withdrawn on an explicit disconnect.

class _MemoryProfileStore extends ProfileStore {
  _MemoryProfileStore({required super.prefs, required this.savedProfile});

  final ServerProfile savedProfile;
  String? selectedID;

  @override
  List<ServerProfile> get profiles => [savedProfile];

  @override
  String? get activeId => selectedID;

  @override
  Future<void> setActiveId(String? id) async {
    selectedID = id;
  }
}

class _Api extends OpenCodeApi with CompleteMessageHistory {
  _Api() : super(baseUrl: 'http://localhost:4096');

  @override
  Future<List<MessageWithParts>> messages(String id) async => const [];

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() async => const [];

  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() async => const [];
}

class _Repository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceProject>> listProjects() async => const [];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => const [];

  @override
  Future<List<PendingQuestion>> listQuestions() async => const [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session(String id, {String? title, int updated = 1}) => Session(
  id: id,
  title: title,
  time: SessionTime(created: 1, updated: updated),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const shortcutChannel = MethodChannel('oc/shortcut');
  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late List<Map<String, Object?>> publishes;

  setUp(() {
    publishes = [];
    messenger.setMockMethodCallHandler(shortcutChannel, (call) async {
      if (call.method == 'setPinnedSessions') {
        publishes.add((call.arguments as Map).cast<String, Object?>());
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/background'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(secureStorage, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(shortcutChannel, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('oc/background'),
        null,
      );
      messenger.setMockMethodCallHandler(secureStorage, null);
      debugPlatformCapabilities = null;
    });
  });

  Future<(ConnectionController, SharedPreferences)> connected() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final profile = ServerProfile(
      id: 'server-1',
      name: 'Local',
      baseUrl: 'http://localhost:4096',
    );
    final store = _MemoryProfileStore(prefs: prefs, savedProfile: profile);
    await store.setActiveId(profile.id);
    final controller = ConnectionController(store)
      ..api = _Api()
      ..repository = _Repository()
      ..version = '1.18.23'
      ..status = StreamStatus.connected;
    addTearDown(controller.dispose);
    for (var index = 1; index <= 6; index++) {
      controller.sessionsById['ses-$index'] = _session(
        'ses-$index',
        title: index == 2 ? null : 'Session $index',
        updated: index,
      );
    }
    return (controller, prefs);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('pinned sessions become launcher shortcuts, capped at four', () async {
    final (controller, prefs) = await connected();
    for (final id in ['ses-1', 'ses-2', 'ses-3', 'ses-4', 'ses-5']) {
      await controller.setSessionPinned(
        id,
        true,
        locationRevision: controller.locationRevision,
      );
    }
    await settle();

    final last = publishes.last;
    expect(last['profileID'], 'server-1');
    final sessions = (last['sessions'] as List).cast<Map>();
    expect(sessions, hasLength(4));
    // Pin order is the session list's order: most recently updated first.
    expect(sessions.map((s) => s['id']), ['ses-5', 'ses-4', 'ses-3', 'ses-2']);
    expect(sessions.last['title'], 'Untitled session');
    for (final entry in sessions) {
      expect(entry.keys.toSet(), {'id', 'title'});
    }
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNotNull);

    // Unpinning republishes the smaller set.
    await controller.setSessionPinned(
      'ses-5',
      false,
      locationRevision: controller.locationRevision,
    );
    await settle();
    expect((publishes.last['sessions'] as List).map((s) => (s as Map)['id']), [
      'ses-4',
      'ses-3',
      'ses-2',
      'ses-1',
    ]);
  });

  test('unchanged pins do not republish on every notification', () async {
    final (controller, _) = await connected();
    await controller.setSessionPinned(
      'ses-1',
      true,
      locationRevision: controller.locationRevision,
    );
    await settle();
    final before = publishes.length;
    controller.notifyListeners();
    controller.notifyListeners();
    await settle();
    expect(publishes.length, before);
  });

  test('the tile cache carries the Activity count and nothing else', () async {
    final (controller, prefs) = await connected();
    controller.permissions['p1'] = PermissionRequest(
      id: 'p1',
      sessionID: 'ses-1',
      permission: 'edit',
      patterns: const ['lib/main.dart'],
    );
    controller.questions['q1'] = const PendingQuestion(
      id: 'q1',
      sessionID: 'ses-1',
      prompts: [],
    );
    controller.notifyListeners();
    await settle();

    final cached =
        jsonDecode(prefs.getString(AttentionTileSnapshot.prefsKey)!) as Map;
    expect(cached['pendingCount'], 2);
    expect(cached['profileID'], 'server-1');
    expect(cached.keys.toSet(), {'pendingCount', 'profileID', 'updatedAt'});
    expect(
      prefs.getString(AttentionTileSnapshot.prefsKey),
      isNot(contains('main.dart')),
    );

    controller.permissions.clear();
    controller.notifyListeners();
    await settle();
    expect(
      (jsonDecode(prefs.getString(AttentionTileSnapshot.prefsKey)!)
          as Map)['pendingCount'],
      1,
    );
  });

  test('nothing is published while not connected', () async {
    final (controller, prefs) = await connected();
    controller.status = StreamStatus.connecting;
    await controller.setSessionPinned(
      'ses-1',
      true,
      locationRevision: controller.locationRevision,
    );
    await settle();
    expect(publishes, isEmpty);
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
    expect(prefs.getString(AttentionTileSnapshot.prefsKey), isNull);
  });

  test('an explicit disconnect withdraws both surfaces', () async {
    final (controller, prefs) = await connected();
    await controller.setSessionPinned(
      'ses-1',
      true,
      locationRevision: controller.locationRevision,
    );
    await settle();
    expect((publishes.last['sessions'] as List), isNotEmpty);
    expect(prefs.getString(AttentionTileSnapshot.prefsKey), isNotNull);

    await controller.disconnect(keepActive: true);
    await settle();

    expect(publishes.last['sessions'], isEmpty);
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
    expect(prefs.getString(AttentionTileSnapshot.prefsKey), isNull);
  });

  test('lifecycle suspension keeps the last published state', () async {
    final (controller, prefs) = await connected();
    await controller.setSessionPinned(
      'ses-1',
      true,
      locationRevision: controller.locationRevision,
    );
    await settle();
    final before = publishes.length;

    controller.suspendForLifecycle();
    await settle();

    expect(controller.status, StreamStatus.disconnected);
    expect(publishes.length, before);
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNotNull);
    expect(prefs.getString(AttentionTileSnapshot.prefsKey), isNotNull);
  });

  test('off Android neither surface is written', () async {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    final (controller, prefs) = await connected();
    await controller.setSessionPinned(
      'ses-1',
      true,
      locationRevision: controller.locationRevision,
    );
    await settle();
    expect(publishes, isEmpty);
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
    expect(prefs.getString(AttentionTileSnapshot.prefsKey), isNull);
  });
}
