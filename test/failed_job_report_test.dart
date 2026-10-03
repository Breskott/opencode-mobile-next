import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/builtin/team/builtin_team_job.dart';
import 'package:opencode_mobile/diagnostics/failed_job_report.dart';
import 'package:opencode_mobile/domain/development_service.dart';
import 'package:opencode_mobile/domain/managed_shell.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

SetupProgress setup({
  SetupState state = SetupState.failed,
  String log = 'download failed\nexit 1',
}) => SetupProgress(
  state: state,
  components: const [
    ComponentProgress(id: 'linux', state: ComponentState.done),
    ComponentProgress(
      id: 'opencode',
      state: ComponentState.failed,
      error: 'Could not install',
    ),
  ],
  overall: 0.5,
  jobId: 'setup-1',
  current: 'opencode',
  logTail: log,
);

const work = WorkItem(
  id: 'work-1',
  title: 'Build',
  state: WorkState.failed,
  runId: 'run-1',
  sessionId: 'session-1',
);
const gate = OrchestrationGate(
  id: 'gate-1',
  kind: GateKind.runFailed,
  title: 'Run failed',
  runId: 'run-1',
  workId: 'work-1',
);

DevelopmentService service({bool stopped = false}) => DevelopmentService(
  id: 'dev',
  name: 'Preview',
  command: 'npm run dev',
  directory: '/project',
  url: '',
  run: DevelopmentServiceRun(
    ownerToken: 'fake-owner',
    shellID: 'sh_1',
    startedAt: 1000,
    stopped: stopped,
  ),
);

ManagedShell shell({
  ManagedShellStatus status = ManagedShellStatus.exited,
  int? exitCode = 1,
  String owner = 'fake-owner',
  int startedAt = 1000,
  String command = 'npm run dev',
  String directory = '/project',
  String id = 'sh_1',
}) => ManagedShell(
  id: id,
  command: command,
  directory: directory,
  status: status,
  startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
  ownerToken: owner,
  exitCode: exitCode,
);

