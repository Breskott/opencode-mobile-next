import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../domain/run_result.dart';
import '../../domain/server_gateway.dart';
import '../../domain/session_title_text.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_iconography.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress.dart';
import '../kit/kit_screen.dart';
import '../kit/kit_state_view.dart';
import '../kit/kit_tokens.dart';
import '../kit/kit_top_bar.dart';
import '../kit/motion/kit_refresh.dart';
import '../kit/motion/kit_reveal.dart';
import '../widgets/run_result_view.dart';
import 'files_screen.dart' show deliverReviewPrompt, pushWorkingTreeReview;

/// Loads a session's newest history pages and shows the latest run's
/// server-recorded outcome and tool evidence. Nothing is persisted: after a
/// restart the same server records rebuild the same view, and the only
/// in-memory fact (whether this phone saw the last step complete live) is
/// reported as absent rather than assumed.
///
/// Built from kit parts only (STANDARDS KIT-1). States (STATE-20): loading
/// (says so past 8 s, with Try again), error (why, Try again, details
/// folded), empty, scope changed, loaded, still running (a notice over what
/// has been done so far) and refresh failed (a notice over the kept result).
/// While the run changed files and the server can list them, "Review
/// changed files" is pinned at the bottom (map run-result actionsMissing).
class RunResultScreen extends StatefulWidget {
  const RunResultScreen({
    super.key,
    required this.controller,
    required this.sessionID,
  });

  final ConnectionController controller;
  final String sessionID;

  /// How many older pages to walk looking for the user message that started
  /// the run before giving up and labelling the history partial.
  static const maxPages = 5;

  @override
  State<RunResultScreen> createState() => _RunResultScreenState();
}

class _RunResultScreenState extends State<RunResultScreen> {
  bool _loading = true;

  /// The failure as the app says it (a [ProductException]'s own words), or
  /// null when only a raw error is known; the raw text is [_error], shown
  /// only behind Details (COPY-14).
  String? _errorWords;
  String? _error;
  Object? _errorObject;
  RunResult? _result;
  bool _loaded = false;
  int _generation = 0;
  DateTime _loadStartedAt = DateTime.now();
  late final Object _boundScope;
  bool _invalidated = false;

  Object get _currentScope => (
    widget.controller,
    widget.sessionID,
    widget.controller.profile?.id,
    widget.controller.profile?.baseUrl,
    widget.controller.connectionRevision,
    widget.controller.locationRevision,
    widget.controller.directory,
    widget.controller.workspace,
  );

  bool get _current => !_invalidated && _boundScope == _currentScope;

  void _clearError() {
    _error = null;
    _errorWords = null;
    _errorObject = null;
  }

  void _invalidateIfChanged() {
    if (_current) return;
    _invalidated = true;
    _generation++;
    _result = null;
    _loaded = false;
    _loading = false;
    _clearError();
  }

  @override
  void initState() {
    super.initState();
    _boundScope = _currentScope;
    widget.controller.addListener(_changed);
    // The first load starts after initState so its setState is legal; the
    // initial fields already describe the loading state for the first frame.
    scheduleMicrotask(_load);
  }

  @override
  void didUpdateWidget(covariant RunResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _invalidateIfChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(_invalidateIfChanged);
  }

