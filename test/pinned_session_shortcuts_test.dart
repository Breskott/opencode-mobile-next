import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/background/pinned_session_shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _session(String id, {String? title}) =>
    Session(id: id, title: title, time: SessionTime(created: 1, updated: 2));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    (PinnedSessionShortcuts, SharedPreferences, List<Map<String, Object?>>)
  >
  harness({
    bool isAndroid = true,
    Map<String, Object> initial = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final published = <Map<String, Object?>>[];
    final shortcuts = PinnedSessionShortcuts(
      prefs: prefs,
      isAndroid: isAndroid,
      publishNative: (payload) async => published.add(payload),
    );
    return (shortcuts, prefs, published);
  }

  test('publishes at most four pinned sessions, titles and ids only', () async {
    final (shortcuts, prefs, published) = await harness();
    await shortcuts.update(
      sessions: [
        _session('s1', title: '  Fix auth  '),
        _session('s2'),
        _session('s3', title: 'Refactor'),
        _session('s4', title: 'Docs'),
        _session('s5', title: 'Never shown'),
      ],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );

    expect(published, hasLength(1));
    final payload = published.single;
    expect(payload['profileID'], 'server-1');
    final sessions = payload['sessions'] as List;
    expect(sessions, hasLength(4));
    expect(sessions[0], {'id': 's1', 'title': 'Fix auth'});
    expect(sessions[1], {'id': 's2', 'title': 'Untitled session'});
    expect((sessions[3] as Map)['id'], 's4');
    // Exactly these two keys per entry: no prompt text, tool input, busy
    // state, timestamps or file paths ever reach the launcher.
    for (final entry in sessions) {
      expect((entry as Map).keys.toSet(), {'id', 'title'});
    }
    // The published set is remembered with its owner so a later process can
    // withdraw it on deletion.
    final stored =
        jsonDecode(prefs.getString(PinnedSessionShortcuts.prefsKey)!) as Map;
    expect(stored['profileID'], 'server-1');
    expect((stored['sessions'] as List), hasLength(4));
  });

  test('long titles are cut before they leave the app', () async {
    final (shortcuts, _, published) = await harness();
    final long = 'x' * 200;
    await shortcuts.update(
      sessions: [_session('s1', title: long)],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    final title =
        ((published.single['sessions'] as List).single as Map)['title']
            as String;
    expect(title.length, PinnedSessionShortcuts.maxTitleLength);
  });

  test('unchanged payloads are not republished', () async {
    final (shortcuts, _, published) = await harness();
    final sessions = [_session('s1', title: 'Fix auth')];
    await shortcuts.update(
      sessions: sessions,
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    await shortcuts.update(
      sessions: sessions,
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    expect(published, hasLength(1));

    // A title edit or a new pin changes the payload.
    await shortcuts.update(
      sessions: [_session('s1', title: 'Fix auth now')],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    expect(published, hasLength(2));
  });

  test('no pins publishes an empty set and forgets the record', () async {
    final (shortcuts, prefs, published) = await harness();
    await shortcuts.update(
      sessions: [_session('s1', title: 'Fix auth')],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    await shortcuts.update(
      sessions: const [],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    expect(published, hasLength(2));
    expect(published.last['sessions'], isEmpty);
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
  });

  test('clear withdraws everything on disconnect', () async {
    final (shortcuts, prefs, published) = await harness();
    await shortcuts.update(
      sessions: [_session('s1', title: 'Fix auth')],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    await shortcuts.clear();
    expect(published.last, {'profileID': '', 'sessions': isEmpty});
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
    // Clearing twice is free.
    await shortcuts.clear();
    expect(published, hasLength(2));
  });

  group('clearForProfile', () {
    final record = jsonEncode({
      'profileID': 'server-1',
      'sessions': [
        {'id': 's1', 'title': 'Fix auth'},
      ],
    });

    test('withdraws the deleted profile\'s shortcuts', () async {
      final (shortcuts, prefs, published) = await harness(
        initial: {PinnedSessionShortcuts.prefsKey: record},
      );
      expect(
        await shortcuts.clearForProfile('server-1'),
        PinnedShortcutClear.cleared,
      );
      expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
      expect(published.single['sessions'], isEmpty);
    });

    test('leaves another profile\'s shortcuts alone', () async {
      final (shortcuts, prefs, published) = await harness(
        initial: {PinnedSessionShortcuts.prefsKey: record},
      );
      expect(
        await shortcuts.clearForProfile('server-2'),
        PinnedShortcutClear.nothingToClear,
      );
      expect(prefs.getString(PinnedSessionShortcuts.prefsKey), record);
      expect(published, isEmpty);
    });

    test('reports nothing to clear when nothing was published', () async {
      final (shortcuts, _, published) = await harness();
      expect(
        await shortcuts.clearForProfile('server-1'),
        PinnedShortcutClear.nothingToClear,
      );
      expect(published, isEmpty);
    });

    test('an unreadable record is withdrawn rather than kept', () async {
      final (shortcuts, prefs, published) = await harness(
        initial: {PinnedSessionShortcuts.prefsKey: '{not json'},
      );
      expect(
        await shortcuts.clearForProfile('server-1'),
        PinnedShortcutClear.cleared,
      );
      expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
      expect(published, hasLength(1));
    });

    test('off Android the record is still removed without a publish', () async {
      final (shortcuts, prefs, published) = await harness(
        isAndroid: false,
        initial: {PinnedSessionShortcuts.prefsKey: record},
      );
      expect(
        await shortcuts.clearForProfile('server-1'),
        PinnedShortcutClear.cleared,
      );
      expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
      expect(published, isEmpty);
    });
  });

  test('non-Android platforms publish nothing', () async {
    final (shortcuts, prefs, published) = await harness(isAndroid: false);
    await shortcuts.update(
      sessions: [_session('s1', title: 'Fix auth')],
      profileID: 'server-1',
      untitledLabel: 'Untitled session',
    );
    await shortcuts.clear();
    expect(prefs.getString(PinnedSessionShortcuts.prefsKey), isNull);
    expect(published, isEmpty);
  });
}
