import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TimedApi extends OpenCodeApi {
  _TimedApi() : super(baseUrl: 'https://fixture.invalid');
  bool failStatus = false;
  @override
  Future<ServerPage<Session>> sessionPage({
    String? cursor,
    int limit = 100,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return ServerPage(items: [Session(id: 'one')]);
  }

  @override
  Future<Map<String, String>> sessionStatuses() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (failStatus) throw StateError('synthetic failure');
    return {'one': 'busy'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inventory latency and partial status failure', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ConnectionController(
      ProfileStore(prefs: prefs),
      isIsolated: true,
    );
    final api = _TimedApi();
    controller.api = api;
    var completed = false;
    final pending = controller.refreshSessions().then((_) => completed = true);
    var elapsed = 0;
    while (!completed && elapsed < 240) {
      await tester.pump(const Duration(milliseconds: 10));
      elapsed += 10;
    }
    await pending;
    debugPrint('PERF inventory scripted_ms=$elapsed');
    expect(elapsed, 60);
    expect(controller.sortedSessions().single.id, 'one');
    expect(controller.busySessions, contains('one'));
    api.failStatus = true;
    final failedStatus = controller.refreshSessions();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await failedStatus;
    expect(controller.sortedSessions().single.id, 'one');
    expect(controller.sessionsError, isNotNull);
    controller.dispose();
  });

  test('5000 sessions across 20 unrelated reads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ConnectionController(
      ProfileStore(prefs: prefs),
      isIsolated: true,
    );
    controller.sessionsById = {
      for (var i = 0; i < 5000; i++)
        '$i': Session(
          id: '$i',
          time: SessionTime(updated: (i * 7919) % 5000),
        ),
    };
    List<Session>? previous;
    var projections = 0;
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      final sorted = controller.sortedSessions();
      if (!identical(previous, sorted)) projections++;
      previous = sorted;
    }
    watch.stop();
    debugPrint(
      'PERF inventory sort projections=$projections host_us=${watch.elapsedMicroseconds}',
    );
    expect(projections, 1);
    final old = previous!;
    expect(() => old.clear(), throwsUnsupportedError);
    controller.sessionsById[old.last.id] = old.last.copyWith(
      time: SessionTime(updated: 99999),
    );
    expect(controller.sortedSessions().first.id, old.last.id);
    expect(old.first.time!.updated, 4999);
    controller.sessionsById.remove(old.first.id);
    expect(controller.sortedSessions().length, 4999);
    controller.dispose();
  });
}
