import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../api/models.dart';
import '../../domain/mobile_tool_view.dart';
import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../kit/chat/kit_markdown.dart';
import '../kit/chat/kit_tool_row.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_code_block.dart';
import '../kit/kit_details_fold.dart';
import '../kit/kit_diff_view.dart';
import '../kit/kit_image.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_status_mark.dart';
import '../kit/kit_tappable.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import 'file_preview.dart';
import 'mobile_task_view.dart';
import 'product_states.dart' show productErrorText;

// The host adapter for one tool call (embedded-tool-card; chat-2). It maps a
// server `ToolState` to a KitToolRow — kind, words, status, +/− and time —
// and fills the row's body with kit parts only: KitCodeBlock for output
// (capped at 12 lines, "Open full output" opens the reader), KitDiffView for
// an edit, KitImage and KitRow for produced files, MobileTaskList for the
// plan, KitDetailsFold for a sub-agent's prompt. A sub-agent the host can
// open is the plain agent line ("Delegated to explore · Done") that matches
// the team's worker card (STANDARDS STATE-16, KIT-41).

AppLocalizations _chatL10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

// The chat transcript (a `part` of chat_screen.dart) opens file diffs through
// this library, which it already imports; tool cards render diffs too.

typedef ToolOutputFileLoader =
    Future<FilePreviewData> Function(ToolOutputFile file);
typedef ToolOutputFileAction =
    Future<void> Function(ToolOutputFile file, FilePreviewData data);

enum _ToolKind {
  read,
  list,
  glob,
  grep,
  shell,
  edit,
  write,
  patch,
  webFetch,
  webSearch,
  task,
  todo,
  question,
  lsp,
  skill,
  generic,
}

String? _valueString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _rawString(dynamic value) => value is String ? value : null;

num? _valueNumber(dynamic value) =>
    value is num ? value : num.tryParse('$value');

String _fileName(String value) {
  final normalized = value.replaceAll('\\', '/');
  final parts = normalized.split('/').where((part) => part.isNotEmpty);
  return parts.isEmpty ? value : parts.last;
}

/// The child session the OpenCode `task` or native v2 `subagent` tool spawned, read
/// from the tool metadata. The server writes `sessionId` (alongside
/// `parentSessionId`, `model` and, for background jobs, `jobId`); the other
/// spellings cover native v2 (`sessionID`) and older builds.
String? taskChildSessionId(ToolState state) {
  final metadata = state.metadata;
  if (metadata == null) return null;
  for (final key in const ['sessionId', 'sessionID', 'session_id']) {
    if (_valueString(metadata[key]) case final id?) return id;
  }
  return null;
}

/// `state="…"` of the `<task …>` wrapper the server puts around a subagent
/// result (running / completed / error); null when the output lacks one.
String? _taskOutputState(String? output, {bool nativeSubagent = false}) {
  if (output == null) return null;
  final tag = nativeSubagent ? 'subagent' : 'task';
  final match = RegExp('<$tag\\b[^>]*\\bstate="([a-z_]+)"').firstMatch(output);
  return match?.group(1);
}

/// Text inside `<task_result>` / `<task_error>`, or the whole output when the
/// server did not wrap it.
String _taskResultText(String? output, {bool nativeSubagent = false}) {
  final raw = output ?? '';
  if (nativeSubagent) {
    final wrapper = RegExp(
      r'^\s*<subagent\b[^>]*>\n?(.*?)\n?</subagent>\s*$',
      dotAll: true,
    ).firstMatch(raw);
    return (wrapper?.group(1) ?? raw).trim();
  }
  final match = RegExp(
    r'<task_(?:result|error)>\n?(.*?)\n?</task_(?:result|error)>',
    dotAll: true,
  ).firstMatch(raw);
  return (match?.group(1) ?? raw).trim();
}

/// The invocation finished by detaching its child, not by completing the
/// child's work. The later synthetic completion is a separate server message.
bool _nativeSubagentLaunched(ToolState state) =>
    state.executed &&
    state.status == 'completed' &&
    state.metadata?['status'] == 'running';

String? _subagentState(ToolState state, {required bool nativeSubagent}) {
  if (!state.executed) return null;
  if (nativeSubagent && state.status == 'error') return 'error';
  if (nativeSubagent) {
    final status = state.metadata?['status'];
    if (status == 'running' || status == 'completed') return status as String;
  }
  return _taskOutputState(state.output, nativeSubagent: nativeSubagent);
}

/// Compact "Title · subtitle" line for the tool currently executing, used by
/// the chat tool-group header as a live ticker while a run is active.
String runningToolTicker(
  String rawName,
  ToolState state, {
  AppLocalizations? l10n,
}) {
  final contract = _ToolContract.from(rawName, state, l10n: l10n);
  final subtitle = contract.subtitle;
  return subtitle == null || subtitle.isEmpty
      ? contract.title
      : '${contract.title} · $subtitle';
}

/// What a tool call says about itself, in words, before any widget: its
/// kind, its title ("Read", the sub-agent's name), what it touched
/// ([subtitle]; a technical value when [technical]), the other facts
/// ([details]: "From line 5", "3 matches") and an edit's +/− counts.
class _ToolContract {
  final _ToolKind kind;
  final String title;
  final String? subtitle;

  /// [subtitle] is a value the app did not write (a path, a pattern, a
  /// command, a URL): the row draws it mono and left-to-right.
  final bool technical;
  final List<String> details;
  final int? added;
  final int? removed;

  /// A shell command's exit code, when the server reported one.
  final int? exitCode;
  final bool nativeSubagent;

  const _ToolContract({
    required this.kind,
    required this.title,
    this.subtitle,
    this.technical = false,
    this.details = const [],
    this.added,
    this.removed,
    this.exitCode,
    this.nativeSubagent = false,
  });

