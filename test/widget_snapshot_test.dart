import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/background/widget_snapshot.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _session(String id, {String? title, int? updated}) => Session(
  id: id,
  title: title,
  time: SessionTime(created: 1, updated: updated),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(WidgetSessionSnapshot, SharedPreferences, List<int>)> harness({
    bool isAndroid = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final refreshes = <int>[];
    final snapshot = WidgetSessionSnapshot(
      prefs: prefs,
      isAndroid: isAndroid,
      refreshNative: () async => refreshes.add(1),
    );
    return (snapshot, prefs, refreshes);
  }

  test(
    'snapshot keeps routing private and profile deletion removes target',
    () async {
      final (snapshot, prefs, _) = await harness();
      await snapshot.update(
        sessions: [_session('s1')],
        busySessions: {},
        connected: true,
        profileID: 'server-1',
        scopeToken: 'opaque-scope',
        onDemand: {
          'fingerprint': 'opaque-fingerprint',
          'directory': '/private/project',
          'workspace': 'private-workspace',
        },
      );
      final raw = prefs.getString(WidgetSessionSnapshot.prefsKey)!;
      expect(raw, isNot(contains('/private/project')));
      expect(raw, isNot(contains('private-workspace')));
      expect(jsonDecode(raw)['onDemand'], {
        'fingerprint': 'opaque-fingerprint',
      });
      final target = jsonDecode(
        prefs.getString(WidgetSessionSnapshot.targetKey('server-1'))!,
      );
      expect(target['directory'], '/private/project');
      expect(target['scopeToken'], 'opaque-scope');
      expect(
        await snapshot.clearForProfile('server-1'),
        WidgetSnapshotClear.cleared,
      );
      expect(
        prefs.containsKey(WidgetSessionSnapshot.targetKey('server-1')),
        false,
      );
    },
  );
  test('suspension migrates legacy raw routing out of the snapshot', () async {
    final (snapshot, prefs, _) = await harness();
    await prefs.setString(
      WidgetSessionSnapshot.prefsKey,
      jsonEncode({
        'profileID': 'server-1',
        'scopeToken': 'scope',
        'onDemand': {
          'fingerprint': 'fp',
          'directory': '/private/project',
          'workspace': 'workspace',
        },
      }),
    );
    await snapshot.update(
      sessions: [],
      busySessions: {},
      connected: false,
      profileID: 'server-1',
      preserveForOnDemand: true,
    );
    final raw = prefs.getString(WidgetSessionSnapshot.prefsKey)!;
    expect(jsonDecode(raw)['onDemand'], {'fingerprint': 'fp'});
    expect(raw, isNot(contains('/private/project')));
    expect(
      jsonDecode(
        prefs.getString(WidgetSessionSnapshot.targetKey('server-1'))!,
      )['directory'],
      '/private/project',
    );
  });
  test(
    'writes at most four sessions with busy flags and title fallback',
    () async {
      final (snapshot, prefs, refreshes) = await harness();
      await snapshot.update(
        sessions: [
          _session('s1', title: 'Fix auth', updated: 50),
          _session('s2', updated: 40),
          _session('s3', title: 'Refactor', updated: 30),
          _session('s4', title: 'Docs', updated: 20),
          _session('s5', title: 'Never shown', updated: 10),
        ],
        busySessions: {'s1', 's3'},
        connected: true,
        profileID: 'server-1',
      );

      final decoded =
          jsonDecode(prefs.getString(WidgetSessionSnapshot.prefsKey)!)
              as Map<String, dynamic>;
      expect(decoded['connected'], isTrue);
      // The widget stamps this onto every row's tap intent so a tap after a
      // profile switch opens the app normally instead of a foreign chat.
      expect(decoded['profileID'], 'server-1');
      final sessions = decoded['sessions'] as List;
      expect(sessions, hasLength(4));
      expect(sessions[0], {
        'id': 's1',
        'title': 'Fix auth',
        'busy': true,
        'updatedAt': 50,
      });
      expect((sessions[2] as Map)['title'], 'New conversation');
      expect((sessions[2] as Map)['busy'], isFalse);
      // The snapshot never carries prompt text, tool input, or file paths:
      // exactly these four keys per session.
      for (final entry in sessions) {
        expect((entry as Map).keys.toSet(), {
          'id',
          'title',
          'busy',
          'updatedAt',
        });
      }
      expect(refreshes, hasLength(1));
    },
  );

  test(
    'the untitled fallback is the caller\'s words, English if none',
    () async {
      final (snapshot, prefs, _) = await harness();
      await snapshot.update(
        sessions: [_session('s1', updated: 50)],
        busySessions: const {},
        connected: true,
        untitledLabel: 'محادثة بلا عنوان',
      );
      final decoded =
          jsonDecode(prefs.getString(WidgetSessionSnapshot.prefsKey)!)
              as Map<String, dynamic>;
      expect(
        ((decoded['sessions'] as List).single as Map)['title'],
        'محادثة بلا عنوان',
      );
    },
  );

  test('publishes presented titles instead of server placeholders', () async {
    final (snapshot, prefs, _) = await harness();
    await snapshot.update(
      sessions: [
        _session('default', title: 'New session - 2026-10-15T04:39:03.218Z'),
        _session('child', title: 'Child session - 2026-10-15T04:39:03.218Z'),
        _session('custom', title: 'Fix login 2026-10-15T04:39:03.218Z'),
        _session('markup', title: 'Fix auth…<tool_call>private input'),
      ],
      busySessions: const {},
      connected: true,
    );
    final decoded =
        jsonDecode(prefs.getString(WidgetSessionSnapshot.prefsKey)!) as Map;
    expect(
      [for (final row in decoded['sessions'] as List) (row as Map)['title']],
      ['New conversation', 'New conversation', 'Fix login', 'Fix auth'],
    );
  });

  test(
    'presented widget titles use app language and remain redacted',
    () async {
      final (snapshot, prefs, _) = await harness();
      await snapshot.update(
        sessions: [
          _session('default', title: 'New session - 2026-10-15T04:39:03.218Z'),
          _session('empty'),
          _session('custom', title: 'إصلاح تسجيل الدخول'),
          _session('secret', title: 'password=synthetic-password\nTitle'),
        ],
        busySessions: const {},
        connected: true,
        l10n: lookupAppLocalizations(const Locale('ar')),
      );
      final raw = prefs.getString(WidgetSessionSnapshot.prefsKey)!;
      final decoded = jsonDecode(raw) as Map;
      final titles = [
        for (final row in decoded['sessions'] as List) (row as Map)['title'],
      ];
      expect(titles.take(3), [
        'محادثة جديدة',
        'محادثة جديدة',
        'إصلاح تسجيل الدخول',
      ]);
      expect(raw, isNot(contains('synthetic-password')));
      expect(titles.last, contains('Title'));
      expect(titles.last, isNot(contains('\n')));
    },
  );

  test('unchanged payloads neither rewrite nor redraw', () async {
    final (snapshot, _, refreshes) = await harness();
    final sessions = [_session('s1', title: 'Fix auth', updated: 50)];
    await snapshot.update(
      sessions: sessions,
      busySessions: const {},
      connected: true,
    );
    await snapshot.update(
      sessions: sessions,
      busySessions: const {},
      connected: true,
    );
    expect(refreshes, hasLength(1));

    await snapshot.update(
      sessions: sessions,
      busySessions: {'s1'},
      connected: true,
    );
    expect(refreshes, hasLength(2));

    // A profile switch changes the payload, so the widget redraws and its
    // row intents pick up the new discriminator.
    await snapshot.update(
      sessions: sessions,
      busySessions: {'s1'},
      connected: true,
      profileID: 'server-2',
    );
    expect(refreshes, hasLength(3));
  });

  test('non-Android platforms write nothing', () async {
    final (snapshot, prefs, refreshes) = await harness(isAndroid: false);
    await snapshot.update(
      sessions: [_session('s1', title: 'Fix auth', updated: 50)],
      busySessions: const {},
      connected: true,
    );
    expect(prefs.getString(WidgetSessionSnapshot.prefsKey), isNull);
    expect(refreshes, isEmpty);
  });

  group('clearForProfile native answer', () {
    const channel = MethodChannel('oc/background');
    Future<void> answer(Object? value) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => value);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    }

    test('a host with nothing to say still clears the stored copy', () async {
      final (snapshot, prefs, _) = await harness();
      await answer(null);
      await snapshot.update(
        sessions: [_session('s1', title: 'A')],
        busySessions: {},
        connected: true,
        profileID: 'p1',
      );
      expect(await snapshot.clearForProfile('p1'), WidgetSnapshotClear.cleared);
      expect(prefs.getString(WidgetSessionSnapshot.prefsKey), isNull);
    });

    test('an explicit native refusal is a failure', () async {
      final (snapshot, _, _) = await harness();
      await answer({'cleared': false});
      expect(await snapshot.clearForProfile('p1'), WidgetSnapshotClear.failed);
    });
  });
}
