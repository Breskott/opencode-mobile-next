// Census scenes for the ledger part `f-files-review-terminal`
// (docs/design/ui-ledger/parts/f-files-review-terminal.json). See tool/capture/census_test.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/review_handoff.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/review_workspace.dart';
import 'package:opencode_mobile/ui/screens/staged_revert_screen.dart';
import 'package:opencode_mobile/ui/screens/terminal_screen.dart';
import 'package:opencode_mobile/ui/widgets/file_preview.dart';
import 'package:opencode_mobile/ui/widgets/run_command_dialog.dart';

import '../../fixtures.dart';
import '../census_core.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

const _bloc =
    'class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {\n'
    '  Future<void> _onApplyCoupon(\n'
    '    ApplyCoupon event,\n'
    '    Emitter<CheckoutState> emit,\n'
    '  ) async {\n'
    '    emit(state.copyWith(status: CheckoutStatus.applying));\n'
    '    final total = await _repository.applyCoupon(event.code);\n'
    '    emit(state.copyWith(total: total, status: CheckoutStatus.settled));\n'
    '  }\n'
    '}\n';

const _readme =
    '# shopfront\n\nThe storefront checkout app.\n\n'
    '## Getting started\n\n```\nflutter pub get\nflutter test\n```\n';

/// A project file tree: two folders, a handful of files, some with VCS
/// status so the Changes card and row badges have something to show.
class _FilesApi extends CaptureApi {
  _FilesApi({this.empty = false, this.failing = false});
  final bool empty;
  final bool failing;

  @override
  Future<List<FileNode>> listFiles([String path = '']) async {
    if (failing) throw const ProductException('Could not list files.');
    if (empty) return const [];
    switch (path) {
      case 'src':
        return [
          FileNode(name: 'main.dart', path: 'src/main.dart', isDir: false),
        ];
      case 'lib':
        return [FileNode(name: 'checkout', path: 'lib/checkout', isDir: true)];
      case 'lib/checkout':
        return [
          FileNode(
            name: 'checkout_bloc.dart',
            path: 'lib/checkout/checkout_bloc.dart',
            isDir: false,
          ),
        ];
      default:
        return [
          for (final name in ['.git', 'lib', 'src', 'test'])
            FileNode(name: name, path: name, isDir: true),
          for (final name in ['.gitignore', 'pubspec.yaml', 'README.md'])
            FileNode(name: name, path: name, isDir: false),
        ];
    }
  }

  @override
  Future<FileContent> fileContent(String path) async => switch (path) {
    'README.md' => FileContent(_readme, mimeType: 'text/markdown'),
    'lib/checkout/checkout_bloc.dart' => FileContent(_bloc),
    _ => Future.error(StateError('no fixture for $path')),
  };
}

class _FilesRepository extends CaptureRepository {
  _FilesRepository({this.empty = false});
  final bool empty;

  @override
  Future<List<VersionControlFile>> listFileStatuses() async => empty
      ? const []
      : const [
          VersionControlFile(
            path: 'lib/checkout/checkout_bloc.dart',
            status: 'modified',
            additions: 6,
            deletions: 2,
          ),
          VersionControlFile(
            path: 'test/checkout_test.dart',
            status: 'modified',
            additions: 5,
            deletions: 2,
          ),
          VersionControlFile(
            path: 'lib/checkout/coupon_banner.dart',
            status: 'added',
            additions: 40,
            deletions: 0,
          ),
        ];
}

/// A terminal repository with a small process list and a channel that
/// replays a short recorded session as soon as something listens.
class _TerminalRepository extends CaptureRepository {
  _TerminalRepository({List<TerminalProcess>? processes, this.failing = false})
    : processes = processes ?? _defaultProcesses();
  final List<TerminalProcess> processes;
  final bool failing;

  static List<TerminalProcess> _defaultProcesses() => [
    const TerminalProcess(
      id: 'term_tests',
      title: 'flutter test',
      command: 'flutter test test/checkout_test.dart',
      arguments: [],
      directory: projectDirectory,
      running: true,
      pid: 4821,
    ),
    const TerminalProcess(
      id: 'term_build',
      title: 'flutter build',
      command: 'flutter build apk --release',
      arguments: [],
      directory: projectDirectory,
      running: false,
      pid: 4790,
      exitCode: 0,
    ),
  ];

  @override
  Future<List<TerminalProcess>> listTerminals() async {
    if (failing) throw const ProductException('Could not list terminals.');
    return processes;
  }

