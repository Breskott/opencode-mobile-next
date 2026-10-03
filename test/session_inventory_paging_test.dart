import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/widgets/older_sessions_pager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'http://localhost');
  late Future<ServerPage<Session>> Function(String? cursor) page;
  Future<Session> Function(String id)? one;
  Future<Map<String, String>> Function()? statuses;
  final cursors = <String?>[];
  int detailReads = 0;

  @override
  Future<ServerPage<Session>> sessionPage({String? cursor, int limit = 100}) {
    cursors.add(cursor);
    return page(cursor);
  }

  @override
  Future<Map<String, String>> sessionStatuses() async =>
      statuses == null ? {} : await statuses!();
  @override
  Future<Session> session(String id) async {
    detailReads++;
    return one == null ? Session(id: id, directory: '/one') : one!(id);
  }

  @override
  Future<void> deleteSession(String id) async {}
}

Future<ConnectionController> _controller(_Api api) async {
  SharedPreferences.setMockInitialValues({});
  final controller =
      ConnectionController(
          ProfileStore(prefs: await SharedPreferences.getInstance()),
        )
        ..api = api
        ..status = StreamStatus.connected
        ..directory = '/one';
  addTearDown(controller.dispose);
  return controller;
}

Session _session(String id, {String? title, String? parentID}) =>
    Session(id: id, title: title ?? id, directory: '/one', parentID: parentID);

final _skeletons = find.byKey(const ValueKey('sessions-older-more'));