  factory _ToolContract.from(
    String rawName,
    ToolState state, {
    AppLocalizations? l10n,
  }) {
    final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
    final name = rawName.trim().toLowerCase();
    final input = state.input;
    final metadata = state.metadata ?? const <String, dynamic>{};
    final details = <String>[];

    _ToolKind kind;
    String title;
    String? subtitle;
    var technical = false;
    int? added;
    int? removed;
    int? exitCode;
    switch (name) {
      case 'read':
        kind = _ToolKind.read;
        title = strings.chatUiRead;
        final path = _valueString(input['filePath']);
        subtitle = path == null ? null : _fileName(path);
        technical = true;
        if (_valueNumber(input['offset']) case final value?) {
          details.add(strings.chatUiFromLine(value));
        }
        if (_valueNumber(input['limit']) case final value?) {
          details.add(strings.chatUiLineCount(value));
        }
        final display = metadata['display'];
        if (display is Map) {
          final start = _valueNumber(display['lineStart']);
          final end = _valueNumber(display['lineEnd']);
          if (start != null && end != null) {
            details.add(strings.chatUiLineRange(start, end));
          }
          final count = display['entries'] is List
              ? (display['entries'] as List).length
              : null;
          if (count != null) details.add(strings.chatUiEntryCount(count));
        }
        break;
      case 'list':
        kind = _ToolKind.list;
        title = strings.chatUiList;
        subtitle = _valueString(input['path']) ?? state.title;
        technical = true;
        break;
      case 'glob':
        kind = _ToolKind.glob;
        title = strings.chatUiFindFiles;
        subtitle = _valueString(input['pattern']);
        technical = true;
        if (_valueNumber(metadata['count']) case final value?) {
          details.add(strings.chatUiFoundCount(value));
        }
        break;
      case 'grep':
        kind = _ToolKind.grep;
        title = strings.chatUiSearchText;
        subtitle = _valueString(input['pattern']);
        technical = true;
        if (_valueNumber(metadata['matches']) case final value?) {
          details.add(strings.chatUiMatchCount(value));
        }
        if (_valueString(input['include']) case final value?) {
          details.add(value);
        }
        break;
      case 'bash':
      case 'shell':
        kind = _ToolKind.shell;
        title = strings.activeContextShell;
        subtitle = _valueString(input['command']);
        technical = true;
        exitCode = _valueNumber(metadata['exit'])?.toInt();
        break;
      case 'edit':
        kind = _ToolKind.edit;
        title = strings.chatUiEdit;
        final path = _valueString(input['filePath']);
        subtitle = path == null ? state.title : _fileName(path);
        technical = path != null;
        final filediff = metadata['filediff'];
        if (filediff is Map) {
          added = _positive(filediff['additions']);
          removed = _positive(filediff['deletions']);
        }
        break;
      case 'write':
        kind = _ToolKind.write;
        title = strings.chatUiWrite;
        final path = _valueString(input['filePath']);
        subtitle = path == null ? state.title : _fileName(path);
        technical = path != null;
        details.add(
          metadata['exists'] == false
              ? strings.chatUiNewFile
              : strings.chatUiUpdated,
        );
        break;
      case 'patch':
      case 'apply_patch':
        kind = _ToolKind.patch;
        title = strings.chatUiApplyPatch;
        final files = metadata['files'];
        if (files is List) {
          subtitle = strings.chatUiFileCount(files.length);
          var additions = 0;
          var deletions = 0;
          for (final file in files.whereType<Map>()) {
            additions += (_valueNumber(file['additions']) ?? 0).toInt();
            deletions += (_valueNumber(file['deletions']) ?? 0).toInt();
          }
          if (additions > 0) added = additions;
          if (deletions > 0) removed = deletions;
        }
        break;
      case 'webfetch':
        kind = _ToolKind.webFetch;
        title = strings.chatUiFetchPage;
        subtitle = _valueString(input['url']);
        technical = true;
        if (_valueString(input['format']) case final value?) details.add(value);
        break;
      case 'websearch':
        kind = _ToolKind.webSearch;
        title = _valueString(metadata['provider']) == null
            ? strings.chatUiWebSearch
            : strings.chatUiProviderSearch(metadata['provider'] ?? '');
        subtitle = _valueString(input['query']);
        if (_valueNumber(metadata['numResults']) case final value?) {
          details.add(strings.chatUiResultCount(value));
        }
        break;
      case 'task':
      case 'subagent':
        kind = _ToolKind.task;
        title =
            _valueString(
              input[name == 'subagent' ? 'agent' : 'subagent_type'],
            ) ??
            strings.chatUiAgent;
        subtitle = _valueString(input['description']);
        break;
      case 'todowrite':
      case 'todo':
        kind = _ToolKind.todo;
        title = strings.workTitle;
        final todos = metadata['todos'] ?? input['todos'];
        // One readout, the same as the opened list's: completed out of the
        // tasks still tracked (cancelled ones are not).
        final view = MobileTaskView.fromTodos(todos);
        if (view != null && view.trackedCount > 0) {
          subtitle = strings.mobileTasksProgress(
            view.completedCount,
            view.trackedCount,
          );
        } else if (todos is List) {
          final done = todos
              .where((item) => item is Map && item['status'] == 'completed')
              .length;
          subtitle = strings.chatUiCompletedCount(done, todos.length);
        }
        break;
      case 'question':
        kind = _ToolKind.question;
        title = strings.chatUiQuestions;
        final questions = input['questions'];
        final answers = metadata['answers'];
        if (questions is List) {
          subtitle = answers is List && answers.isNotEmpty
              ? strings.chatUiAnsweredCount(questions.length)
              : strings.chatUiAskedCount(questions.length);
        }
        break;
      case 'lsp':
        kind = _ToolKind.lsp;
        title =
            _valueString(input['operation']) ?? strings.chatUiLanguageServer;
        final path = _valueString(input['filePath']);
        subtitle = path == null ? null : _fileName(path);
        technical = true;
        break;
      case 'skill':
        kind = _ToolKind.skill;
        title = strings.activeContextSkill;
        subtitle = _valueString(input['name']);
        break;
      default:
        kind = _ToolKind.generic;
        title = state.title?.trim().isNotEmpty == true ? state.title! : rawName;
        subtitle = null;
    }
    if (metadata['truncated'] == true &&
        !details.contains(strings.chatUiTruncated)) {
      details.add(strings.chatUiTruncated);
    }
    return _ToolContract(
      kind: kind,
      title: title,
      subtitle: subtitle,
      technical: technical && subtitle != null,
      details: details,
      added: added,
      removed: removed,
      exitCode: exitCode,
      nativeSubagent: name == 'subagent',
    );
  }

