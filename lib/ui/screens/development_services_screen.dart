import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/development_service.dart';
import '../../domain/server_gateway.dart';
import '../../feedback/bug_report.dart' show openFailedJobReport;
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/development_service_store.dart';
import '../../state/development_services.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_field.dart';
import '../kit/kit_icon_button.dart';
import '../kit/kit_log_panel.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_screen.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_state_view.dart';
import '../kit/kit_technical_value.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/kit_top_bar.dart';
import '../kit/kit_undo.dart';
import '../kit/motion/kit_refresh.dart';
import '../widgets/external_link.dart';
import '../widgets/product_states.dart' show productErrorText;

/// Development services (map pages `development-services`, `-editor-sheet`,
/// `-confirm-sheet`, `-logs-sheet`): the project's saved dev commands and
/// preview links as one row list. Each row says its state and command in
/// words, carries one trailing Start or Stop, and keeps the rarer acts in
/// its menu (long-press, right-click). Start runs at once with Undo;
/// Stop, Restart and Forget ask first; Remove offers Undo unless a command
/// may still be running, when it asks and says so.
class DevelopmentServicesScreen extends StatefulWidget {
  const DevelopmentServicesScreen({super.key, required this.controller});
  final ConnectionController controller;

  @override
  State<DevelopmentServicesScreen> createState() =>
      _DevelopmentServicesScreenState();
}