void main() {
  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  test('v2 failed row carries the same job log and component reason', () {
    final report = FailedJobReport.setup(setup(), componentId: 'opencode')!;
    expect(report.kind, FailedJobKind.setup);
    expect(report.jobId, 'setup-1');
    expect(report.title, 'opencode');
    expect(report.detail, 'Could not install');
    expect(report.logExcerpt, 'download failed\nexit 1');
    expect(report.preview, contains(report.logExcerpt));
    expect(FailedJobReport.setup(setup(), componentId: 'linux'), isNull);
    expect(FailedJobReport.setup(setup(), componentId: 'missing'), isNull);
  });

  test('OCTRACE timing lines never land in a failed job\'s log excerpt', () {
    final report = FailedJobReport.setup(
      setup(
        log:
            'OCTRACE 2.9ms linux.setupStatus\n'
            '[oc] What OpenCode said:\n'
            '  Error: Failed to start server\n'
            '[oc] OpenCode was installed but did not start\n'
            '[2026-09-28 10:00:00 UTC] timing · OCTRACE\n'
            'OCTRACE 3.1ms linux.setupStatus\n',
      ),
    )!;
    expect(report.logExcerpt, isNot(contains('OCTRACE')));
    expect(
      report.logExcerpt.split('\n').last,
      '[oc] OpenCode was installed but did not start',
    );
  });

  test('successful, active and interrupted setup do not claim failure', () {
    for (final state in SetupState.values.where(
      (s) => s != SetupState.failed,
    )) {
      expect(FailedJobReport.setup(setup(state: state)), isNull);
    }
    expect(FailedJobReport.setup(setup(log: ''))!.hasLog, isFalse);
  });

  test('redacts full multiline input before line or character truncation', () {
    KitRedact.registerKnownSecret('fake-loaded-credential');
    final report = FailedJobReport.setup(
      setup(
        log: [
          'password="${List.filled(140, 'synthetic secret').join('\n')}"',
          '-----BEGIN PRIVATE KEY-----',
          'synthetic-private-key-body',
          '-----END PRIVATE KEY-----',
          '\x1b[31mBearer synthetic-bearer\x1b[0m',
          'fake-loaded-credential',
          'error at /work/project/main.dart',
        ].join('\n'),
      ),
    )!;
    expect(report.logExcerpt.contains('synthetic'), isFalse);
    expect(report.preview.contains('fake-loaded-credential'), isFalse);
    expect(report.logExcerpt, contains(KitRedact.mask));
    expect(report.logExcerpt, contains('/work/project/main.dart'));
    expect(report.logExcerpt.contains('\x1b'), isFalse);
  });

  test('excerpt keeps a bounded tail, including a single huge line', () {
    final lines = List.generate(200, (i) => 'line $i');
    final report = FailedJobReport.setup(setup(log: lines.join('\n')))!;
    expect(report.logExcerpt.split('\n').length, 120);
    expect(report.logExcerpt.startsWith('line 80\n'), isTrue);
    expect(report.logExcerpt.endsWith('line 199'), isTrue);
    final large = FailedJobReport.setup(setup(log: '${'x' * 20000}END'))!;
    expect(large.logExcerpt.length, FailedJobReport.maxLogCharacters);
    expect(large.logExcerpt.endsWith('END'), isTrue);
  });

  test('team work and gate attach only the linked session excerpt', () {
    final report = FailedJobReport.teamGate(
      gate,
      work: work,
      sessionId: 'session-1',
      logTail: 'test failed',
    )!;
    expect(report.kind, FailedJobKind.teamRun);
    expect(report.jobId, 'run-1');
    expect(report.logExcerpt, 'test failed');
    expect(
      FailedJobReport.teamWork(
        work,
        sessionId: 'session-1',
        logTail: 'test failed',
      )!.logExcerpt,
      'test failed',
    );
    for (final session in [null, '', 'reused-agent-new-session']) {
      expect(
        FailedJobReport.teamGate(
          gate,
          work: work,
          sessionId: session,
          logTail: 'unrelated',
        )!.hasLog,
        isFalse,
      );
      expect(
        FailedJobReport.teamWork(
          work,
          sessionId: session,
          logTail: 'unrelated',
        )!.hasLog,
        isFalse,
      );
    }
    final unavailable = FailedJobReport.teamGate(gate)!;
    expect(unavailable.hasLog, isFalse);
    expect(unavailable.preview, contains('Log excerpt: unavailable'));
  });

  test('gate rejects unrelated work and never copies raw provider payload', () {
    const unrelated = WorkItem(
      id: 'other',
      title: 'Other',
      state: WorkState.failed,
      runId: 'other-run',
      sessionId: 'session-1',
    );
    expect(
      FailedJobReport.teamGate(
        gate,
        work: unrelated,
        sessionId: 'session-1',
        logTail: 'wrong log',
      )!.hasLog,
      isFalse,
    );
    const runGate = OrchestrationGate(
      id: 'g',
      kind: GateKind.runFailed,
      title: 'password=synthetic-title',
      runId: 'run-1',
      prompt: 'token=synthetic-prompt',
      raw: {'private': 'never-export-this'},
    );
    final report = FailedJobReport.teamGate(
      runGate,
      work: work,
      sessionId: 'session-1',
      logTail: 'correct',
    )!;
    expect(report.logExcerpt, 'correct');
    expect(report.preview.contains('synthetic'), isFalse);
    expect(report.preview.contains('never-export-this'), isFalse);
    expect(
      FailedJobReport.teamGate(
        const OrchestrationGate(
          id: 'g',
          kind: GateKind.confirmation,
          title: 'Confirm',
        ),
      ),
      isNull,
    );
    expect(
      FailedJobReport.teamWork(
        const WorkItem(id: 'w', title: 'Done', state: WorkState.completed),
      ),
      isNull,
    );
  });

  test(
    'built-in team failed job carries redacted exception log until cleared',
    () async {
      final job = BuiltinTeamJob();
      addTearDown(job.dispose);
      expect(FailedJobReport.teamSetup(job), isNull);
      await job.run(
        stages: const [],
        work: (_) async {
          expect(FailedJobReport.teamSetup(job), isNull);
          throw BuiltinTeamException(
            BuiltinTeamStage.values.first,
            'start failed\npassword=synthetic-password',
          );
        },
      );
      final report = FailedJobReport.teamSetup(job)!;
      expect(report.kind, FailedJobKind.teamSetup);
      expect(report.logExcerpt, contains('start failed'));
      expect(report.logExcerpt.contains('synthetic-password'), isFalse);
      job.clearError();
      expect(FailedJobReport.teamSetup(job), isNull);
      expect(report.logExcerpt, contains('start failed'));
    },
  );

  test('dev report requires exact owned run and an observed failure', () {
    final report = FailedJobReport.developmentService(
      service(),
      shell(),
      logTail: 'failed\npassword=synthetic-password',
    )!;
    expect(report.logExcerpt, 'failed\npassword=${KitRedact.mask}');
    expect(report.detail, 'exited (exit 1)');
    expect(report.preview.contains('fake-owner'), isFalse);
    expect(report.preview.contains('npm run dev'), isFalse);
    for (final wrong in [
      shell(owner: 'other'),
      shell(startedAt: 2000),
      shell(command: 'other'),
      shell(directory: '/other'),
      shell(id: 'sh_2'),
    ]) {
      expect(FailedJobReport.developmentService(service(), wrong), isNull);
    }
    expect(
      FailedJobReport.developmentService(service(stopped: true), shell()),
      isNull,
    );
    for (final state in [
      ManagedShellStatus.running,
      ManagedShellStatus.unknown,
    ]) {
      expect(
        FailedJobReport.developmentService(service(), shell(status: state)),
        isNull,
      );
    }
    for (final code in [0, null]) {
      expect(
        FailedJobReport.developmentService(service(), shell(exitCode: code)),
        isNull,
      );
    }
    for (final state in [
      ManagedShellStatus.timeout,
      ManagedShellStatus.killed,
    ]) {
      expect(
        FailedJobReport.developmentService(
          service(),
          shell(status: state, exitCode: null),
        )!.hasLog,
        isFalse,
      );
    }
  });
}