  static int? _positive(dynamic raw) {
    final value = _valueNumber(raw)?.toInt();
    return value != null && value > 0 ? value : null;
  }

  /// The row's glyph (one per verb, COPY-18).
  KitToolKind get rowKind => switch (kind) {
    _ToolKind.read || _ToolKind.lsp => KitToolKind.read,
    _ToolKind.list || _ToolKind.glob => KitToolKind.list,
    _ToolKind.grep => KitToolKind.search,
    _ToolKind.shell => KitToolKind.shell,
    _ToolKind.edit || _ToolKind.write || _ToolKind.patch => KitToolKind.edit,
    _ToolKind.webFetch || _ToolKind.webSearch => KitToolKind.web,
    _ToolKind.task => KitToolKind.agent,
    _ToolKind.todo => KitToolKind.todo,
    _ToolKind.question => KitToolKind.question,
    _ToolKind.skill => KitToolKind.skill,
    _ToolKind.generic => KitToolKind.other,
  };
}

/// Wall-clock tool run time as the card shows it: tenths of a second under
/// a minute ("0.8s", "12.4s"), minutes and zero-padded seconds past it
/// ("1m 05s").
String formatToolDuration(Duration duration, {AppLocalizations? l10n}) {
  final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
  final clamped = duration.isNegative ? Duration.zero : duration;
  if (clamped.inMinutes >= 1) {
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    return strings.chatUiDurationMinutesSeconds(clamped.inMinutes, seconds);
  }
  return strings.chatUiDurationSeconds(
    (clamped.inMilliseconds / 1000).toStringAsFixed(1),
  );
}

/// One tool invocation as one line of the reply (a [KitToolRow]): what it
/// did, where, and how it went, opening to its note and what it produced.
/// A sub-agent the host can open is the plain agent line instead.
class ToolCard extends StatefulWidget {
  final String toolName;
  final ToolState state;
  final bool embedded;

  /// The agent's own one-line name for this step ("Setting up persistence
  /// check"), said right before the call. It becomes the row's title and the
  /// tool's name moves into the detail, so the step is one line, not two.
  final String? heading;

  /// The rest of the thought [heading] was the first line of. Shown first
  /// when the row is opened: why, then what.
  final String? note;

  /// Optional longer-lived store (e.g. session-scoped) keyed by
  /// [expansionKey], so expansion survives list recycling in a virtualized
  /// transcript instead of resetting when the item State is rebuilt.
  final Map<String, bool>? expansionStore;
  final String? expansionKey;
  final ToolOutputFileLoader? filePreviewLoader;
  final ToolOutputFileAction? onAttachFile;
  final ToolOutputFileAction? onDownloadFile;

  /// Opens the child session a `task` tool call delegated to, given its id.
  /// Null keeps the delegation a foldable step (prompt and result inline)
  /// instead of the agent line that opens its conversation.
  final ValueChanged<String>? onOpenSession;

  /// The call is blocked on the person (a permission request whose tool is
  /// this call). The row then says "Waiting for you", never "Running"
  /// (AUTO-15). A running `question` tool is always waiting for the person.
  final bool waitingForYou;

  /// Runs a shell call's command again, given the command. Null hides
  /// "Run this command again".
  final ValueChanged<String>? onRerunCommand;

