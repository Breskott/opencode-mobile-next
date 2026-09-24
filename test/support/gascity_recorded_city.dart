// A loopback "supervisor" that answers the Gas City read routes with JSON
// recorded from a live city (test/fixtures/gascity/finished_runs, read-only
// GETs against the Android 15 emulator city `phone`, Gas City 1.4.1,
// 2026-09-24; see docs/qa/aiteam-builtin-2026-09-24/README.md "Finished
// runs"). Every request is kept so a test can pin the exact query the
// gateway sent.

import 'dart:convert';
import 'dart:io';

/// The recorded city's name.
const recordedCity = 'phone';

/// When the recorded convoy closed (`convoy.closed` event `ts`).
final recordedConvoyClosedAt = DateTime.parse('2026-09-24T09:33:03.458744331Z');

Directory _fixtureDir() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory(
      '${dir.path}/test/fixtures/gascity/finished_runs',
    );
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError('test/fixtures/gascity/finished_runs not found');
}

/// One recorded response as a decoded map.
Map<String, Object?> recordedJson(String file) =>
    jsonDecode(File('${_fixtureDir().path}/$file').readAsStringSync())
        as Map<String, Object?>;

class RecordedCity {
  RecordedCity._(this._server, this._files);

  final HttpServer _server;
  final Map<String, String> _files;

  /// Every request path with its query, in arrival order.
  final requests = <Uri>[];

  /// Routes that answer 404 (a host without the route).
  final missing = <String>{};

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  /// Starts the host. [overrides] swaps a route's file (key as in
  /// [_route]); add a key to [missing] to answer it 404.
  static Future<RecordedCity> start({
    Map<String, String> overrides = const {},
  }) async {
    final files = <String, String>{
      '/runs': 'runs.json',
      '/convoys': 'convoys.json',
      '/beads': 'beads.json',
      '/beads?ready': 'beads_ready.json',
      '/beads?closed-convoys': 'beads_closed_convoys.json',
      '/events?convoy.closed': 'events_convoy_closed.json',
      '/waits': 'waits.json',
      '/pending': 'pending.json',
      '/convoy/ma-lqw': 'convoy_ma-lqw.json',
      ...overrides,
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final city = RecordedCity._(server, files);
    server.listen(city._answer);
    return city;
  }

  /// The fixture key for a request under `/v0/city/phone`.
  static String _route(Uri uri) {
    final prefix = '/v0/city/$recordedCity';
    final tail = uri.path.startsWith(prefix)
        ? uri.path.substring(prefix.length)
        : uri.path;
    final q = uri.queryParameters;
    if (tail == '/beads' && q['ready'] == 'true') return '/beads?ready';
    if (tail == '/beads' && q['status'] == 'closed' && q['type'] == 'convoy') {
      return '/beads?closed-convoys';
    }
    if (tail == '/events' && q['type'] == 'convoy.closed') {
      return '/events?convoy.closed';
    }
    return tail;
  }

  Future<void> _answer(HttpRequest request) async {
    requests.add(request.uri);
    final route = _route(request.uri);
    final file = _files[route];
    final response = request.response;
    if (file == null || missing.contains(route)) {
      response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType('application', 'problem+json')
        ..write(
          jsonEncode({
            'type': 'urn:gascity:error:not-found',
            'title': 'Not Found',
            'status': 404,
            'detail': 'no route $route',
          }),
        );
    } else {
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(File('${_fixtureDir().path}/$file').readAsStringSync());
    }
    await response.close();
  }
}
