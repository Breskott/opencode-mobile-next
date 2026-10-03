import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/development_service.dart';
import 'package:opencode_mobile/domain/managed_shell.dart';
import 'package:opencode_mobile/state/development_service_store.dart';
import 'package:opencode_mobile/state/development_services.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/development_service_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late ServiceRepository gateway;
  late DevelopmentServices model;
  var current = true;
  var supported = true;

  setUp(() async {
    KitRedact.clearKnownSecrets();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    gateway = ServiceRepository();
    current = supported = true;
    model = DevelopmentServices(
      store: DevelopmentServiceStore(
        preferences: preferences,
        profileID: 'p84',
        canWrite: () => true,
      ),
      directory: sampleService.directory,
      workspace: null,
      resolveGateway: () async => gateway,
      isCurrent: () => current,
      supported: () => supported,
    );
    await model.register(sampleService);
    await model.start(sampleService.id);
  });

  tearDown(() {
    model.dispose();
    KitRedact.clearKnownSecrets();
  });

  void failShell({String? owner}) {
    final previous = gateway.shells['sh_1']!;
    gateway.shells['sh_1'] = ManagedShell(
      id: previous.id,
      command: previous.command,
      directory: previous.directory,
      ownerToken: owner ?? previous.ownerToken,
      startedAt: previous.startedAt,
      status: ManagedShellStatus.exited,
      exitCode: 2,
    );
  }

  test(
    'failed service exposes preview after owned log read without persisting it',
    () async {
      expect(model.failedReport('vite'), isNull);
      failShell();
      await model.refresh();
      expect(model.failedReport('vite')!.hasLog, isFalse);
      final stored = preferences.getString('oc.developmentServices.p84');
      gateway.output = 'build failed\npassword=synthetic-password';
      await model.readLogs('vite');
      final report = model.failedReport('vite')!;
      expect(report.logExcerpt, 'build failed\npassword=${KitRedact.mask}');
      expect(report.detail, 'exited (exit 2)');
      expect(preferences.getString('oc.developmentServices.p84'), stored);
      expect(gateway.starts, 1);
      expect(gateway.stops, isEmpty);
      expect(model.failedReport('missing'), isNull);
      await model.start('vite');
      expect(model.failedReport('vite'), isNull);
      expect(report.logExcerpt, contains('build failed'));
    },
  );

  test('scope change and lost ownership cannot attach a cached log', () async {
    failShell();
    await model.readLogs('vite');
    expect(model.failedReport('vite')!.hasLog, isTrue);
    current = false;
    expect(model.failedReport('vite'), isNull);
    current = true;
    supported = false;
    expect(model.failedReport('vite'), isNull);
    supported = true;
    failShell(owner: 'different-owner');
    await model.readLogs('vite');
    expect(model.failedReport('vite'), isNull);
    expect(model.logs.containsKey('vite'), isFalse);
  });

  test('invalidation discards a pending read and its report', () async {
    failShell();
    await model.refresh();
    gateway.infoGate = Completer<void>();
    final pending = model.readLogs('vite');
    model.invalidateRuntime();
    gateway.infoGate!.complete();
    await pending;
    expect(model.failedReport('vite'), isNull);
    expect(model.logs, isEmpty);
  });

  test('failed log refresh cannot reuse a previous excerpt', () async {
    failShell();
    await model.readLogs('vite');
    gateway.failReads = true;
    await model.readLogs('vite');
    expect(model.logs.containsKey('vite'), isFalse);
    expect(model.failedReport('vite'), isNull);
  });

  test(
    'a replaced receipt cannot reuse the prior run log after refresh',
    () async {
      failShell();
      gateway.output = 'old run failure';
      await model.readLogs('vite');
      final replacement = ManagedShell(
        id: 'sh_new',
        command: sampleService.command,
        directory: sampleService.directory,
        ownerToken: 'replacement-owner',
        startedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        status: ManagedShellStatus.exited,
        exitCode: 3,
      );
      gateway.shells[replacement.id] = replacement;
      await model.store.updateRun(
        'vite',
        const DevelopmentServiceRun(
          ownerToken: 'replacement-owner',
          shellID: 'sh_new',
          startedAt: 2000,
        ),
      );
      await model.refresh();
      final report = model.failedReport('vite')!;
      expect(report.jobId, 'sh_new');
      expect(report.hasLog, isFalse);
      gateway.output = 'new run failure';
      await model.readLogs('vite');
      expect(model.failedReport('vite')!.logExcerpt, 'new run failure');
    },
  );
}