  const ToolCard({
    super.key,
    required this.toolName,
    required this.state,
    this.embedded = false,
    this.heading,
    this.note,
    this.expansionStore,
    this.expansionKey,
    this.filePreviewLoader,
    this.onAttachFile,
    this.onDownloadFile,
    this.onOpenSession,
    this.waitingForYou = false,
    this.onRerunCommand,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;
  final Map<String, Future<FilePreviewData>> _previewLoads = {};

  List<ToolOutputFile> get _files => widget.state.outputFiles.take(8).toList();
  List<ToolOutputFile> get _images =>
      _files.where((file) => file.isImage).toList();

  /// The ordered v2 content segments, but only when their order carries
  /// information a joined string loses — a text run after a file. Trivial
  /// orders (all text, or text followed only by trailing files) keep the
  /// existing v1 rendering exactly.
  List<ToolResultSegment>? get _interleavedSegments {
    final segments = widget.state.segments;
    var seenFile = false;
    for (final segment in segments) {
      if (segment.isFile) {
        seenFile = true;
      } else if (seenFile) {
        return segments;
      }
    }
    return null;
  }

  bool? get _storedExpansion => widget.expansionKey == null
      ? null
      : widget.expansionStore?[widget.expansionKey!];

  void _setExpanded(bool value) {
    setState(() {
      _expanded = value;
      if (widget.expansionKey case final key?) {
        widget.expansionStore?[key] = value;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _expanded = _storedExpansion ?? (widget.state.status == 'error');
    _syncPreviewLoads();
  }

  @override
  void didUpdateWidget(covariant ToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The host may open a step from outside (the conversation menu's Tasks
    // lands on the plan open): the stored choice wins.
    if (_storedExpansion case final stored? when stored != _expanded) {
      _expanded = stored;
    }
    if (!identical(oldWidget.state.outputFiles, widget.state.outputFiles) ||
        oldWidget.filePreviewLoader != widget.filePreviewLoader) {
      _syncPreviewLoads(reset: true);
    }
  }

  void _syncPreviewLoads({bool reset = false}) {
    if (reset) _previewLoads.clear();
    final identities = _files.map((file) => file.identity).toSet();
    _previewLoads.removeWhere((key, _) => !identities.contains(key));
    for (final file in _images) {
      _previewLoads.putIfAbsent(file.identity, () => _loadPreview(file));
    }
  }

  Future<FilePreviewData> _loadPreview(ToolOutputFile file) async {
    try {
      final url = file.url;
      if (url?.isNotEmpty == true) {
        return FilePreviewData.fromDataUrl(
          name: file.displayName,
          mimeType: file.mimeType,
          url: url,
        );
      }
      final loader = widget.filePreviewLoader;
      if (loader != null && file.path?.isNotEmpty == true) {
        return await loader(file);
      }
      return FilePreviewData(
        name: file.displayName,
        mimeType: file.mimeType,
        error: _chatL10n(context).chatUiTheGeneratedFileIsNotAvailableFrom,
      );
    } catch (error) {
      return FilePreviewData(
        name: file.displayName,
        mimeType: file.mimeType,
        error: _chatL10n(context).chatUiFileLoadFailed(productErrorText(error)),
      );
    }
  }

  Future<FilePreviewData> _loadCached(ToolOutputFile file) =>
      _previewLoads.putIfAbsent(file.identity, () => _loadPreview(file));

  void _retryPreview(ToolOutputFile file) {
    setState(() => _previewLoads[file.identity] = _loadPreview(file));
  }

  bool get _backgroundLaunch =>
      widget.toolName.trim().toLowerCase() == 'subagent' &&
      _nativeSubagentLaunched(widget.state);

  bool get _background =>
      widget.state.metadata?['background'] == true ||
      widget.state.input['background'] == true;

  /// How the call went, in the row's terms. A command that exited non-zero
  /// or timed out failed; one the server killed was stopped; a sub-agent
  /// reads its child's state; a call blocked on the person is waiting for
  /// them, never running.
  KitToolStatus _statusOf(_ToolContract contract) {
    final state = widget.state;
    if (!state.executed) return KitToolStatus.notRun;
    if (_backgroundLaunch) return KitToolStatus.background;
    final live = state.status == 'pending' || state.status == 'running';
    if (live && (widget.waitingForYou || contract.kind == _ToolKind.question)) {
      return KitToolStatus.waitingForYou;
    }
    switch (state.status) {
      case 'pending':
        return KitToolStatus.pending;
      case 'running':
        return KitToolStatus.running;
      case 'error':
        return KitToolStatus.failed;
      case 'cancelled' || 'killed':
        return KitToolStatus.stopped;
    }
    if (contract.kind == _ToolKind.task) {
      final child = _subagentState(
        state,
        nativeSubagent: contract.nativeSubagent,
      );
      if (child == 'error') return KitToolStatus.failed;
      if (child == 'running') {
        return _background ? KitToolStatus.background : KitToolStatus.running;
      }
    }
    if (contract.kind == _ToolKind.shell) {
      final shellStatus = _valueString(state.metadata?['shellStatus']);
      if (shellStatus == 'killed') return KitToolStatus.stopped;
      if (shellStatus == 'timeout') return KitToolStatus.failed;
      final exit = contract.exitCode;
      if (exit != null && exit != 0) return KitToolStatus.failed;
    }
    return KitToolStatus.done;
  }

  /// One ordered v2 content segment: capped output, an image preview, or a
  /// file row.
  Widget _segmentWidget(ToolResultSegment segment) {
    final file = segment.file;
    if (file == null) {
      return _Output(text: segment.text!, name: 'tool-output.txt');
    }
    return _fileWidget(file);
  }

  Widget _fileWidget(ToolOutputFile file) => file.isImage
      ? _ImagePreview(
          file: file,
          load: _loadCached(file),
          onRetry: () => _retryPreview(file),
          onAttach: widget.onAttachFile,
          onDownload: widget.onDownloadFile,
        )
      : _FileRow(
          file: file,
          load: () => _loadCached(file),
          onAttach: widget.onAttachFile,
          onDownload: widget.onDownloadFile,
        );

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final contract = _ToolContract.from(
      widget.toolName,
      widget.state,
      l10n: l10n,
    );
    final status = _statusOf(contract);
    final rowKey = widget.embedded ? const Key('embedded-tool-row') : null;

    // A sub-agent the host can open: the plain agent line that matches the
    // team's worker card. It opens the sub-agent's own conversation.
    final sessionId = taskChildSessionId(widget.state);
    final onOpenSession = widget.onOpenSession;
    if (contract.kind == _ToolKind.task &&
        widget.state.executed &&
        sessionId != null &&
        onOpenSession != null) {
      return KitToolRow.agent(
        rowKey: rowKey ?? const ValueKey('task-open-session'),
        title: l10n.toolCardDelegatedTo(contract.title),
        status: status,
        task: contract.subtitle,
        startedAt: status == KitToolStatus.running
            ? widget.state.startedAt
            : null,
        onOpen: () => onOpenSession(sessionId),
        openLabel: l10n.chatUiOpenSubagentSession,
      );
    }

    final hasBody =
        (widget.state.output?.isNotEmpty ?? false) ||
        (widget.state.inputJson?.isNotEmpty ?? false) ||
        widget.state.input.isNotEmpty ||
        widget.state.metadata?.isNotEmpty == true ||
        widget.state.pruned ||
        _files.isNotEmpty;

    final heading = widget.heading;
    final title = contract.kind == _ToolKind.task
        ? l10n.toolCardDelegatedTo(contract.title)
        : contract.title;
    final path = contract.technical ? contract.subtitle : null;
    final String? detail;
    if (path != null) {
      detail = null;
    } else if (heading != null) {
      detail = [title, ?contract.subtitle].join(' ');
    } else {
      final words = [?contract.subtitle, ...contract.details];
      detail = words.isEmpty ? null : words.join(' · ');
    }

    final interleaved = _interleavedSegments;
    final Widget row = KitToolRow(
      rowKey: rowKey,
      kind: contract.rowKind,
      title: heading ?? title,
      status: status,
      path: path,
      detail: detail,
      added: contract.added,
      removed: contract.removed,
      // The row shows it only once finished (and reads it for a failure).
      duration: widget.state.duration,
      note: (widget.note?.isNotEmpty ?? false)
          ? KitMarkdown(
              widget.note!,
              key: const Key('step-note'),
              role: KitTextRole.secondary,
              tone: KitTextTone.secondary,
              selectable: false,
            )
          : null,
      body: hasBody
          ? [
              _ToolBody(
                contract: contract,
                state: widget.state,
                embedded: widget.embedded,
                // Facts the line had no room for (it shows the path).
                facts: path == null ? const [] : contract.details,
                // Output already shown in order under the line; the body
                // keeps the input only.
                suppressOutput: interleaved != null,
                onRerunCommand: widget.onRerunCommand,
              ),
            ]
          : const [],
      expanded: _expanded,
      onExpansionChanged: _setExpanded,
    );

    // What the call produced (images, files, or text and files in order)
    // stays visible under the line, one indent level in, folded or not.
    final Widget? produced = interleaved != null
        ? KeyedSubtree(
            key: const Key('tool-interleaved-output'),
            child: _Stack(
              children: [for (final s in interleaved) _segmentWidget(s)],
            ),
          )
        : _files.isNotEmpty
        ? _Stack(children: [for (final file in _files) _fileWidget(file)])
        : null;
    if (produced == null) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space3,
            bottom: tokens.space2,
          ),
          child: produced,
        ),
      ],
    );
  }
}

/// Blocks one under another with the kit's block gap.
class _Stack extends StatelessWidget {
  const _Stack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = KitTokens.of(context).space2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}

/// A row's title and the detail after it, in whatever room the row really
/// has. The title keeps its natural width up to two thirds of that room and
/// the detail takes the rest, so neither can run over the other however
/// deeply the row is nested. (A cap taken from the screen's width let a long
/// title paint across the detail inside a nested group.)
class TitleWithDetail extends StatelessWidget {
  const TitleWithDetail({
    super.key,
    required this.title,
    this.detail,
    this.gap = 6,
  });

