import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/setup_registry.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/setup_registry_store.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  String body = jsonEncode({
    'servers': [
      {
        'server': {
          'name': 'org.example/weather',
          'version': '1.0.0',
          'description': 'Weather tools',
          'remotes': [
            {'type': 'streamable-http', 'url': 'https://tools.example/mcp'},
          ],
        },
      },
    ],
  });
  Completer<void>? gate;
  Completer<void>? requestEntered;
  bool fail = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final entered = requestEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    await gate?.future;
    if (fail) throw StateError('private upstream diagnostics');
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedPreferences extends InMemorySharedPreferencesStore {
  _DelayedPreferences(super.data) : super.withData();
  Completer<void>? gate;
  final entered = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final pending = gate;
    if (pending != null && key.endsWith('oc.setupRegistry.one')) {
      if (!entered.isCompleted) entered.complete();
      await pending.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _Transport transport;
  late SetupRegistryClient client;
  late SetupRegistryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    transport = _Transport();
    client = SetupRegistryClient(adapter: transport);
    store = SetupRegistryStore(prefs, profileId: 'one', client: client);
    KitRedact.clearKnownSecrets();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  tearDown(() async {
    await store.dispose();
    client.dispose();
    KitRedact.clearKnownSecrets();
  });

  Future<_DelayedPreferences> delayedDisk() async {
    await store.dispose();
    final original = SharedPreferencesStorePlatform.instance;
    final disk = _DelayedPreferences(await original.getAll());
    SharedPreferencesStorePlatform.instance = disk;
    SharedPreferences.resetStatic();
    addTearDown(() => SharedPreferencesStorePlatform.instance = original);
    prefs = await SharedPreferences.getInstance();
    store = SetupRegistryStore(prefs, profileId: 'one', client: client);
    await store.load();
    return disk;
  }

  test(
    'opt-out is persisted after a refresh write already in flight',
    () async {
      final disk = await delayedDisk();
      await store.setOptIn(true);
      disk.gate = Completer<void>();
      final refresh = store.refresh();
      await disk.entered.future;
      final disable = store.setOptIn(false);
      disk.gate!.complete();
      await Future.wait([refresh, disable]);
      final raw =
          (await disk.getAll())['flutter.oc.setupRegistry.one'] as String;
      expect(jsonDecode(raw)['optedIn'], isFalse);
      expect(store.snapshot.optedIn, isFalse);
    },
  );

  test('clear waits for a pending refresh write then removes it', () async {
    final disk = await delayedDisk();
    await store.setOptIn(true);
    disk.gate = Completer<void>();
    final refresh = store.refresh();
    await disk.entered.future;
    final clear = store.clear();
    disk.gate!.complete();
    await Future.wait([refresh, clear]);
    expect(
      (await disk.getAll()).containsKey('flutter.oc.setupRegistry.one'),
      isFalse,
    );
    expect(store.snapshot.entries, isEmpty);
  });

  test('awaiting dispose drains writes before profile deletion', () async {
    final disk = await delayedDisk();
    await store.setOptIn(true);
    disk.gate = Completer<void>();
    final refresh = store.refresh();
    await disk.entered.future;
    var closed = false;
    final closing = store.dispose().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    disk.gate!.complete();
    await refresh;
    await closing;
    await ProfileStore(prefs: prefs).removeScopedPreferences('one');
    expect(
      (await disk.getAll()).containsKey('flutter.oc.setupRegistry.one'),
      isFalse,
    );
  });

  test(
    'default load, refresh and offline mode never access the internet',
    () async {
      await store.load();
      await store.refresh();
      expect(store.snapshot.status, SetupRegistryStatus.disabled);
      await store.setOptIn(true);
      expect(transport.requests, isEmpty);
      await store.refresh(online: false);
      expect(transport.requests, isEmpty);
      expect(store.snapshot.status, SetupRegistryStatus.offline);
    },
  );

  test(
    'explicit refresh uses fixed unauthenticated origin and caches safely',
    () async {
      final states = <SetupRegistryStatus>[];
      final subscription = store.changes.listen(
        (state) => states.add(state.status),
      );
      await store.setOptIn(true);
      await store.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        states,
        containsAllInOrder([
          SetupRegistryStatus.loading,
          SetupRegistryStatus.ready,
        ]),
      );
      expect(transport.requests, hasLength(1));
      final request = transport.requests.single;
      expect(request.uri.origin, 'https://registry.modelcontextprotocol.io');
      expect(request.uri.path, '/v0.1/servers');
      expect(request.queryParameters, {'limit': 100, 'version': 'latest'});
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(store.snapshot.entries.single.name, 'org.example/weather');
      expect(store.snapshot.entries.single.connectableRemote!.toMcpConfig(), {
        'type': 'remote',
        'url': 'https://tools.example/mcp',
        'enabled': false,
      });
      expect(prefs.containsKey('oc.setupRegistry.one'), isTrue);
      expect(store.snapshot.cachedAt, isNotNull);
      await subscription.cancel();
    },
  );

  test(
    'restart preserves consent and cache; opt-out and offline do not fetch',
    () async {
      await store.setOptIn(true);
      await store.refresh();
      final reopened = SetupRegistryStore(
        prefs,
        profileId: 'one',
        client: client,
      );
      await reopened.load();
      expect(reopened.snapshot.entries, hasLength(1));
      await reopened.refresh(online: false);
      expect(reopened.snapshot.status, SetupRegistryStatus.offline);
      await reopened.setOptIn(false);
      await reopened.refresh();
      expect(reopened.snapshot.entries, hasLength(1));
      expect(transport.requests, hasLength(1));
      await reopened.dispose();
    },
  );

  test(
    'profile cache is isolated and existing deletion sweep removes it',
    () async {
      await store.setOptIn(true);
      await store.refresh();
      final other = SetupRegistryStore(prefs, profileId: 'two', client: client);
      await other.load();
      expect(other.snapshot.optedIn, isFalse);
      expect(other.snapshot.entries, isEmpty);
      await other.setOptIn(true);
      final profiles = ProfileStore(prefs: prefs);
      expect(
        profiles.profileScopedPreferenceKeys('one'),
        contains(store.storageKey),
      );
      expect(await profiles.removeScopedPreferences('one'), isEmpty);
      expect(prefs.containsKey(store.storageKey), isFalse);
      expect(prefs.containsKey(other.storageKey), isTrue);
      await other.dispose();
    },
  );

  test(
    'clear forgets consent and cache without changing other preferences',
    () async {
      await prefs.setString('oc.unrelated.two', 'kept');
      await store.setOptIn(true);
      await store.refresh();
      await store.clear();
      expect(store.snapshot.status, SetupRegistryStatus.disabled);
      expect(store.snapshot.entries, isEmpty);
      expect(prefs.containsKey(store.storageKey), isFalse);
      expect(prefs.getString('oc.unrelated.two'), 'kept');
    },
  );

  test(
    'offline transition cancels an in-flight refresh and keeps cached state',
    () async {
      await store.setOptIn(true);
      await store.refresh();
      transport.gate = Completer<void>();
      transport.requestEntered = Completer<void>();
      final refresh = store.refresh();
      await transport.requestEntered!.future;
      await store.refresh(online: false);
      transport.gate!.complete();
      await refresh;
      expect(store.snapshot.status, SetupRegistryStatus.offline);
      expect(store.snapshot.entries, hasLength(1));
      expect(transport.requests, hasLength(2));
    },
  );

  test('opt-out during refresh cannot resurrect entries or consent', () async {
    await store.setOptIn(true);
    transport.gate = Completer<void>();
    transport.requestEntered = Completer<void>();
    final refresh = store.refresh();
    await transport.requestEntered!.future;
    await store.setOptIn(false);
    transport.gate!.complete();
    await refresh;
    expect(store.snapshot.optedIn, isFalse);
    expect(store.snapshot.entries, isEmpty);
    expect(jsonDecode(prefs.getString(store.storageKey)!)['optedIn'], isFalse);
  });

  test(
    'deletion during refresh cannot recreate a profile preference',
    () async {
      await store.setOptIn(true);
      transport.gate = Completer<void>();
      transport.requestEntered = Completer<void>();
      final refresh = store.refresh();
      await transport.requestEntered!.future;
      await prefs.remove(store.storageKey);
      transport.gate!.complete();
      await refresh;
      expect(prefs.containsKey(store.storageKey), isFalse);
    },
  );

  test(
    'redirects, oversized data and invalid JSON fail with safe copy',
    () async {
      await store.setOptIn(true);
      for (final response in [
        (302, '{}'),
        (200, 'x' * (SetupRegistryClient.maxResponseBytes + 1)),
        (200, 'not JSON'),
      ]) {
        transport.status = response.$1;
        transport.body = response.$2;
        await store.refresh();
        expect(store.snapshot.status, SetupRegistryStatus.error);
        expect(
          store.snapshot.reason,
          'The public registry could not be loaded. Showing saved listings.',
        );
      }
      expect(transport.requests, hasLength(3));
    },
  );

  test(
    'failed refresh keeps cached entries and hides raw exceptions',
    () async {
      await store.setOptIn(true);
      await store.refresh();
      transport.fail = true;
      await store.refresh();
      expect(store.snapshot.entries, hasLength(1));
      expect(
        store.snapshot.reason!.contains('private upstream diagnostics'),
        isFalse,
      );
    },
  );

  test(
    'metadata redaction drops credentials, unsafe URLs, and executable arguments',
    () async {
      transport.body = jsonEncode({
        'servers': [
          {
            'server': {
              'name': 'org.example/weather',
              'version': '1.0.0',
              'description': 'token=fake-registry-secret',
              'remotes': [
                {'type': 'sse', 'url': 'http://tools.example/mcp'},
                {
                  'type': 'sse',
                  'url': 'https://user:fake-password@tools.example/mcp',
                },
                {
                  'type': 'sse',
                  'url': 'https://tools.example/mcp?token=fake-query',
                },
                {'type': 'sse', 'url': 'https://tools.example/{tenant}'},
                {
                  'type': 'sse',
                  'url': 'https://tools.example/mcp',
                  'headers': [
                    {'name': 'Authorization', 'value': 'Bearer fake-header'},
                  ],
                },
              ],
              'packages': [
                {
                  'registryType': 'npm',
                  'identifier': '@example/weather',
                  'version': '1.0.0',
                  'runtimeArguments': ['fake-command'],
                  'environmentVariables': [
                    {'name': 'API_KEY', 'value': 'fake-env'},
                  ],
                },
              ],
            },
          },
        ],
      });
      await store.setOptIn(true);
      await store.refresh();
      final entry = store.snapshot.entries.single;
      expect(entry.description.contains('fake-registry-secret'), isFalse);
      expect(entry.remotes, hasLength(1));
      expect(entry.remotes.single.requiresConfiguration, isTrue);
      expect(entry.connectableRemote, isNull);
      expect(entry.unsupportedReason, contains('connection details'));
      expect(
        entry.remotes.single.toMcpConfig,
        throwsA(isA<SetupRegistryException>()),
      );
      final stored = prefs.getString(store.storageKey)!;
      for (final dropped in [
        'fake-registry-secret',
        'fake-password',
        'fake-query',
        'fake-header',
        'fake-command',
        'fake-env',
      ]) {
        expect(stored.contains(dropped), isFalse);
      }
      expect(entry.packages.single.identifier, '@example/weather');
    },
  );

  test('package-only listings explain the unsupported installation path', () {
    final entry = RegistryEntry.fromJson({
      'name': 'org.example/package',
      'version': '1.0.0',
      'packages': [
        {
          'registryType': 'npm',
          'identifier': '@example/package',
          'version': '1.0.0',
        },
      ],
    })!;
    expect(entry.connectableRemote, isNull);
    expect(entry.unsupportedReason, contains('reviewed command'));
  });

  test(
    'deleted listings are excluded and server response count is bounded',
    () async {
      final server = {'name': 'org.example/weather', 'version': '1.0.0'};
      transport.body = jsonEncode({
        'servers': [
          {
            'server': server,
            '_meta': {
              'io.modelcontextprotocol.registry/official': {
                'status': 'deleted',
              },
            },
          },
          for (var i = 0; i < 101; i++) {'server': server},
        ],
      });
      final entries = await client.fetch();
      expect(entries, hasLength(99));
    },
  );

  test(
    'a search is sent as the registry search parameter, never saved',
    () async {
      await store.setOptIn(true);
      await store.refresh();
      final saved = prefs.getString(store.storageKey);
      await store.refresh(query: ' weather ');
      final request = transport.requests.last;
      expect(request.uri.path, '/v0.1/servers');
      expect(request.queryParameters, {
        'limit': 100,
        'version': 'latest',
        'search': 'weather',
      });
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(store.snapshot.query, 'weather');
      expect(prefs.getString(store.storageKey), saved);
      store.showSaved();
      expect(store.snapshot.query, isNull);
      expect(store.snapshot.entries.single.name, 'org.example/weather');
    },
  );

  test('a search term that looks like a credential is not sent', () async {
    await client.fetch(search: 'ghp_abcdefghijklmnopqrstuvwxyz0123456789');
    expect(
      transport.requests.single.queryParameters.containsKey('search'),
      isFalse,
    );
  });

  test('declared header and variable names are kept, never their values', () {
    final entry = RegistryEntry.fromJson({
      'name': 'org.example/both',
      'version': '1.0.0',
      'title': 'Both',
      'remotes': [
        {
          'type': 'streamable-http',
          'url': 'https://tools.example/mcp',
          'headers': [
            {
              'name': 'Authorization',
              'isRequired': true,
              'isSecret': true,
              'value': 'Bearer fake-header',
              'default': 'fake-default',
            },
            {'name': 'bad name; rm', 'isRequired': true},
          ],
        },
      ],
      'packages': [
        {
          'registryType': 'npm',
          'identifier': '@example/both',
          'version': '1.0.0',
          'runtimeHint': 'npx',
          'transport': {'type': 'stdio'},
          'packageArguments': [
            {'value': 'fake-argument', 'isRequired': true},
          ],
          'environmentVariables': [
            {'name': 'API_KEY', 'isSecret': true, 'default': 'fake-env'},
          ],
        },
      ],
    })!;
    expect(entry.title, 'Both');
    final header = entry.remotes.single.headers.single;
    expect(
      (header.name, header.required, header.secret),
      ('Authorization', true, true),
    );
    final package = entry.packages.single;
    expect(package.transport, 'stdio');
    expect(package.runtimeHint, 'npx');
    expect(package.requiresArguments, isTrue);
    expect(package.environment.single.name, 'API_KEY');
    final json = jsonEncode(entry.toJson());
    for (final dropped in [
      'fake-header',
      'fake-default',
      'fake-argument',
      'fake-env',
      'rm',
    ]) {
      expect(json.contains(dropped), isFalse, reason: dropped);
    }
    // The saved form reads back the same.
    final again = RegistryEntry.fromJson(entry.toJson())!;
    expect(jsonEncode(again.toJson()), json);
  });
}
