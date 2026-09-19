// ignore_for_file: avoid_print
// Live proof against a real Paseo daemon. Not part of the suite: run with
//   PASEO_LIVE_URL=ws://127.0.0.1:6790 PASEO_LIVE_DIR=/abs/project \
//     flutter test tool/qa/paseo_live_proof_test.dart
// Optional: PASEO_LIVE_PASSWORD, PASEO_LIVE_MODEL (provider/model).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/paseo/gateway.dart';

void main() {
  final url = Platform.environment['PASEO_LIVE_URL'];
  final dir = Platform.environment['PASEO_LIVE_DIR'];
  test(
    'a Claude conversation runs end to end through the gateway',
    () async {
      final gateway = PaseoGateway.connect(
        baseUrl: url!,
        password: Platform.environment['PASEO_LIVE_PASSWORD'] ?? '',
        directory: dir,
      );
      final log = <String>[];
      final idle = Completer<void>();
      String? sessionID;
      final channel = gateway.openEventChannel(
        onEvent: (env) {
          final p = env.properties;
          var line = env.type;
          if (env.type == 'message.part.delta') line += ' ${p['delta']}';
          if (env.type == 'message.part.updated') {
            final part = p['part'] as Map;
            line +=
                ' ${part['type']} ${part['tool'] ?? ''} '
                '${(part['state'] as Map?)?['status'] ?? ''} '
                '${part['text'] ?? ''}';
          }
          if (env.type == 'permission.asked') {
            line +=
                ' ${p['permission']} ${p['patterns']} always=${p['always']}';
            unawaited(gateway.respondPermission(p['id'] as String, 'once'));
          }
          if (env.type == 'session.error') line += ' ${p['error']}';
          log.add(line);

          print(line);
          if (env.type == 'session.idle' &&
              p['sessionID'] == sessionID &&
              !idle.isCompleted) {
            idle.complete();
          }
        },
        onStatus: (s) => print('stream: $s'),
      )..start();

      final health = await gateway.health();
      print(health.version);
      final providers = await gateway.providers();
      for (final p in providers.providers) {
        print('provider ${p.id}: ${p.modelIDs.take(6).join(', ')}');
      }
      final agents = await gateway.agents();
      print('modes: ${agents.map((a) => a.name).join(', ')}');
      final defaults = await gateway.loadChatDefaults();

      print(
        'defaults: ${defaults.model?.providerID}/${defaults.model?.modelID} ${defaults.agent}',
      );

      final before = await gateway.sessions();
      print('sessions before: ${before.length}');

      final session = await gateway.createSession();
      sessionID = session.id;
      final wanted = Platform.environment['PASEO_LIVE_MODEL'];
      final model = wanted == null
          ? defaults.model
          : ModelRef(
              providerID: wanted.split('/').first,
              modelID: wanted.split('/').skip(1).join('/'),
            );
      addTearDown(
        () => print('daemon said: ${gateway.transport.lastDaemonError}'),
      );
      await gateway.promptAsync(
        session.id,
        text:
            'Create the file proof.txt containing the word proof, '
            'then reply with exactly: done',
        model: model,
        agent: 'default',
      );
      await idle.future.timeout(const Duration(minutes: 3));

      final history = await gateway.messages(session.id);
      for (final m in history) {
        final part = m.parts.first;

        print(
          'H ${m.info.role} ${m.info.id} ${part.type} '
          '${part.toolName ?? ''} ${part.text.replaceAll('\n', ' ')}',
        );
      }
      expect(history.first.info.role, 'user');
      expect(history.last.info.role, 'assistant');
      expect(log.any((l) => l.startsWith('permission.asked edit')), isTrue);
      expect(File('$dir/proof.txt').existsSync(), isTrue);

      final after = await gateway.sessions();
      expect(after.any((s) => s.id == session.id), isTrue);
      await gateway.deleteSession(session.id);
      expect(
        (await gateway.sessions()).any((s) => s.id == session.id),
        isFalse,
      );
      await channel.dispose();
      gateway.close();
    },
    skip: url == null || dir == null
        ? 'set PASEO_LIVE_URL and PASEO_LIVE_DIR'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