  final Widget title;
  final Widget? detail;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final room = constraints.maxWidth;
      final detail = this.detail;
      if (detail == null || !room.isFinite) {
        return Align(alignment: AlignmentDirectional.centerStart, child: title);
      }
      return Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: room * .66),
            child: title,
          ),
          SizedBox(width: gap),
          Expanded(child: detail),
        ],
      );
    },
  );
}

/// The agent's reasoning for a step, shown inside the opened step: secondary
/// Markdown in the secondary tone.
class StepNote extends StatelessWidget {
  const StepNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => KitMarkdown(
    text,
    role: KitTextRole.secondary,
    tone: KitTextTone.secondary,
    selectable: false,
  );
}

/// Inline output is cut to this before it reaches the block, so a huge
/// result never lays out on the scrolling transcript (PERF-2); the block
/// itself shows 12 lines and "Open full output" opens all of it.
const _inlineLineCap = 200;
const _inlineCharCap = 20000;

/// Prose results (a sub-agent's answer, a fetched page, a skill) show this
/// many lines as Markdown before "Open full output".
const _proseLineCap = 12;
const _proseCharCap = 4000;

String _inline(String text) {
  var out = text;
  final lines = out.split('\n');
  if (lines.length > _inlineLineCap) {
    out = lines.take(_inlineLineCap).join('\n');
  }
  if (out.length > _inlineCharCap) out = out.substring(0, _inlineCharCap);
  return out;
}

/// Output as a capped [KitCodeBlock]: 12 lines, copy of the whole text, and
/// "Open full output" into the reader.
class _Output extends StatelessWidget {
  const _Output({
    super.key,
    required this.text,
    required this.name,
    this.kind = KitCodeKind.output,
    this.caption,
    this.fileName,
  });

  final String text;
  final String name;
  final KitCodeKind kind;
  final String? caption;
  final String? fileName;

  @override
  Widget build(BuildContext context) => KitCodeBlock(
    text: _inline(text),
    kind: kind,
    caption: caption,
    fileName: fileName,
    copyText: text,
    onOpenFull: () =>
        showFilePreviewSheet(context, FilePreviewData(name: name, text: text)),
  );
}

/// A prose result as Markdown, capped at [_proseLineCap] lines with "Open
/// full output" into the reader.
class _Prose extends StatelessWidget {
  const _Prose({super.key, required this.text, required this.name});

  final String text;
  final String name;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    var shown = lines.length > _proseLineCap
        ? lines.take(_proseLineCap).join('\n')
        : text;
    if (shown.length > _proseCharCap) {
      shown = shown.substring(0, _proseCharCap);
    }
    final capped = shown.length < text.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitMarkdown(shown, role: KitTextRole.secondary),
        if (capped)
          KitButton.tertiary(
            key: const Key('tool-body-see-all'),
            label: _chatL10n(context).kitCodeOpenFull,
            onPressed: () => showFilePreviewSheet(
              context,
              FilePreviewData(name: name, text: text),
            ),
          ),
      ],
    );
  }
}

/// What an opened call shows, built only once it is open: the facts the
/// line had no room for, then the kind's own blocks.
class _ToolBody extends StatelessWidget {
  const _ToolBody({
    required this.contract,
    required this.state,
    required this.embedded,
    this.facts = const [],
    this.suppressOutput = false,
    this.onRerunCommand,
  });

  final _ToolContract contract;
  final ToolState state;
  final bool embedded;
  final List<String> facts;
  final ValueChanged<String>? onRerunCommand;

  /// True when the ordered segment rendering already shows the output; the
  /// body then only adds the input JSON.
  final bool suppressOutput;

  Map<String, dynamic> get _metadata =>
      state.metadata ?? const <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    return _Stack(
      children: [
        if (facts.isNotEmpty)
          KitText(
            facts.join(' · '),
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
        if (state.pruned)
          KitNotice(
            key: const Key('tool-pruned'),
            message: l10n.chatUiOutputPruned,
            icon: AppIconography.cut,
            liveRegion: false,
          ),
        ..._blocks(context),
      ],
    );
  }

  List<Widget> _blocks(BuildContext context) {
    // A failed delegation still shows who was asked to do what; the error
    // lands in the result instead of replacing the whole body.
    if (contract.kind == _ToolKind.task && !suppressOutput) {
      return _taskBody(context);
    }
    if (state.status == 'error') {
      return [
        _error(context, state.output ?? _chatL10n(context).chatUiToolFailed),
      ];
    }
    if (suppressOutput) return [_genericInput()];
    return switch (contract.kind) {
      _ToolKind.read => [_readBody(context)],
      _ToolKind.shell => _shellBody(context),
      _ToolKind.edit => [_editBody(context)],
      _ToolKind.write => _writeBody(context),
      _ToolKind.patch => _patchBody(context),
      _ToolKind.todo => [_todoBody(context)],
      _ToolKind.question => _questionBody(context),
      _ToolKind.webFetch || _ToolKind.webSearch => [_richOutputBody()],
      _ToolKind.task => _taskBody(context),
      _ToolKind.list ||
      _ToolKind.glob ||
      _ToolKind.grep => [_searchBody(context)],
      _ToolKind.lsp => [_lspBody()],
      _ToolKind.skill => [_skillBody()],
      _ToolKind.generic => _genericBody(),
    };
  }