  Future<void> _load() async {
    if (!mounted) return;
    _invalidateIfChanged();
    if (!_current) {
      setState(() {});
      return;
    }
    final generation = ++_generation;
    final controller = widget.controller;
    setState(() {
      _loading = true;
      _loadStartedAt = DateTime.now();
      _clearError();
    });
    try {
      final api = await controller.prepareActionTransport();
      if (!mounted || generation != _generation || !_current) return;
      if (api == null) {
        throw const ProductException('OpenCode is reconnecting. Try again.');
      }
      final loaded = await loadRunHistory(
        api,
        widget.sessionID,
        isCurrent: () => mounted && generation == _generation && _current,
      );
      if (!mounted || generation != _generation || !_current) return;
      setState(() {
        _result = RunResult.fromMessages(
          widget.sessionID,
          loaded.messages,
          historyComplete: loaded.complete,
        );
        _loaded = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation || !_current) return;
      setState(() {
        _errorObject = error;
        _errorWords = error is ProductException ? error.message : null;
        _error = error is ProductException ? error.message : '$error';
        _loading = false;
      });
    }
  }

  void _openConversation() {
    if (!_current) return;
    Navigator.of(context).pushNamed('/chat/${widget.sessionID}');
  }

  /// "Review changed files" lands on the one review of the project's
  /// changes (map run-result sameJobElsewhere → review-workspace), opened
  /// at the first file this run changed.
  Future<void> _reviewChanges(RunResult result) async {
    if (!_current || result.changedFiles.isEmpty) return;
    final prompt = await pushWorkingTreeReview(
      context,
      widget.controller,
      initialFile: result.changedFiles.first.path,
    );
    if (mounted) await deliverReviewPrompt(context, prompt);
  }

  @override
  Widget build(BuildContext context) {
    _invalidateIfChanged();
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final session = controller.sessionsById[widget.sessionID];
    final result = _current ? _result : null;
    final retry = KitAction(
      label: l10n.commonRetry,
      onPressed: () => unawaited(_load()),
    );
    final Widget body;
    if (!_current) {
      body = KitStateView(
        icon: AppIconography.projects,
        title: l10n.reviewRunResultsScopeChangedTitle,
        body: l10n.runResultsScopeChanged,
        bodyKey: const Key('run-result-scope-changed'),
        primary: KitAction(
          label: l10n.reviewRunResultsCloseAction,
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
        ),
      );
    } else if (_loading && !_loaded) {
      // A wait past 8 s says so and offers Try again (STATE-5).
      body = KitStateView(
        key: const Key('run-result-loading'),
        icon: AppIconography.history,
        title: l10n.reviewRunResultsLoadingTitle,
        progress: const KitProgress.waiting(),
        since: _loadStartedAt,
        onSlow: [retry],
      );
    } else if (_error != null && !_loaded) {
      body = KitStateView.error(
        title: l10n.reviewRunResultsErrorTitle,
        body: _errorWords ?? l10n.reviewRunResultsErrorBody,
        bodyKey: const Key('run-result-error-state'),
        error: _errorObject,
        details: _errorWords == null ? _error : null,
        retry: retry,
      );
    } else if (result == null) {
      body = KitStateView(
        icon: AppIconography.history,
        title: l10n.reviewRunResultsEmptyTitle,
        body: l10n.runResultsEmpty,
        bodyKey: const Key('run-result-empty'),
      );
    } else {
      body = RunResultView(
        result: result,
        sessionTitle: session?.title,
        observedLive: controller.observedCompletedMessageIDs.contains(
          result.lastStepID,
        ),
        onOpenConversation: _openConversation,
      );
    }
    final running =
        result != null &&
        (result.outcome.kind == RunOutcomeKind.running ||
            controller.busySessions.contains(widget.sessionID));
    final canReview =
        result != null &&
        result.changedFiles.isNotEmpty &&
        controller.capabilities.fileBrowsing;
    final notices = <Widget>[
      // A failed refresh keeps the result and says so (STATE-3).
      if (_error != null && _loaded && _current)
        KitNotice.error(
          key: const Key('run-result-refresh-error'),
          message: l10n.reviewRunResultsRefreshFailed,
          error: _errorObject,
          details: _error,
          retry: retry,
        ),
      if (running)
        KitNotice(
          key: const Key('run-result-running'),
          icon: AppIconography.waiting,
          message: l10n.reviewRunResultsRunningNotice,
        ),
    ];
    return KitScreen(
      // The page is named for the conversation it reviews ("Fix the
      // checkout total"); "Run results" only when the title is unknown.
      topBar: KitTopBar(
        title: switch (displaySessionTitleText(session?.title)) {
          final title when title.isNotEmpty => title,
          _ => l10n.runResultsTitle,
        },
      ),
      loading: _loading && _loaded,
      loadingLabel: l10n.reviewRunResultsLoadingTitle,
      bottom: canReview
          ? KitActionBlock(
              primary: KitAction(
                key: const Key('run-result-review-changes'),
                label: l10n.reviewRunResultsReviewChanges,
                icon: AppIconography.review,
                onPressed: () => unawaited(_reviewChanges(result)),
              ),
            )
          : null,
      body: KitRefresh(
        onRefresh: _load,
        child: Column(
          children: [
            // Notices unfold over the kept result and fold away once they
            // no longer apply; always mounted, so the result below keeps
            // its place and state.
            KitReveal(
              child: notices.isEmpty
                  ? null
                  : Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: tokens.gutter,
                        top: tokens.space2,
                        end: tokens.gutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, notice) in notices.indexed) ...[
                            if (index > 0) SizedBox(height: tokens.space2),
                            notice,
                          ],
                        ],
                      ),
                    ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The newest pages of a session, walked back until the user message that
/// started the latest run is included, the history is exhausted, or
/// [RunResultScreen.maxPages] pages were read. [complete] is true only when
/// the server reported no further pages.
class LoadedRunHistory {
  const LoadedRunHistory({required this.messages, required this.complete});
  final List<MessageWithParts> messages;
  final bool complete;
}

Future<LoadedRunHistory> loadRunHistory(
  ServerGateway api,
  String sessionID, {
  required bool Function() isCurrent,
  int maxPages = RunResultScreen.maxPages,
}) async {
  final messages = <MessageWithParts>[];
  final seen = <String>{};
  final cursors = <String>{};
  String? cursor;
  var complete = false;
  for (var page = 0; page < maxPages; page++) {
    final result = await api.messagePage(sessionID, cursor: cursor);
    if (!isCurrent()) {
      throw const ProductException(
        'The session changed while loading history.',
      );
    }
    // Pages walk backwards; each gateway page keeps its server item order.
    // Prepend older pages so equal timestamps spanning pages stay ordered.
    final older = <MessageWithParts>[];
    for (final message in result.items) {
      if (seen.add(message.info.id)) older.add(message);
    }
    messages.insertAll(0, older);
    if (!result.hasMore) {
      complete = true;
      break;
    }
    if (messages.any((m) => m.info.role == 'user')) break;
    final next = result.nextCursor;
    if (next == null || next == cursor || !cursors.add(next)) break;
    cursor = next;
  }
  return LoadedRunHistory(messages: messages, complete: complete);
}
