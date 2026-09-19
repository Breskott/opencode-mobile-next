// ignore_for_file: avoid_print
// Live proof of the app's OpenCode 2 client against a real server. Not part of
// the suite: run with
//   OC2_LIVE_URL=http://127.0.0.1:4197 OC2_LIVE_PASSWORD=... \
//     OC2_LIVE_DIR=/abs/project flutter test tool/qa/oc2_live_proof_test.dart
// Each step is reported on its own, so one broken call does not hide the rest.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/api2/gateway.dart';
import 'package:opencode_mobile/api2/gateway_operations.dart';

void main() {
  final url = Platform.environment['OC2_LIVE_URL'];
  final dir = Platform.environment['OC2_LIVE_DIR'];
  final password = Platform.environment['OC2_LIVE_PASSWORD'] ?? '';

  test(
    'the OpenCode 2 client works against a live server',
    () async {
      final results = <String, String>{};
      Future<T?> step<T>(String name, Future<T> Function() run) async {
        try {
          final value = await run().timeout(const Duration(seconds: 90));
          results[name] = 'ok';
          return value;
        } catch (error) {
          results[name] = 'FAILED: ${error.toString().split('\n').first}';
          return null;
        }
      }

      final probe = await step(
        'probe',
        () => serverProbe(
          baseUrl: url!,
          username: 'opencode',
          password: password,
        ),
      );
      print(
        'probe: ok=${probe?.ok} flavor=${probe?.flavor} version=${probe?.version}',
      );

      final gateway = Api2Gateway.connect(
        baseUrl: url!,
        password: password,
        directory: dir,
      );
      final operations = Api2OperationsGateway(client: gateway.client);
      final events = <String>[];
      final idle = Completer<void>();
      String? sessionID;
      final channel = gateway.openEventChannel(
        onEvent: (env) {
          events.add(env.type);
          if (env.type == 'permission.asked' ||
              env.type == 'permission.v2.asked') {
            final id = env.properties['id']?.toString();
            if (id != null) unawaited(gateway.respondPermission(id, 'once'));
          }
          if ((env.type == 'session.idle' ||
                  (env.type == 'session.status' &&
                      env.properties['status'] is Map &&
                      (env.properties['status'] as Map)['type'] == 'idle')) &&
              env.properties['sessionID'] == sessionID &&
              !idle.isCompleted) {
            idle.complete();
          }
        },
        onStatus: (status) => print('stream: $status'),
      )..start();

      final health = await step('health', gateway.health);
      print('health: ${health?.healthy} ${health?.version}');
      final providers = await step('providers', gateway.providers);
      final free = providers?.providers
          .expand((p) => p.modelIDs.map((m) => (p.id, m)))
          .where((m) => m.$2.contains('free'))
          .toList();
      print(
        'models: ${providers?.providers.map((p) => '${p.id}:${p.modelIDs.length}').join(', ')}',
      );
      await step('agents', gateway.agents);
      await step('chat defaults', operations.loadChatDefaults);
      await step('catalog', operations.loadCatalog);
      await step('sessions', gateway.sessions);
      await step('session statuses', gateway.sessionStatuses);
      await step('pending permissions', gateway.pendingPermissions);
      await step('pending forms', gateway.pendingForms);
      await step('projects', operations.listProjects);
      await step('current project', operations.loadCurrentProject);
      await step('commands', operations.listCommands);
      await step('skills', operations.listSkills);
      await step('references', operations.listReferences);
      await step('mcp servers', operations.listMcpServers);
      await step('plugins', operations.listPlugins);
      await step('vcs health', operations.loadVersionControlHealth);
      await step('vcs file statuses', operations.listFileStatuses);
      await step(
        'worktrees',
        () => operations.listWorktrees(projectDirectory: dir!),
      );
      await step('cloud environments', operations.listWorkspaces);
      await step('global sessions', () => operations.listGlobalSessions());
      await step('running shells', operations.loadRunningShells);
      await step('shell identity', operations.managedShellServerIdentity);
      await step('terminals', operations.listTerminals);
      await step('files', () => gateway.listFiles(''));
      await step('read file', () => gateway.fileContent('README.md'));
      await step('find file', () => gateway.findFile('READ'));

      final session = await step('create session', gateway.createSession);
      sessionID = session?.id;
      if (session != null) {
        await step(
          'rename',
          () => gateway.renameSession(session.id, 'live proof'),
        );
        await step(
          'session details',
          () => operations.getSessionDetails(session.id),
        );
        await step(
          'note save',
          () => operations.saveSessionNote(session.id, 'proof note'),
        );
        await step('note load', () => operations.loadSessionNote(session.id));
        await step('inbox', () => gateway.inboxItems(session.id));
        await step('forms', () => gateway.sessionForms(session.id));
        // Free models come and go; OC2_LIVE_MODEL (provider/model) picks one
        // that answers today.
        final wanted = Platform.environment['OC2_LIVE_MODEL'];
        final model = wanted != null && wanted.contains('/')
            ? ModelRef(
                providerID: wanted.split('/').first,
                modelID: wanted.split('/').skip(1).join('/'),
              )
            : free == null || free.isEmpty
            ? null
            : ModelRef(providerID: free.first.$1, modelID: free.first.$2);
        print('prompting with ${model?.providerID}/${model?.modelID}');
        if (model != null) {
          // OpenCode 2 sends with the conversation's own selection.
          await step(
            'set model',
            () => gateway.setSessionModel(session.id, model, ''),
          );
        }
        await step(
          'prompt',
          () => gateway.promptAsync(
            session.id,
            text: 'Reply with exactly the word: pong',
            model: model,
          ),
        );
        await step(
          'turn finishes',
          () => idle.future.timeout(const Duration(seconds: 80)),
        );
        final history = await step(
          'messages',
          () => gateway.messages(session.id),
        );
        for (final m in history ?? const <MessageWithParts>[]) {
          final text = m.parts
              .where((p) => p.type == 'text')
              .map((p) => p.text.replaceAll('\n', ' '))
              .join(' ');
          print(
            '  ${m.info.role}: ${m.parts.map((p) => p.type).join(',')} $text',
          );
        }
        await step(
          'active context',
          () => operations.loadActiveContext(session.id),
        );
        await step('export', () => operations.exportSession(session.id));
        await step(
          'children',
          () => operations.listSessionChildren(session.id),
        );
        await step('todos', () => gateway.todos(session.id));
        await step('diff', () => gateway.diff(session.id));
        await step('abort (idle)', () => gateway.abort(session.id));
        await step('delete session', () => gateway.deleteSession(session.id));
      }
      await channel.dispose();
      gateway.close();

      print('\nevent types seen: ${events.toSet().toList()..sort()}');
      print('\n=== RESULTS');
      for (final entry in results.entries) {
        print(
          '${entry.value == 'ok' ? 'ok    ' : 'BROKEN'} ${entry.key}'
          '${entry.value == 'ok' ? '' : '  -> ${entry.value}'}',
        );
      }
      final broken = results.values.where((v) => v != 'ok').length;
      print('\n$broken of ${results.length} steps broken');
      expect(broken, 0);
    },
    skip: url == null || dir == null
        ? 'set OC2_LIVE_URL and OC2_LIVE_DIR'
        : false,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