  /// An error in the tool's own words, as capped output (LOOK-5: no danger
  /// colour; the row already says Failed).
  Widget _error(BuildContext context, String message) => _Output(
    key: Key(
      embedded ? 'embedded-tool-error-output' : 'standalone-tool-error-output',
    ),
    text: message.replaceFirst(RegExp(r'^Error:\s*'), ''),
    name: 'tool-error.txt',
    caption: _chatL10n(context).chatUiToolFailed,
  );

  Widget _readBody(BuildContext context) {
    final l10n = _chatL10n(context);
    final display = _metadata['display'];
    if (display is Map) {
      final map = Map<String, dynamic>.from(display);
      final type = _valueString(map['type']);
      final path =
          _valueString(map['path']) ??
          _valueString(state.input['filePath']) ??
          'read-output.txt';
      if (type == 'directory' && map['entries'] is List) {
        final entries = (map['entries'] as List).map((item) => '$item');
        final footer = map['truncated'] == true
            ? l10n.chatUiMoreEntries(map['totalEntries'] ?? '')
            : l10n.chatUiEntryTotal(
                map['totalEntries'] ?? (map['entries'] as List).length,
              );
        return _Output(
          text: entries.take(200).join('\n'),
          name: 'directory.txt',
          caption: '${l10n.chatUiDirectory}: $path · $footer',
        );
      }
      final text = _rawString(map['text']);
      if (type == 'file' && text?.trim().isNotEmpty == true) {
        return _Output(
          text: text!,
          name: _fileName(path),
          kind: KitCodeKind.code,
          fileName: _fileName(path),
        );
      }
    }

    final output = state.output ?? '';
    final directory = RegExp(
      r'<entries>\n?(.*?)\n?</entries>',
      dotAll: true,
    ).firstMatch(output);
    if (directory != null) {
      final entries = directory
          .group(1)!
          .split('\n')
          .where((line) => line.trim().isNotEmpty && !line.startsWith('('));
      final path =
          _valueString(state.input['filePath']) ?? l10n.chatUiDirectory;
      return _Output(
        text: entries.join('\n'),
        name: 'directory.txt',
        caption: '${l10n.chatUiDirectory}: $path',
      );
    }
    final content = RegExp(
      r'<content>\n?(.*?)\n?</content>',
      dotAll: true,
    ).firstMatch(output);
    if (content != null) {
      final text = content
          .group(1)!
          .split('\n')
          .map((line) => line.replaceFirst(RegExp(r'^\d+: '), ''))
          .where((line) => !line.startsWith('(End of file'))
          .join('\n');
      final name = _fileName(
        _valueString(state.input['filePath']) ?? 'read-output.txt',
      );
      return _Output(
        text: text,
        name: name,
        kind: KitCodeKind.code,
        fileName: name,
      );
    }
    return _plainOutput(context, 'read-output.txt');
  }

