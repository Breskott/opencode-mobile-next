// Shared fixtures for shared-system-1's tests and goldens: a connected
// controller whose API records slash commands, and hosts for the product
// states, the external-link gate and the run-command sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemCommandsRepository implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SystemCommandsApi extends OpenCodeApi {
  SystemCommandsApi() : super(baseUrl: 'http://localhost');

  int creates = 0;
  Completer<void>? submission;
  Object? failure;
  List<Session> seeded = const [];
  final calls = <({String session, String command, String args})>[];

  @override
  Future<ServerPage<Session>> sessionPage({
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: seeded);

  @override
  Future<Map<String, String>> sessionStatuses() async => {};

  @override
  Future<Session> createSession() async {
    creates++;
    return Session(id: 'new-chat');
  }

  @override
  Future<void> slashCommand(
    String sessionID,
    String command,
    String args, {
    ModelRef? model,
    String? variant,
  }) async {
    calls.add((session: sessionID, command: command, args: args));
    if (failure != null) throw failure!;
    await submission?.future;
  }
}

Future<ConnectionController> systemController(SystemCommandsApi api) async {
  SharedPreferences.setMockInitialValues({});
  final controller =
      ConnectionController(
          ProfileStore(prefs: await SharedPreferences.getInstance()),
        )
        ..api = api
        ..repository = SystemCommandsRepository()
        ..status = StreamStatus.connected;
  for (final session in api.seeded) {
    controller.sessionsById[session.id] = session;
  }
  return controller;
}

/// A page with one button that runs [open] from inside the app.
class SystemHost extends StatelessWidget {
  const SystemHost({super.key, required this.open, this.child});

  final FutureOr<void> Function(BuildContext context) open;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('Open it'),
        ),
      ),
      if (child case final child?) Expanded(child: child),
    ],
  );
}