  @override
  Future<TerminalProcess> createTerminal({String? title}) async {
    final process = TerminalProcess(
      id: 'term_new',
      title: title ?? 'Terminal ${processes.length + 1}',
      command: 'bash',
      arguments: const [],
      directory: projectDirectory,
      running: true,
      pid: 5000,
    );
    processes.add(process);
    return process;
  }

  @override
  Future<void> renameTerminal(String id, String title) async {}

  @override
  Future<void> resizeTerminal(
    String id, {
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<void> removeTerminal(String id) async {}

  @override
  Future<TerminalChannel> connectTerminal(String id, {int? cursor}) async {
    final channel = _FakeTerminalChannel();
    channel.emit(
      'shopfront on  main\n'
      '\$ flutter test test/checkout_test.dart\n'
      '00:03 +0: applies a coupon to the total\n'
      '00:04 +1: keeps the total when the coupon is invalid\n'
      '00:05 +2: clears the cart after payment\n'
      '00:06 +12: All tests passed!\n'
      'shopfront on  main\n\$ ',
    );
    return channel;
  }
}

class _FakeTerminalChannel extends TerminalChannel {
  final _controller = StreamController<String>();
  @override
  Stream<String> get output => _controller.stream;
  @override
  void write(String value) {}
  @override
  Future<void> close() async => _controller.close();
  void emit(String text) => _controller.add(text);
}

/// A repository that also answers the staged-revert questions review needs.
class _RevertRepository extends CaptureRepository
    implements StagedRevertGateway {
  @override
  Future<String?> sessionRevertPrompt(String id, String messageID) async =>
      'Keep the greeting concise.';

  @override
  Future<SessionRevert> stageSessionRevert(
    String id,
    String messageID, {
    required bool applyFiles,
  }) async => SessionRevert(messageID: messageID, files: sampleDiffs());

  @override
  Future<void> commitSessionRevert(String id) async {}

  @override
  Future<void> clearSessionRevert(String id) async {}
}

Session _revertSession() => sampleSessions()[checkoutSessionID]!.copyWith(
  stagedRevert: SessionRevert(messageID: 'msg_assistant', files: sampleDiffs()),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<CaptureController> _projectTab(
  CensusKit kit, {
  CaptureApi? api,
  CaptureRepository? repository,
}) async {
  final controller = await kit.connected(api: api, repository: repository);
  await kit.pumpApp(const HomeScreen(), controller: controller);
  await kit.tapText('Project');
  return controller;
}

Future<CaptureController> _filesTab(
  CensusKit kit, {
  CaptureApi? api,
  CaptureRepository? repository,
}) async {
  final controller = await _projectTab(kit, api: api, repository: repository);
  await kit.tapKey('project-hub-files');
  return controller;
}

/// A stand-alone screen pumped as the app's home, the way review/terminal are
/// pushed over the shell in the real app.
Future<CaptureController> _standalone(
  CensusKit kit,
  Widget Function(ConnectionController controller) build, {
  CaptureApi? api,
  CaptureRepository? repository,
}) async {
  final controller = await kit.connected(api: api, repository: repository);
  await kit.pumpApp(build(controller), controller: controller);
  return controller;
}

/// A minimal backdrop screen for a dialog/sheet whose real opener lives on
/// several unrelated screens; names the kind of screen it would sit over.
Widget _backdrop(String title) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: const SizedBox.shrink(),
);

// ---------------------------------------------------------------------------
// Shots
// ---------------------------------------------------------------------------

final fFilesReviewTerminalArea = CensusArea(
  'f-files-review-terminal',
  shots: [
    // -- project hub ---------------------------------------------------------
    CensusShot('project-hub', (kit) async {
      await _projectTab(kit);
      kit.expectText('Files');
      kit.expectText('Terminal');
    }),

    // -- files ----------------------------------------------------------------
    CensusShot('files', state: 'loaded', (kit) async {
      await _filesTab(kit, api: _FilesApi(), repository: _FilesRepository());
      kit.expectText('README.md');
      kit.expectVisible(find.byKey(const ValueKey('files-changes-card')));
    }),
    CensusShot('files', state: 'empty', (kit) async {
      await _filesTab(
        kit,
        api: _FilesApi(empty: true),
        repository: _FilesRepository(empty: true),
      );
      kit.expectText('Folder is empty');
    }),
    CensusShot('files', state: 'error', (kit) async {
      await _filesTab(kit, api: _FilesApi(failing: true));
      kit.expectTextContaining("Couldn't");
    }, note: 'the error state from a listFiles failure.'),

    // -- files-row-actions-sheet -----------------------------------------------
    CensusShot('files-row-actions-sheet', (kit) async {
      await _filesTab(kit, api: _FilesApi(), repository: _FilesRepository());
      await kit.tapKey('project-file-actions-README.md');
      kit.expectVisible(find.byKey(const ValueKey('file-row-actions-sheet')));
      kit.expectText('README.md');
    }),

    // -- files-file-viewer-sheet -------------------------------------------------
    CensusShot('files-file-viewer-sheet', state: 'markdown', (kit) async {
      await _filesTab(kit, api: _FilesApi(), repository: _FilesRepository());
      await kit.tapKey('project-file-README.md');
      kit.expectText('README.md');
      kit.expectVisible(find.byKey(const ValueKey('project-file-download')));
    }),
    CensusShot('files-file-viewer-sheet', state: 'code', (kit) async {
      await _filesTab(kit, api: _FilesApi(), repository: _FilesRepository());
      await kit.tapText('lib');
      await kit.tapText('checkout');
      await kit.tapText('checkout_bloc.dart');
      kit.expectText('checkout_bloc.dart');
      kit.expectTextContaining('CheckoutBloc');
    }),

    // -- review-workspace --------------------------------------------------------
    CensusShot('review-workspace', state: 'loaded', (kit) async {
      final handoff = ReviewHandoffSession(
        store: ReviewHandoffStore(),
        sessionID: checkoutSessionID,
      );
      await _standalone(
        kit,
        (controller) => ReviewWorkspace(
          loadDiffs: () async => sampleDiffs(),
          loadWorkingTreeDiffs: () async => sampleDiffs(),
          handoff: handoff,
        ),
      );
      kit.expectText('Review changes');
      kit.expectTextContaining('checkout_test.dart');
    }),
    CensusShot('review-workspace', state: 'empty', (kit) async {
      await _standalone(
        kit,
        (controller) => ReviewWorkspace(loadDiffs: () async => const []),
      );
      kit.expectText('Review changes');
    }),
    CensusShot('review-workspace', state: 'error', (kit) async {
      await _standalone(
        kit,
        (controller) => ReviewWorkspace(
          loadDiffs: () async =>
              throw const ProductException('Could not read the diff.'),
        ),
      );
      kit.expectVisible(find.byKey(const ValueKey('review-error')));
    }),

    // -- review-comment-sheet ------------------------------------------------
    CensusShot('review-comment-sheet', (kit) async {
      await _standalone(
        kit,
        (controller) => ReviewWorkspace(loadDiffs: () async => sampleDiffs()),
      );
      await kit.tapKey('review-file-actions');
      await kit.tapText('Ask about file');
      kit.expectVisible(find.byKey(const ValueKey('review-comment-field')));
      kit.expectText('Comment on change');
    }),

    // -- terminal --------------------------------------------------------------
    CensusShot('terminal', state: 'populated', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(),
      );
      kit.expectText('flutter test');
      kit.expectText('flutter build');
    }),
    CensusShot('terminal', state: 'empty', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(processes: []),
      );
      kit.expectText('No terminal processes');
    }),
    CensusShot('terminal', state: 'failed', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(failing: true),
      );
      kit.expectTextContaining("Couldn't list");
    }),

    // -- terminal-rename-dialog ------------------------------------------------
    CensusShot('terminal-rename-dialog', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(),
      );
      await kit.tap(find.byTooltip('Terminal actions').first);
      await kit.tapText('Rename');
      kit.expectText('Rename terminal');
    }),

    // -- terminal-remove-sheet ---------------------------------------------------
    CensusShot('terminal-remove-sheet', state: 'stop-running', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(),
      );
      await kit.tap(find.byTooltip('Terminal actions').at(0));
      await kit.tapText('Stop');
      kit.expectText('Stop terminal?');
    }),
    CensusShot('terminal-remove-sheet', state: 'remove-exited', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(),
      );
      await kit.tap(find.byTooltip('Terminal actions').at(1));
      await kit.tapText('Remove');
      kit.expectText('Remove terminal?');
    }),

    // -- terminal-surface --------------------------------------------------------
    CensusShot('terminal-surface', state: 'connected', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(),
      );
      await kit.tapText('flutter test');
      kit.expectVisible(find.byKey(const ValueKey('terminal-accessible-mode')));
    }),
    CensusShot('terminal-surface', state: 'accessible', (kit) async {
      await _standalone(
        kit,
        (controller) =>
            TerminalPage(controller: controller, localSupported: false),
        repository: _TerminalRepository(),
      );
      await kit.tapText('flutter test');
      await kit.tapKey('terminal-accessible-mode');
      kit.expectVisible(
        find.byKey(const ValueKey('terminal-accessible-input')),
      );
    }),

    // -- stage-revert-sheet ----------------------------------------------------
    CensusShot('stage-revert-sheet', (kit) async {
      final controller = await kit.connected();
      controller.busySessions.clear();
      controller.sessionsById[checkoutSessionID] = _revertSession();
      await kit.pumpApp(
        _backdrop('Fix flaky checkout test'),
        controller: controller,
      );
      await kit.present(
        (context) => showStageRevertSheet(
          context,
          controller: controller,
          review: controller.reviewSessionRevert(checkoutSessionID),
          prompt: 'Keep the greeting concise.',
        ),
      );
      kit.expectText('Stage a revert from this prompt?');
    }),

    // -- staged-revert -----------------------------------------------------------
    CensusShot('staged-revert', (kit) async {
      final api = CaptureApi()
        ..busy = {}
        ..sessionsById[checkoutSessionID] = _revertSession();
      await _standalone(
        kit,
        (controller) => StagedRevertScreen(
          controller: controller,
          sessionID: checkoutSessionID,
        ),
        api: api,
        repository: _RevertRepository(),
      );
      kit.expectText('Review staged revert');
      kit.expectVisible(find.byKey(const ValueKey('commit-staged-revert')));
    }),

    // -- staged-revert-confirm-sheet -----------------------------------------------
    CensusShot('staged-revert-confirm-sheet', state: 'commit', (kit) async {
      final api = CaptureApi()
        ..busy = {}
        ..sessionsById[checkoutSessionID] = _revertSession();
      await _standalone(
        kit,
        (controller) => StagedRevertScreen(
          controller: controller,
          sessionID: checkoutSessionID,
        ),
        api: api,
        repository: _RevertRepository(),
      );
      await kit.tapKey('commit-staged-revert');
      kit.expectText('Make this revert permanent?');
    }),
    CensusShot('staged-revert-confirm-sheet', state: 'clear', (kit) async {
      final api = CaptureApi()
        ..busy = {}
        ..sessionsById[checkoutSessionID] = _revertSession();
      await _standalone(
        kit,
        (controller) => StagedRevertScreen(
          controller: controller,
          sessionID: checkoutSessionID,
        ),
        api: api,
        repository: _RevertRepository(),
      );
      await kit.tapKey('clear-staged-revert');
      kit.expectText('Clear this staged revert?');
    }),

    // -- file-preview-sheet -------------------------------------------------------
    CensusShot('file-preview-sheet', state: 'markdown', (kit) async {
      final controller = await kit.connected();
      await kit.pumpApp(
        _backdrop('Fix flaky checkout test'),
        controller: controller,
      );
      await kit.present(
        (context) => showFilePreviewSheet(
          context,
          FilePreviewData(name: 'README.md', text: _readme),
          onAttach: () async {},
          onDownload: () async {},
        ),
      );
      kit.expectText('README.md');
      kit.expectVisible(find.byTooltip('Attach to prompt'));
    }),

    // -- embedded-file-preview-body -----------------------------------------------
    CensusShot(
      'embedded-file-preview-body',
      (kit) async {
        final controller = await kit.connected();
        await kit.pumpApp(
          _backdrop('Fix flaky checkout test'),
          controller: controller,
        );
        await kit.present(
          (context) => showFilePreviewSheet(
            context,
            FilePreviewData(
              name: 'checkout_bloc.diff.json',
              mimeType: 'application/json',
              text:
                  '{\n'
                  '  "file": "lib/checkout/checkout_bloc.dart",\n'
                  '  "additions": 6,\n'
                  '  "deletions": 2\n'
                  '}\n',
            ),
          ),
        );
        kit.expectText('checkout_bloc.diff.json');
      },
      note:
          'FilePreviewBody embedded in the file-preview sheet host, JSON mode.',
    ),

    // -- diff-view -----------------------------------------------------------------
    CensusShot('diff-view', (kit) async {
      final controller = await kit.connected();
      await kit.pumpApp(
        _backdrop('Fix flaky checkout test'),
        controller: controller,
      );
      await kit.push(DiffPage(diffs: sampleDiffs()));
      kit.expectVisible(find.byKey(const ValueKey('diff-view')));
      kit.expectVisible(
        find.byKey(const ValueKey('diff-file-header-test/checkout_test.dart')),
      );
    }),

    // -- run-command-dialog ----------------------------------------------------------
    CensusShot('run-command-dialog', (kit) async {
      final controller = await kit.connected();
      await kit.pumpApp(_backdrop('Commands'), controller: controller);
      await kit.present(
        (context) => showRunCommandDialog(
          context,
          controller: controller,
          command: const CommandInfo(
            name: 'test',
            description: 'Run the project test suite',
            subtask: false,
          ),
        ),
      );
      kit.expectText('Run /test');
    }),
  ],
  notRendered: const {},
);