  /// The command (copyable, never wrapped), its output with the exit code
  /// in words, and "Run this command again" when the host offers it.
  List<Widget> _shellBody(BuildContext context) {
    final l10n = _chatL10n(context);
    final command = _valueString(state.input['command']) ?? '';
    final streamed = _rawString(_metadata['output']);
    var output = state.output?.trim().isNotEmpty == true
        ? state.output!
        : streamed ?? '';
    output = output
        .replaceAll(
          RegExp(r'\n*<shell_metadata>.*?</shell_metadata>', dotAll: true),
          '',
        )
        .trimRight();
    final shellStatus = _valueString(_metadata['shellStatus']);
    final exit = contract.exitCode;
    final outcome = [
      if (shellStatus == 'timeout')
        l10n.chatUiTimedOut
      else if (shellStatus == 'killed')
        l10n.chatUiKilled
      else if (exit == 0)
        l10n.toolCardExitPassed
      else if (exit != null)
        l10n.toolCardExitFailed(exit),
      if (_metadata['truncated'] == true) l10n.chatUiTruncated,
    ];
    final rerun = onRerunCommand;
    return [
      if (command.isNotEmpty)
        KitCodeBlock(
          key: const Key('tool-shell-command'),
          text: command,
          kind: KitCodeKind.command,
          copyLabel: l10n.toolCardCopyCommand,
        ),
      if (output.isNotEmpty || outcome.isNotEmpty)
        _Output(
          key: const Key('tool-shell-output'),
          text: output.isEmpty ? l10n.chatUiNoOutput : output,
          name: 'command-output.txt',
          caption: outcome.isEmpty ? null : outcome.join(' · '),
        ),
      if (rerun != null && command.isNotEmpty && state.executed)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: KitButton.tertiary(
            key: const Key('tool-shell-rerun'),
            label: l10n.toolCardRunCommandAgain,
            icon: AppIconography.retry,
            onPressed: () => rerun(command),
          ),
        ),
    ];
  }

  Widget _editBody(BuildContext context) {
    final path = _valueString(state.input['filePath']) ?? 'changes.diff';
    final filediff = _metadata['filediff'];
    final patch = filediff is Map ? _rawString(filediff['patch']) : null;
    final diff = patch ?? _rawString(_metadata['diff']);
    if (diff?.trim().isNotEmpty == true) {
      return _Diff(files: [KitDiffFile.fromPatch(path, diff!)]);
    }
    final oldText = _rawString(state.input['oldString']);
    final newText = _rawString(state.input['newString']);
    if (oldText != null || newText != null) {
      return _Diff(
        files: [
          KitDiffFile.fromTexts(
            path,
            before: oldText ?? '',
            after: newText ?? '',
            status: KitDiffFileStatus.modified,
          ),
        ],
      );
    }
    return _plainOutput(context, 'edit-output.txt');
  }

  List<Widget> _writeBody(BuildContext context) {
    final content = _rawString(state.input['content']);
    if (content?.trim().isNotEmpty != true) {
      return [_plainOutput(context, 'write-output.txt')];
    }
    final name = _fileName(
      _valueString(state.input['filePath']) ?? 'written-file.txt',
    );
    return [
      _Output(
        text: content!,
        name: name,
        kind: KitCodeKind.code,
        fileName: name,
      ),
      if (_hasDiagnostics) _diagnostics(),
    ];
  }

  List<Widget> _patchBody(BuildContext context) {
    final l10n = _chatL10n(context);
    final rawFiles = _metadata['files'];
    if (rawFiles is List && rawFiles.isNotEmpty) {
      final diffs = <KitDiffFile>[];
      final plain = <String>[];
      for (final raw in rawFiles.whereType<Map>()) {
        final file = Map<String, dynamic>.from(raw);
        final path =
            _valueString(file['relativePath']) ??
            _valueString(file['movePath']) ??
            _valueString(file['filePath']) ??
            l10n.chatUiChangedFile;
        if (_rawString(file['patch']) case final patch?) {
          diffs.add(KitDiffFile.fromPatch(path, patch));
        } else {
          plain.add('$path · ${_valueString(file['type']) ?? 'changed'}');
        }
      }
      return [
        if (diffs.isNotEmpty) _Diff(files: diffs),
        if (plain.isNotEmpty)
          _Output(text: plain.join('\n'), name: 'changed-files.txt'),
        if (_hasDiagnostics) _diagnostics(),
      ];
    }
    final diff =
        _rawString(_metadata['diff']) ?? _rawString(state.input['patchText']);
    return [
      diff?.trim().isNotEmpty != true
          ? _plainOutput(context, 'patch-output.txt')
          : _Diff(files: [KitDiffFile.fromPatch('changes.diff', diff!)]),
    ];
  }

  Widget _searchBody(BuildContext context) {
    final l10n = _chatL10n(context);
    final path = _valueString(state.input['path']);
    final include = _valueString(state.input['include']);
    final caption = [
      if (path != null) '${l10n.chatUiScope}: $path',
      if (include != null) '${l10n.chatUiFiles}: $include',
    ];
    return _plainOutput(
      context,
      'search-results.txt',
      caption: caption.isEmpty ? null : caption.join(' · '),
    );
  }

  Widget _richOutputBody() {
    final output = state.output ?? '';
    if (output.trim().isEmpty) return _genericInput();
    final name = switch (contract.kind) {
      _ToolKind.webFetch =>
        _valueString(state.input['format']) == 'html'
            ? 'response.html'
            : 'response.md',
      _ToolKind.webSearch => 'search-results.md',
      _ => 'agent-result.md',
    };
    return name.endsWith('.html')
        ? _Output(text: output, name: name)
        : _Prose(text: output, name: name);
  }

  /// `task` as a step (no conversation to open): what the sub-agent was
  /// asked (description, model, the prompt folded), and what came back.
  List<Widget> _taskBody(BuildContext context) {
    final l10n = _chatL10n(context);
    final launched = contract.nativeSubagent && _nativeSubagentLaunched(state);
    final description =
        _valueString(state.input['description']) ?? _valueString(state.title);
    final prompt = _rawString(state.input['prompt']);
    final model = _metadata['model'];
    final modelLabel = model is Map
        ? _valueString(model['modelID'])
        : _valueString(model);
    final resultText = launched
        ? ''
        : _taskResultText(
            state.output,
            nativeSubagent: contract.nativeSubagent,
          );
    final childState = _subagentState(
      state,
      nativeSubagent: contract.nativeSubagent,
    );
    final working =
        !launched &&
        state.executed &&
        state.status != 'error' &&
        (state.status == 'running' ||
            state.status == 'pending' ||
            childState == 'running');

    return [
      if (description?.isNotEmpty == true)
        KitText(
          description!,
          key: const Key('task-description'),
          role: KitTextRole.secondary,
          tone: KitTextTone.primary,
        ),
      if (modelLabel != null)
        KitText(
          '${l10n.chatUiModel} · $modelLabel',
          role: KitTextRole.caption,
          tone: KitTextTone.secondary,
        ),
      if (prompt?.trim().isNotEmpty == true)
        KitDetailsFold(
          key: const Key('task-prompt'),
          foldKey: const Key('task-prompt-toggle'),
          label: l10n.chatUiPromptFromParentAgent,
          child: KitMarkdown(prompt!.trimRight(), role: KitTextRole.secondary),
        ),
      if (launched)
        KitText(
          l10n.workStartedInBackground,
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        )
      else if (state.status == 'error')
        _error(
          context,
          resultText.isEmpty ? l10n.chatUiSubagentFailed : resultText,
        )
      else if (resultText.isNotEmpty)
        _Prose(
          key: const Key('task-result'),
          text: resultText,
          name: 'agent-result.md',
        )
      else if (working)
        KitText(
          l10n.chatUiSubagentWorking,
          key: const Key('task-working'),
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        )
      else
        KitText(
          l10n.chatUiNoResult,
          role: KitTextRole.secondary,
          tone: KitTextTone.tertiary,
        ),
    ];
  }

  Widget _todoBody(BuildContext context) {
    final raw = _metadata['todos'] ?? state.input['todos'];
    final view = MobileTaskView.fromTodos(raw);
    if (view != null) return MobileTaskList(view: view);
    if (state.output?.isNotEmpty == true) {
      return _plainOutput(context, 'tasks.json');
    }
    final fallback = MobileTaskView.fallback(raw);
    return fallback.isEmpty
        ? _plainOutput(context, 'tasks.json')
        : _Output(text: fallback, name: 'tasks.txt');
  }

  List<Widget> _questionBody(BuildContext context) {
    final l10n = _chatL10n(context);
    final questions = state.input['questions'];
    final answers = _metadata['answers'];
    if (questions is! List || questions.isEmpty) {
      return [_plainOutput(context, 'question-output.txt')];
    }
    return [
      for (var index = 0; index < questions.length; index += 1)
        _QuestionAnswer(
          question: questions[index] is Map
              ? _valueString((questions[index] as Map)['question']) ??
                    l10n.chatUiQuestion
              : '${questions[index]}',
          answer: answers is List && index < answers.length
              ? answers[index]
              : null,
        ),
    ];
  }

  Widget _lspBody() {
    final result = _metadata['result'] ?? state.outputValue ?? state.output;
    return _Output(
      text: result is String
          ? result
          : const JsonEncoder.withIndent('  ').convert(result),
      name: 'language-server.json',
    );
  }

  Widget _skillBody() {
    final output = state.output;
    return output?.trim().isNotEmpty == true
        ? _Prose(text: output!, name: 'skill.md')
        : _genericInput();
  }

  List<Widget> _genericBody() {
    final hasInput =
        state.input.isNotEmpty || state.inputJson?.isNotEmpty == true;
    return [
      if (hasInput) _genericInput(),
      if (state.output?.trim().isNotEmpty == true)
        _Output(
          text: state.output!,
          name: state.outputValue is Map || state.outputValue is List
              ? 'tool-output.json'
              : 'tool-output.txt',
        ),
    ];
  }

  Widget _genericInput() {
    final input = state.input.isNotEmpty
        ? const JsonEncoder.withIndent('  ').convert(state.input)
        : state.inputJson ?? '';
    return _Output(text: input, name: 'tool-input.json');
  }

  Widget _plainOutput(BuildContext context, String name, {String? caption}) =>
      _Output(
        text: state.output?.trim().isNotEmpty == true
            ? state.output!
            : _chatL10n(context).chatUiNoOutput,
        name: name,
        caption: caption,
      );

  bool get _hasDiagnostics {
    final diagnostics = _metadata['diagnostics'];
    return diagnostics is Map && diagnostics.isNotEmpty;
  }

  Widget _diagnostics() => _Output(
    text: const JsonEncoder.withIndent(' ').convert(_metadata['diagnostics']),
    name: 'diagnostics.json',
  );
}

