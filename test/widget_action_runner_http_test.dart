import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/widget_action_runner.dart';
import 'package:opencode_mobile/background/widget_v2_contract.dart';
import 'package:opencode_mobile/state/profiles.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stable in [true, false]) {
    for (final kind in ['allowOnce', 'reject']) {
      test('cold OC2 ${stable ? 'stable' : 'beta'} $kind uses the negotiated '
          'permission body and clears only the answered request', () async {
        await HttpOverrides.runZoned(
          () async {
            final server = await HttpServer.bind(
              InternetAddress.loopbackIPv4,
              0,
            );
            final seen = <String>[];
            final replies = <Object?>[];
            final queries = <Map<String, String>>[];
            var pending = true;
            const sessionID = 'ses_widget_test';
            const requestID = 'per_widget_test';
            final decision = kind == 'allowOnce' ? 'once' : 'reject';
            server.listen((request) async {
              final path = request.uri.path;
              seen.add('${request.method} $path');
              final response = request.response
                ..headers.contentType = ContentType.json;
              Object? body = <String, Object?>{};
              if (path == '/api/health' && !stable) {
                body = {'healthy': true, 'version': '0.0.0-beta-18600'};
              } else if (path == '/api/info' && stable) {
                body = {'version': '2.0.29'};
              } else if (path == '/api/permission/request') {
                queries.add(request.uri.queryParameters);
                body = {
                  'data': [
                    if (pending)
                      {
                        'id': requestID,
                        'sessionID': sessionID,
                        'action': 'shell',
                        'resources': ['sleep 50'],
                      },
                  ],
                };
              } else if (path ==
                      '/api/session/$sessionID/permission/$requestID/reply' &&
                  request.method == 'POST') {
                final reply = jsonDecode(
                  await utf8.decoder.bind(request).join(),
                );
                replies.add(reply);
                if (reply is Map &&
                    reply.length == 1 &&
                    reply[stable ? 'decision' : 'reply'] == decision) {
                  pending = false;
                  response.statusCode = HttpStatus.noContent;
                  body = null;
                } else {
                  response.statusCode = HttpStatus.badRequest;
                }
              } else {
                response.statusCode = HttpStatus.notFound;
              }
              if (body != null) response.write(jsonEncode(body));
              await response.close();
            });
            final profile = ServerProfile(
              id: 'profile',
              name: 'Synthetic server',
              baseUrl: 'http://127.0.0.1:${server.port}',
              flavor: ServerFlavor.v2,
              // Cached version must not substitute for a fresh negotiation.
              serverVersion: stable ? '0.0.0-beta-18600' : '2.0.29',
            );
            final fingerprint = widgetProfileFingerprint(profile);
            final snapshot = <String, dynamic>{
              'version': 2,
              'profileID': profile.id,
              'scopeToken': 'scope',
              'connected': false,
              'pendingCount': 2,
              'runningCount': 1,
              'onDemand': {'fingerprint': fingerprint},
              'sessions': [
                {
                  'id': sessionID,
                  'busy': true,
                  'requestID': requestID,
                  'onDemandActions': ['allowOnce', 'reject'],
                },
                {
                  'id': 'ses_other',
                  'requestID': 'per_other',
                  'onDemandActions': ['allowOnce', 'reject'],
                },
              ],
            };
            final runner = WidgetActionRunner(
              loadProfile: (_) async => profile,
              loadTarget: (_, _) async => {
                'profileID': profile.id,
                'scopeToken': 'scope',
                'fingerprint': fingerprint,
                'directory': '/synthetic/project',
                'workspace': 'wrk_test',
              },
              isCurrent: (_, _) async => true,
              // Deliberately use the production factory, client and gateway.
            );
            try {
              final result = await runner.execute(
                WidgetAction(
                  id: 'tap',
                  action: kind,
                  profileID: profile.id,
                  scopeToken: 'scope',
                  sessionID: sessionID,
                  requestID: requestID,
                ),
                snapshot,
                DateTime.now()
                    .add(const Duration(seconds: 10))
                    .millisecondsSinceEpoch,
              );
              expect(replies, [
                {stable ? 'decision' : 'reply': decision},
              ]);
              expect(result['status'], 'accepted');
              expect(pending, isFalse);
              expect(seen, [
                'GET /api/health',
                if (stable) ...['GET /api/info', 'GET /api/info'],
                'GET /api/permission/request',
                'POST /api/session/$sessionID/permission/$requestID/reply',
              ]);
              expect(queries.single, {
                'location[directory]': '/synthetic/project',
                'location[workspace]': 'wrk_test',
              });
              final updated = result['snapshot'] as Map;
              expect(updated['pendingCount'], 1);
              final rows = updated['sessions'] as List;
              expect((rows.first as Map).containsKey('requestID'), isFalse);
              expect(rows.last, (snapshot['sessions'] as List).last);
              // Duplicate delivery of the same tap cannot send another reply.
              await runner.execute(
                WidgetAction(
                  id: 'tap',
                  action: kind,
                  profileID: profile.id,
                  scopeToken: 'scope',
                  sessionID: sessionID,
                  requestID: requestID,
                ),
                snapshot,
                DateTime.now().millisecondsSinceEpoch + 10000,
              );
              expect(replies, hasLength(1));
            } finally {
              runner.cancel();
              await server.close(force: true);
            }
          },
          createHttpClient: (_) => _RealHttpOverrides().createHttpClient(null),
        );
      });
    }
  }
}