/// The pager at the end of a list, as the Work tab places it; [above]
/// pushes it that far below the top of the screen.
Widget _host(ConnectionController controller, {double above = 0}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          children: [
            SizedBox(height: above),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => OlderSessionsPager.showsFor(controller)
                  ? OlderSessionsPager(controller: controller)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'detail hydration does not suppress a concurrent busy snapshot',
    () async {
      final statusStarted = Completer<void>();
      final status = Completer<Map<String, String>>();
      final api = _Api()..page = (_) async => const ServerPage(items: []);
      api.statuses = () {
        statusStarted.complete();
        return status.future;
      };
      final controller = await _controller(api);
      final refresh = controller.refreshSessions();
      await statusStarted.future;
      await controller.ensureSession('running');
      status.complete({'running': 'busy'});
      await refresh;
      expect(controller.busySessions, contains('running'));
    },
  );

  testWidgets(
    'the first request shows no pager: no skeleton, no error, no button',
    (tester) async {
      final pending = Completer<ServerPage<Session>>();
      final api = _Api()..page = (_) => pending.future;
      final controller = await _controller(api);
      final refresh = controller.refreshSessions();
      await tester.pumpWidget(_host(controller));
      expect(OlderSessionsPager.showsFor(controller), isFalse);
      expect(_skeletons, findsNothing);
      expect(find.byKey(const ValueKey('sessions-older-error')), findsNothing);
      pending.complete(const ServerPage(items: []));
      await refresh;
      await tester.pumpAndSettle();
      expect(_skeletons, findsNothing);
      expect(api.cursors, [null]);
    },
  );

  testWidgets('status failures leave older sessions reachable: the list '
      'pages itself', (tester) async {
    final api = _Api()
      ..page = (cursor) async => cursor == null
          ? ServerPage(items: [_session('recent')], nextCursor: 'older')
          : ServerPage(items: [_session('old')]);
    api.statuses = () async => throw ApiException('status unavailable');
    final controller = await _controller(api);
    await controller.refreshSessions();
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(api.cursors, [null, 'older']);
    expect(controller.sortedSessions().map((s) => s.id), contains('old'));
    expect(find.text('Load more conversations'), findsNothing);
  });

  testWidgets('empty and duplicate inventory pages keep continuation usable', (
    tester,
  ) async {
    final api = _Api()
      ..page = (cursor) async => switch (cursor) {
        null => ServerPage(
          items: [_session('child', parentID: 'root')],
          nextCursor: 'empty',
        ),
        'empty' => const ServerPage(items: [], nextCursor: 'duplicate'),
        'duplicate' => ServerPage(
          items: [_session('child', parentID: 'root')],
          nextCursor: 'last',
        ),
        _ => ServerPage(items: [_session('older-root')]),
      };
    final controller = await _controller(api);
    await controller.refreshSessions();
    expect(controller.sortedSessions(), isEmpty);
    await tester.pumpWidget(_host(controller));
    for (var i = 0; i < 4; i++) {
      await tester.pumpAndSettle();
    }
    expect(api.cursors, [null, 'empty', 'duplicate', 'last']);
    expect(controller.sortedSessions().single.id, 'older-root');
    expect(controller.hasMoreSessions, isFalse);
    expect(_skeletons, findsNothing);
  });

  testWidgets('an end far below the screen waits until it is scrolled to', (
    tester,
  ) async {
    final api = _Api()
      ..page = (cursor) async => cursor == null
          ? ServerPage(items: [_session('recent')], nextCursor: 'older')
          : ServerPage(items: [_session('old')]);
    final controller = await _controller(api);
    await controller.refreshSessions();
    await tester.pumpWidget(_host(controller, above: 3000));
    await tester.pumpAndSettle();
    expect(api.cursors, [null], reason: 'nothing asked while out of reach');
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(api.cursors, [null, 'older']);
  });

  testWidgets('a failed older page says so in words, never the raw error, '
      'and Try again asks for that page again', (tester) async {
    var fail = true;
    final api = _Api()
      ..page = (cursor) async {
        if (cursor == null) {
          return ServerPage(items: [_session('recent')], nextCursor: 'older');
        }
        if (fail) throw ApiException('upstream said 502 secret-body');
        return ServerPage(items: [_session('old')]);
      };
    final controller = await _controller(api);
    await controller.refreshSessions();
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(api.cursors, [null, 'older']);
    final error = find.byKey(const ValueKey('sessions-older-error'));
    expect(error, findsOneWidget);
    expect(find.text('Could not load older conversations.'), findsOneWidget);
    expect(find.textContaining('secret-body'), findsNothing);
    // It does not ask again by itself.
    await tester.pumpAndSettle();
    expect(api.cursors, [null, 'older']);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(api.cursors, [null, 'older', 'older']);
    expect(error, findsNothing);
    expect(controller.sortedSessions().map((s) => s.id), contains('old'));
  });

  testWidgets('a list that changed while paging offers a refresh from the '
      'newest page', (tester) async {
    final api = _Api()
      ..page = (cursor) async => switch (cursor) {
        null => ServerPage(items: [_session('recent')], nextCursor: 'loop'),
        _ => ServerPage(items: [_session('again')], nextCursor: 'loop'),
      };
    final controller = await _controller(api);
    await controller.refreshSessions();
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(controller.sessionsNeedReload, isTrue);
    expect(
      find.text(
        'The conversation list changed on the server. Refresh it to see '
        'older conversations.',
      ),
      findsOneWidget,
    );
    api.page = (cursor) async => ServerPage(items: [_session('fresh')]);
    await tester.tap(find.text('Refresh recent conversations'));
    await tester.pumpAndSettle();
    expect(api.cursors.last, isNull);
    expect(controller.sessionsNeedReload, isFalse);
    expect(find.byKey(const ValueKey('sessions-older-error')), findsNothing);
  });

  test(
    'partial refresh preserves cached older metadata and resets continuation',
    () async {
      final api = _Api()
        ..page = (cursor) async => cursor == null
            ? ServerPage(items: [_session('recent')], nextCursor: 'older')
            : ServerPage(items: [_session('old')]);
      final controller = await _controller(api);
      await controller.refreshSessions();
      await controller.loadMoreSessions();
      await controller.refreshSessions();
      expect(controller.sessionsById.keys, containsAll(['recent', 'old']));
      expect(controller.hasMoreSessions, isTrue);
      expect(api.cursors, [null, 'older', null]);
    },
  );

  test(
    'pending page cannot resurrect deletes or overwrite newer live metadata',
    () async {
      final pending = Completer<ServerPage<Session>>();
      final api = _Api()
        ..page = (cursor) async => cursor == null
            ? ServerPage(items: [_session('recent')], nextCursor: 'older')
            : pending.future;
      final controller = await _controller(api);
      await controller.refreshSessions();
      final more = controller.loadMoreSessions();
      controller.handleEventForTesting(
        EventEnvelope(
          type: 'session.deleted',
          properties: {
            'info': {'id': 'deleted'},
          },
        ),
      );
      controller.handleEventForTesting(
        EventEnvelope(
          type: 'session.updated',
          properties: {
            'info': {'id': 'old', 'directory': '/one', 'title': 'live title'},
          },
        ),
      );
      pending.complete(
        ServerPage(
          items: [
            _session('deleted'),
            _session('old', title: 'stale'),
          ],
        ),
      );
      await more;
      expect(controller.sessionsById.containsKey('deleted'), isFalse);
      expect(controller.sessionsById['old']!.title, 'live title');
      expect(controller.sessionsById.containsKey('recent'), isTrue);
    },
  );

  test(
    'new head refresh invalidates an older request without clearing new state',
    () async {
      final pending = Completer<ServerPage<Session>>();
      var refreshed = false;
      final api = _Api()
        ..page = (cursor) async => cursor == null
            ? ServerPage(
                items: [_session(refreshed ? 'new-head' : 'recent')],
                nextCursor: 'older',
              )
            : pending.future;
      final controller = await _controller(api);
      await controller.refreshSessions();
      final more = controller.loadMoreSessions();
      refreshed = true;
      await controller.refreshSessions();
      pending.complete(ServerPage(items: [_session('stale-page')]));
      await more;
      expect(controller.sessionsById.containsKey('stale-page'), isFalse);
      expect(controller.sessionsById.containsKey('new-head'), isTrue);
      expect(controller.sessionsLoadingMore, isFalse);
      expect(controller.hasMoreSessions, isTrue);
    },
  );

  test(
    'expired cursor reloads and transient failure retries the same token',
    () async {
      var failure = 500;
      final api = _Api()
        ..page = (cursor) async {
          if (cursor != null) {
            throw ApiException('read failed', statusCode: failure);
          }
          return ServerPage(items: [_session('recent')], nextCursor: 'older');
        };
      final controller = await _controller(api);
      await controller.refreshSessions();
      await controller.loadMoreSessions();
      expect(controller.sessionsNeedReload, isFalse);
      failure = 410;
      await controller.loadMoreSessions();
      expect(controller.sessionsNeedReload, isTrue);
      await controller.loadMoreSessions();
      expect(api.cursors, [null, 'older', 'older', null]);
      expect(controller.sessionsMoreError, isNull);
    },
  );

  test(
    'direct reads coalesce and keep out-of-location metadata out of inventory',
    () async {
      final details = Completer<Session>();
      final api = _Api()
        ..page = (_) async =>
            ServerPage(items: [_session('recent')], nextCursor: 'older');
      api.one = (_) => details.future;
      final controller = await _controller(api);
      await controller.refreshSessions();
      final first = controller.ensureSession('foreign');
      final second = controller.ensureSession('foreign');
      details.complete(Session(id: 'foreign', directory: '/elsewhere'));
      await Future.wait([first, second]);
      expect(api.detailReads, 1);
      expect(controller.sessionsById.containsKey('foreign'), isTrue);
      expect(controller.sortedSessions().map((s) => s.id), ['recent']);
      api.one = (id) async => Session(id: id, directory: '/elsewhere');
      await controller.ensureSession('recent');
      expect(controller.sortedSessions(), isEmpty);
      expect(controller.sessionsById.containsKey('recent'), isTrue);
      api.page = (_) async => const ServerPage(items: []);
      await controller.refreshSessions();
      expect(controller.sessionsById.keys, containsAll(['recent', 'foreign']));
    },
  );

  test(
    'direct lookup protects newer details from a pending inventory page',
    () async {
      final page = Completer<ServerPage<Session>>();
      final api = _Api()..page = (_) => page.future;
      api.one = (id) async => _session(id, title: 'fresh details');
      final controller = await _controller(api);
      final refresh = controller.refreshSessions();
      await controller.ensureSession('recent');
      page.complete(
        ServerPage(items: [_session('recent', title: 'old details')]),
      );
      await refresh;
      expect(controller.sessionsById['recent']!.title, 'fresh details');
    },
  );

  test(
    'confirmed local deletion and authoritative 404 clear cached entities',
    () async {
      final api = _Api()
        ..page = (_) async => ServerPage(
          items: [_session('delete'), _session('missing')],
          nextCursor: 'older',
        );
      final controller = await _controller(api);
      await controller.refreshSessions();
      await controller.deleteSession('delete');
      expect(controller.sessionsById.containsKey('delete'), isFalse);
      api.page = (_) async =>
          ServerPage(items: [_session('delete'), _session('missing')]);
      await controller.loadMoreSessions();
      expect(controller.sessionsById.containsKey('delete'), isFalse);
      api.one = (_) async => throw ApiException('missing', statusCode: 404);
      await controller.ensureSession('missing');
      expect(controller.sessionsById, isEmpty);
    },
  );

  testWidgets(
    'a newer session revision starts a fresh detail read instead of joining stale work',
    (tester) async {
      final old = Completer<Session>();
      final fresh = Completer<Session>();
      final api = _Api();
      api.one = (_) => api.detailReads == 1 ? old.future : fresh.future;
      final controller = await _controller(api);
      final pending = controller.ensureSession('target');
      controller.handleEventForTesting(
        EventEnvelope(
          type: 'session.compacted',
          properties: {'sessionID': 'target'},
        ),
      );
      await tester.pump();
      expect(api.detailReads, 2);
      fresh.complete(_session('target', title: 'Fresh title'));
      await tester.pump();
      old.complete(_session('target', title: 'Stale title'));
      await pending;
      expect(controller.sessionsById['target']!.title, 'Fresh title');
    },
  );

  testWidgets('stale detail failure cannot replace a successful newer read', (
    tester,
  ) async {
    final old = Completer<Session>();
    final api = _Api();
    api.one = (_) => api.detailReads == 1
        ? old.future
        : Future.value(_session('target', title: 'Fresh title'));
    final controller = await _controller(api);
    final pending = controller.ensureSession('target');
    controller.handleEventForTesting(
      EventEnvelope(
        type: 'session.compacted',
        properties: {'sessionID': 'target'},
      ),
    );
    await tester.pump();
    old.completeError(ApiException('stale missing', statusCode: 404));
    await pending;
    expect(controller.sessionsById['target']!.title, 'Fresh title');
    expect(controller.sessionDetailsErrors, isEmpty);
  });
}