/// An edit as a [KitDiffView] capped at 12 lines; "Open all changes" opens
/// the read-only diff page.
class _Diff extends StatelessWidget {
  const _Diff({required this.files});

  final List<KitDiffFile> files;

  @override
  Widget build(BuildContext context) => KitDiffView(
    files: files,
    maxLines: 12,
    keyPrefix: 'tool-diff',
    onOpenAll: () => showKitDiff(
      context,
      title: _chatL10n(context).toolCardChangesIn(
        files.length == 1
            ? _fileName(files.first.path)
            : _chatL10n(context).chatUiFileCount(files.length),
      ),
      files: files,
    ),
  );
}

/// One question the agent asked and the answer it got, in words.
class _QuestionAnswer extends StatelessWidget {
  const _QuestionAnswer({required this.question, this.answer});

  final String question;
  final dynamic answer;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final joined = answer is List
        ? (answer as List).map((item) => '$item').join(', ')
        : _valueString(answer);
    final answerText = joined == null || joined.trim().isEmpty ? null : joined;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitText(
          question,
          role: KitTextRole.secondary,
          tone: KitTextTone.primary,
        ),
        KitText(
          answerText == null
              ? l10n.chatUiNoAnswer
              : l10n.chatUiAnsweredDetail(answerText),
          role: KitTextRole.secondary,
          tone: answerText == null
              ? KitTextTone.tertiary
              : KitTextTone.secondary,
        ),
      ],
    );
  }
}

/// A produced image: loading as a working row, a failure in words with
/// "Load (name) again", else the picture (decoded at its laid-out size by
/// KitImage), which opens the reader with Attach and Download.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.file,
    required this.load,
    required this.onRetry,
    this.onAttach,
    this.onDownload,
  });

  final ToolOutputFile file;
  final Future<FilePreviewData> load;
  final VoidCallback onRetry;
  final ToolOutputFileAction? onAttach;
  final ToolOutputFileAction? onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    return FutureBuilder<FilePreviewData>(
      future: load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return KitRow(
            key: const Key('tool-output-image-loading'),
            leading: const KitStatusMark(state: KitMarkState.working),
            title: l10n.chatUiLoadingFile(file.displayName),
            padding: EdgeInsets.zero,
          );
        }
        final data = snapshot.data;
        final failure = snapshot.error;
        final error = failure != null
            ? productErrorText(failure, l10n: l10n)
            : data?.error;
        if (error != null || data?.bytes?.isNotEmpty != true) {
          return KitNotice(
            key: const Key('tool-output-image-error'),
            title: file.displayName,
            message: error ?? l10n.chatUiImageDataIsUnavailable,
            icon: AppIconography.imageBroken,
            liveRegion: false,
            actions: [
              KitAction(
                label: l10n.toolCardLoadImageAgain(file.displayName),
                icon: AppIconography.retry,
                onPressed: onRetry,
              ),
            ],
          );
        }
        final previewData = data!;
        return KitTappable(
          label: l10n.chatUiPreviewGeneratedImage(file.displayName),
          shape: KitShape.code,
          onTap: () => showFilePreviewSheet(
            context,
            previewData,
            onAttach: onAttach == null
                ? null
                : () => onAttach!(file, previewData),
            onDownload: onDownload == null
                ? null
                : () => onDownload!(file, previewData),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: KitImage(
              imageKey: const Key('tool-output-image'),
              source: KitImageSource.memory(previewData.bytes!),
              semanticsLabel: null,
              shape: KitShape.code,
            ),
          ),
        );
      },
    );
  }
}

/// A produced file as a row: its name and type; a tap loads it (a working
/// mark while it does) and opens the reader with Attach and Download.
class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.file,
    required this.load,
    this.onAttach,
    this.onDownload,
  });

  final ToolOutputFile file;
  final Future<FilePreviewData> Function() load;
  final ToolOutputFileAction? onAttach;
  final ToolOutputFileAction? onDownload;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() => _opening = false);
      await showFilePreviewSheet(
        context,
        data,
        onAttach: widget.onAttach == null
            ? null
            : () => widget.onAttach!(widget.file, data),
        onDownload: widget.onDownload == null
            ? null
            : () => widget.onDownload!(widget.file, data),
      );
    } finally {
      if (mounted && _opening) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    return KitRow(
      key: const Key('tool-output-file'),
      leading: const KitRowIcon(AppIconography.file),
      title: widget.file.displayName,
      supporting: TextSpan(
        text: widget.file.mimeType ?? l10n.chatUiGeneratedFile,
      ),
      trailing: _opening
          ? const KitStatusMark(state: KitMarkState.working)
          : const KitChevron(),
      onTap: _opening ? null : _open,
      padding: EdgeInsets.zero,
    );
  }
}