class _DevelopmentServicesScreenState extends State<DevelopmentServicesScreen>
    with WidgetsBindingObserver {
  late final Object _scope;
  late final String _profileID;
  late final DevelopmentServices _model;
  bool _invalid = false;
  bool _foreground = true;
  Timer? _timer;
  late int _connectionRevision;
  late StreamStatus _status;

  Object get _currentScope => (
    widget.controller,
    widget.controller.profile?.id,
    widget.controller.profile?.baseUrl,
    widget.controller.locationRevision,
    widget.controller.directory,
    widget.controller.workspace,
  );

  bool get _current =>
      mounted &&
      !_invalid &&
      _scope == _currentScope &&
      widget.controller.isProfileReadable(_profileID);

  bool get _supported => widget.controller.capabilities.developmentServices;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    final connection = widget.controller;
    _scope = _currentScope;
    _profileID = connection.profile?.id ?? '';
    _connectionRevision = connection.connectionRevision;
    _status = connection.status;
    _invalid = _profileID.isEmpty || connection.directory?.isNotEmpty != true;
    _model = DevelopmentServices(
      store: DevelopmentServiceStore(
        preferences: connection.store.prefs,
        profileID: _profileID,
        canWrite: () => connection.isProfileReadable(_profileID),
      ),
      directory: connection.directory ?? '',
      workspace: connection.workspace,
      isCurrent: () => _current && _foreground,
      supported: () => connection.capabilities.developmentServices,
      resolveGateway: () async {
        final revision = connection.connectionRevision;
        final gateway = await connection.prepareActionRepository();
        if (!_current || revision != connection.connectionRevision) return null;
        return gateway;
      },
    );
    _model.addListener(_changed);
    connection.addListener(_connectionChanged);
    WidgetsBinding.instance.addObserver(this);
    scheduleMicrotask(_refresh);
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _connectionChanged() {
    if (!_current) {
      _invalid = true;
      _timer?.cancel();
      _model.invalidateRuntime();
    } else if (_connectionRevision != widget.controller.connectionRevision ||
        _status != widget.controller.status) {
      _connectionRevision = widget.controller.connectionRevision;
      _status = widget.controller.status;
      _model.invalidateRuntime();
      if (_status == StreamStatus.connected) scheduleMicrotask(_refresh);
    }
    _changed();
  }

  Future<void> _refresh() async {
    if (_current && _foreground) await _model.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _armTimer();
      unawaited(_refresh());
    } else {
      _timer?.cancel();
      _model.invalidateRuntime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_connectionChanged);
    _model.removeListener(_changed);
    _model.dispose();
    super.dispose();
  }

  bool get _canRegister => _current && !_model.busy && _model.readable;

  /// Runs one model act and turns the error it records into a throw, so a
  /// question running it stays open with the reason (map
  /// `development-services-confirm-sheet`: "action failed").
  Future<void> _act(Future<void> Function() act) async {
    await _idle();
    await act();
    final error = _model.error;
    if (error != null) throw error;
  }

  /// Waits for the model's current act (a log poll, a refresh) to finish:
  /// the model ignores an act asked for while it is busy.
  Future<void> _idle() async {
    if (!_model.busy) return;
    final idle = Completer<void>();
    void check() {
      if (!_model.busy && !idle.isCompleted) idle.complete();
    }

    _model.addListener(check);
    try {
      await idle.future;
    } finally {
      _model.removeListener(check);
    }
  }

  bool _startable(DevelopmentService service) =>
      _supported &&
      _model.readable &&
      switch (_model.status(service)) {
        DevelopmentServiceStatus.notStarted ||
        DevelopmentServiceStatus.stopped => true,
        _ => false,
      };

  bool _isRunning(DevelopmentService service) =>
      _supported && _model.status(service) == DevelopmentServiceStatus.running;

  // --- Add a dev command -------------------------------------------------

  Future<void> _register() async {
    if (!_canRegister) return;
    final l = _l10n;
    final editor = GlobalKey<_ServiceEditorState>();
    final result = await showKitSheet<DevelopmentService>(
      context,
      title: l.servicesAdd,
      subtitle: KitBidi.ltr(_model.directory),
      icon: AppIconography.processor,
      sheetKey: const ValueKey('development-services-editor'),
      body: (_) => _ServiceEditor(
        key: editor,
        directory: _model.directory,
        workspace: _model.workspace,
        profileID: _profileID,
        prefs: widget.controller.store.prefs,
        takenNames: {
          for (final service in _model.services)
            service.name.trim().toLowerCase(),
        },
      ),
      primary: KitAction(
        key: const ValueKey('development-services-save'),
        label: l.servicesSave,
        onPressed: () => editor.currentState?.save(),
      ),
    );
    if (result == null || !_current) return;
    await _model.register(result);
    if (_model.error == null) {
      await _ServiceEditor.clearDrafts(
        widget.controller.store.prefs,
        profileID: _profileID,
        directory: _model.directory,
        workspace: _model.workspace,
      );
    }
  }

  // --- Acts ---------------------------------------------------------------

  /// Start needs no question: it runs at once and offers Stop as its undo.
  Future<void> _start(DevelopmentService service) async {
    if (!_current || !_startable(service)) return;
    await _idle();
    if (!_current || !_model.canStart(service)) return;
    await _model.start(service.id);
    if (!mounted || !_current || _model.error != null) return;
    final l = _l10n;
    showKitUndo(
      context,
      message: l.servicesStarted(service.name),
      undoLabel: l.servicesStop,
      undoKey: const ValueKey('development-services-undo-start'),
      onUndo: () => _act(() => _model.stop(service.id)),
    );
  }

  Future<void> _stop(DevelopmentService service) async {
    if (!_current || !_isRunning(service)) return;
    final l = _l10n;
    await showKitConfirm(
      context,
      title: l.servicesStopTitle(service.name),
      body: l.servicesStopHint,
      confirmLabel: l.servicesStopConfirm,
      kind: KitConfirmKind.stop,
      icon: AppIconography.stop,
      confirmKey: const ValueKey('development-services-confirm'),
      action: () => _act(() => _model.stop(service.id)),
    );
  }

  Future<void> _restart(DevelopmentService service) async {
    if (!_current || !_isRunning(service)) return;
    final l = _l10n;
    await showKitConfirm(
      context,
      title: l.servicesRestartTitle(service.name),
      body: l.servicesRestartHint,
      confirmLabel: l.servicesRestartConfirm,
      icon: AppIconography.restart,
      confirmKey: const ValueKey('development-services-confirm'),
      action: () => _act(() => _model.restart(service.id)),
    );
  }

  Future<void> _forget(DevelopmentService service) async {
    if (!_current) return;
    final l = _l10n;
    await showKitConfirm(
      context,
      title: l.servicesForgetTitle(service.name),
      body: l.servicesForgetHint,
      confirmLabel: l.servicesForget,
      icon: AppIconography.info,
      confirmKey: const ValueKey('development-services-confirm'),
      action: () => _act(() => _model.forgetRun(service.id)),
    );
  }

  /// A saved configuration comes back with Undo. When a command may still
  /// be running it asks instead: the command keeps running on the server
  /// and this screen can no longer stop it.
  Future<void> _remove(DevelopmentService service) async {
    if (!_current || _model.busy) return;
    final l = _l10n;
    final live = service.run != null && !service.run!.stopped;
    if (live) {
      await showKitConfirm(
        context,
        title: l.servicesRemoveTitle(service.name),
        body: l.servicesRemoveRunningHint,
        confirmLabel: l.servicesRemove,
        kind: KitConfirmKind.destructive,
        icon: AppIconography.delete,
        confirmKey: const ValueKey('development-services-confirm'),
        action: () => _act(() => _model.remove(service.id)),
      );
      return;
    }
    await _model.remove(service.id);
    if (!mounted || !_current || _model.error != null) return;
    showKitUndo(
      context,
      message: l.servicesRemoved(service.name),
      undoKey: const ValueKey('development-services-undo-remove'),
      onUndo: () => _act(() => _model.register(service.withRun(null))),
    );
  }

  void _visit(DevelopmentService service) {
    if (_current) unawaited(openExternalLink(context, service.url));
  }

  // --- Logs ---------------------------------------------------------------

  static List<KitLogLine> _linesOf(String? text) {
    if (text == null || text.isEmpty) return const [];
    final lines = text.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return [for (final line in lines) KitLogLine(line)];
  }

  /// The log of a tracked run: one kit log panel that follows the newest
  /// line, polls only while it is open, copies, and says whether the
  /// command is live or ended; Stop and Restart sit under it.
  Future<void> _logs(DevelopmentService service) async {
    if (!_current) return;
    final l = _l10n;
    final lines = ValueNotifier<List<KitLogLine>>(
      _linesOf(_model.logs[service.id]),
    );
    void sync() => lines.value = _linesOf(_model.logs[service.id]);
    final running = _isRunning(service);
    _model.addListener(sync);
    unawaited(_model.readLogs(service.id));
    try {
      await showKitSheet<void>(
        context,
        title: '${service.name} · ${l.servicesLogs}',
        icon: AppIconography.text,
        height: KitSheetHeight.full,
        sheetKey: const ValueKey('development-services-logs'),
        body: (_) => ListenableBuilder(
          listenable: _model,
          builder: (context, _) => _logBody(context, service, lines),
        ),
        primary: running
            ? KitAction(
                label: l.servicesStop,
                icon: AppIconography.stop,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(_stop(service));
                },
              )
            : null,
        secondary: running
            ? KitAction(
                label: l.servicesRestart,
                icon: AppIconography.restart,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(_restart(service));
                },
              )
            : null,
      );
    } finally {
      _model.removeListener(sync);
      lines.dispose();
    }
  }

  /// Reads the log again, so the report carries this run's current tail
  /// and not an older read, then opens Report a problem with it. A failed
  /// read keeps the sheet open with its error and Refresh.
  /// [sheet] is the logs sheet's context; the page opens from this
  /// screen's once the sheet is closed.
  Future<void> _report(BuildContext sheet, DevelopmentService service) async {
    await _model.readLogs(service.id);
    if (!_current || _model.error != null || !sheet.mounted) return;
    final report = _model.failedReport(service.id);
    if (report == null) return;
    Navigator.of(sheet).pop();
    if (!mounted) return;
    unawaited(openFailedJobReport(context, report));
  }

  Widget _logBody(
    BuildContext context,
    DevelopmentService service,
    ValueNotifier<List<KitLogLine>> lines,
  ) {
    final l = _l10n;
    final tokens = KitTokens.of(context);
    if (!_current) {
      return KitStateView(
        icon: AppIconography.info,
        title: l.servicesScopeChanged,
        size: KitStateSize.inline,
      );
    }
    final current = _model.services.where((s) => s.id == service.id);
    final status = current.isEmpty
        ? DevelopmentServiceStatus.unknown
        : _model.status(current.first);
    final stopped = status == DevelopmentServiceStatus.stopped;
    final error = _model.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          KitNotice.error(
            key: const ValueKey('development-services-log-error'),
            message: l.servicesLogFailed,
            error: error,
            retry: KitAction(
              label: l.servicesRefresh,
              onPressed: () => unawaited(_model.readLogs(service.id)),
            ),
          ),
          SizedBox(height: tokens.space3),
        ],
        KitLogPanel(
          lines: lines,
          title: l.servicesLogs,
          live: status == DevelopmentServiceStatus.running,
          ended: stopped ? KitLogEnd(exitCode: _model.exitCode(service)) : null,
          emptyText: l.servicesLogEmpty,
          onRefresh: stopped ? null : () => _model.readLogs(service.id),
          // A failed run (nonzero exit, timeout, killed) is reported from
          // the log it failed with (P8.4).
          headerAction: _model.failedReport(service.id) == null
              ? null
              : KitAction(
                  key: ValueKey('development-service-report-${service.id}'),
                  label: l.failedJobReport,
                  icon: AppIconography.bug,
                  onPressed: _model.busy
                      ? null
                      : () => _report(context, service),
                ),
        ),
      ],
    );
  }

  // --- The page -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = _l10n;
    final current = _current;
    final services = current ? _model.services : const <DevelopmentService>[];
    return KitScreen(
      width: KitScreenWidth.list,
      topBar: KitTopBar(
        title: l.servicesTitle,
        actions: [
          if (current && services.isNotEmpty)
            KitAction(
              key: const ValueKey('development-services-add'),
              label: l.servicesAdd,
              icon: AppIconography.add,
              onPressed: _canRegister ? _register : null,
            ),
        ],
        menu: [
          if (current)
            KitMenuItem(
              key: const ValueKey('development-services-refresh'),
              label: l.servicesRefresh,
              icon: AppIconography.retry,
              enabled: !_model.busy,
              onSelected: () => unawaited(_refresh()),
            ),
        ],
      ),
      loading: current && _model.busy,
      loadingLabel: l.servicesWorking,
      body: !current
          ? KitStateView(
              icon: AppIconography.info,
              title: l.servicesScopeChanged,
            )
          : KitRefresh(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: KitScreen.padding(context),
                children: _content(context, l, services),
              ),
            ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    AppLocalizations l,
    List<DevelopmentService> services,
  ) {
    final tokens = KitTokens.of(context);
    final error = _model.error;
    final offline =
        _supported && widget.controller.status != StreamStatus.connected;
    return [
      if (!_supported) ...[
        KitNotice(
          key: const ValueKey('development-services-unsupported'),
          message: l.servicesUnavailable,
          icon: AppIconography.info,
        ),
        SizedBox(height: tokens.space3),
      ] else if (offline) ...[
        KitNotice(
          key: const ValueKey('development-services-offline'),
          message: l.servicesOffline,
          icon: AppIconography.info,
        ),
        SizedBox(height: tokens.space3),
      ],
      if (error != null) ...[
        KitNotice.error(
          key: const ValueKey('development-services-error'),
          message: productErrorText(error),
          error: error,
          retry: KitAction(
            label: l.servicesRefresh,
            onPressed: () => unawaited(_refresh()),
          ),
        ),
        SizedBox(height: tokens.space3),
      ],
      if (services.isEmpty)
        KitStateView(
          icon: AppIconography.processor,
          title: l.servicesEmptyTitle,
          body: l.servicesIntro,
          size: KitStateSize.inline,
          primary: KitAction(
            key: const ValueKey('development-services-add-first'),
            label: l.servicesAdd,
            icon: AppIconography.add,
            onPressed: _canRegister ? _register : null,
          ),
        )
      else ...[
        // One rail (R5): the list's gutter, none of the panel's own.
        KitRowGroup(
          margin: EdgeInsets.zero,
          children: [for (final service in services) _row(context, l, service)],
        ),
        SizedBox(height: tokens.space2),
        KitText(l.servicesStatusHint, role: KitTextRole.secondary),
      ],
      SizedBox(height: tokens.sectionGap),
      KitDetailsFold(
        values: [
          KitTechnicalValue(l.servicesProjectFolder, _model.directory),
          if (_model.workspace case final workspace?)
            KitTechnicalValue(l.servicesWorkspace, workspace),
        ],
      ),
    ];
  }

  String _statusWord(AppLocalizations l, DevelopmentServiceStatus status) =>
      switch (status) {
        DevelopmentServiceStatus.notStarted => l.servicesNotStarted,
        DevelopmentServiceStatus.running => l.servicesRunning,
        DevelopmentServiceStatus.stopped => l.servicesStopped,
        DevelopmentServiceStatus.unknown => l.servicesUnknown,
      };

  List<KitMenuItem> _menu(
    AppLocalizations l,
    DevelopmentService service,
    DevelopmentServiceStatus status,
  ) {
    final tracked = service.run != null && !service.run!.stopped;
    return [
      if (_startable(service))
        KitMenuItem(
          label: l.servicesStart,
          icon: AppIconography.play,
          onSelected: () => unawaited(_start(service)),
        ),
      if (_isRunning(service)) ...[
        KitMenuItem(
          label: l.servicesStop,
          icon: AppIconography.stop,
          onSelected: () => unawaited(_stop(service)),
        ),
        KitMenuItem(
          label: l.servicesRestart,
          icon: AppIconography.restart,
          onSelected: () => unawaited(_restart(service)),
        ),
      ],
      if (tracked && _supported)
        KitMenuItem(
          key: ValueKey('development-service-logs-${service.id}'),
          label: l.servicesLogs,
          icon: AppIconography.text,
          enabled: !_model.busy,
          onSelected: () => unawaited(_logs(service)),
        ),
      if (safeExternalLinkUri(service.url) != null)
        KitMenuItem(
          key: ValueKey('development-service-visit-${service.id}'),
          label: l.servicesVisit,
          icon: AppIconography.externalLink,
          onSelected: () => _visit(service),
        ),
      KitMenuItem.copy(label: l.servicesCopy, text: () => service.command),
      if (status == DevelopmentServiceStatus.unknown)
        KitMenuItem(
          label: l.servicesForget,
          icon: AppIconography.info,
          enabled: !_model.busy,
          onSelected: () => unawaited(_forget(service)),
        ),
      KitMenuItem(
        key: ValueKey('development-service-remove-${service.id}'),
        label: l.servicesRemove,
        icon: AppIconography.delete,
        destructive: true,
        enabled: !_model.busy,
        onSelected: () => unawaited(_remove(service)),
      ),
    ];
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    DevelopmentService service,
  ) {
    final status = _model.status(service);
    final running = status == DevelopmentServiceStatus.running;
    final code = _model.exitCode(service);
    final menu = _menu(l, service, status);
    final tracked = service.run != null && !service.run!.stopped;
    final Widget? trailing = _isRunning(service)
        ? KitIconButton(
            key: ValueKey('development-service-stop-${service.id}'),
            icon: AppIconography.stop,
            tooltip: l.servicesStopNamed(service.name),
            onPressed: () => unawaited(_stop(service)),
          )
        : _startable(service)
        ? KitIconButton(
            key: ValueKey('development-service-start-${service.id}'),
            icon: AppIconography.play,
            tooltip: l.servicesStartNamed(service.name),
            onPressed: () => unawaited(_start(service)),
          )
        : null;
    return KitRow(
      key: ValueKey('development-service-${service.id}'),
      leading: KitRowIcon(AppIconography.processor, current: running),
      title: service.name,
      supporting: TextSpan(
        children: [
          TextSpan(text: _statusWord(l, status)),
          if (code != null && status == DevelopmentServiceStatus.stopped)
            TextSpan(text: ' · ${l.servicesExit(code)}'),
          TextSpan(text: ' · ${KitBidi.ltr(service.command)}'),
        ],
      ),
      supportingMaxLines: 2,
      below: status == DevelopmentServiceStatus.unknown
          ? KitText(l.servicesUnknownHint, role: KitTextRole.secondary)
          : service.url.isEmpty
          ? null
          : KitText.mono(service.url, cut: KitMonoCut.end),
      trailing: trailing,
      menu: menu,
      menuLabel: service.name,
      onTap: tracked && _supported
          ? () => unawaited(_logs(service))
          : () => unawaited(KitRowMenu.show(context, menu)),
    );
  }
}

/// The add form: three labelled fields, each keeping what was typed across
/// swipe, back, Esc, close and a process kill (P7.1: the key is
/// `oc.draft.<target>.<profileId>`, swept with the profile). The drafts
/// are cleared once the service is saved.
class _ServiceEditor extends StatefulWidget {
  const _ServiceEditor({
    super.key,
    required this.directory,
    required this.workspace,
    required this.profileID,
    required this.prefs,
    required this.takenNames,
  });
  final String directory;
  final String? workspace;
  final String profileID;
  final SharedPreferences prefs;
  final Set<String> takenNames;

  static const _fields = ['name', 'command', 'url'];

  /// A stable, short scope for this project's drafts (FNV-1a over the
  /// folder and workspace), so each project keeps its own half-typed form.
  static String _scope(String directory, String? workspace) {
    var hash = 0x811c9dc5;
    for (final unit in '$directory\u0000${workspace ?? ''}'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String target(String field, String directory, String? workspace) =>
      'developmentService.$field.${_scope(directory, workspace)}';

  static Future<void> clearDrafts(
    SharedPreferences prefs, {
    required String profileID,
    required String directory,
    required String? workspace,
  }) async {
    if (profileID.isEmpty) return;
    for (final field in _fields) {
      await prefs.remove(
        KitDraft.keyFor(target(field, directory, workspace), profileID),
      );
    }
  }

  @override
  State<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<_ServiceEditor> {
  final _name = TextEditingController();
  final _command = TextEditingController();
  final _url = TextEditingController();
  String? _nameError;
  String? _commandError;
  String? _urlError;

  KitDraft? _draft(String field, TextEditingController controller) =>
      widget.profileID.isEmpty
      ? null
      : KitDraft(
          target: _ServiceEditor.target(
            field,
            widget.directory,
            widget.workspace,
          ),
          profileId: widget.profileID,
          controller: controller,
          prefs: widget.prefs,
        );

  late final KitDraft? _nameDraft = _draft('name', _name);
  late final KitDraft? _commandDraft = _draft('command', _command);
  late final KitDraft? _urlDraft = _draft('url', _url);

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _url.dispose();
    super.dispose();
  }

  void save() {
    final l = lookupAppLocalizations(Localizations.localeOf(context));
    final name = _name.text.trim();
    final command = _command.text.trim();
    final url = _url.text.trim();
    setState(() {
      _nameError = name.isEmpty
          ? l.servicesNameRequired
          : widget.takenNames.contains(name.toLowerCase())
          ? l.servicesDuplicateName
          : null;
      _commandError = command.isEmpty ? l.servicesCommandRequired : null;
      _urlError = url.isNotEmpty && safeExternalLinkUri(url) == null
          ? l.servicesUrlInvalid
          : null;
    });
    if (_nameError != null || _commandError != null || _urlError != null) {
      return;
    }
    Navigator.of(context).pop(
      DevelopmentService(
        id: DevelopmentServices.newID(),
        name: name,
        command: command,
        directory: widget.directory,
        workspace: widget.workspace,
        url: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitField(
          label: l.servicesName,
          controller: _nameDraft == null ? _name : null,
          draft: _nameDraft,
          maxLength: 80,
          error: _nameError,
          textInputAction: TextInputAction.next,
          fieldKey: const ValueKey('development-services-name'),
        ),
        SizedBox(height: tokens.space4),
        KitField(
          label: l.servicesCommand,
          kind: KitFieldKind.mono,
          controller: _commandDraft == null ? _command : null,
          draft: _commandDraft,
          helper: l.servicesCommandHint,
          maxLength: 4096,
          error: _commandError,
          textInputAction: TextInputAction.next,
          fieldKey: const ValueKey('development-services-command'),
        ),
        SizedBox(height: tokens.space4),
        KitField(
          label: l.servicesUrl,
          kind: KitFieldKind.url,
          controller: _urlDraft == null ? _url : null,
          draft: _urlDraft,
          helper: l.servicesUrlHint,
          maxLength: 2048,
          error: _urlError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => save(),
          fieldKey: const ValueKey('development-services-url'),
        ),
      ],
    );
  }
}
