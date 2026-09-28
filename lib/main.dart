import 'ui/search/search_index.dart';
import 'ui/screens/profile_monitor_screen.dart';
import 'ui/screens/usage_hub_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background/live_background.dart';
import 'builtin/app_exit_recovery.dart';
import 'builtin/builtin_server.dart';
import 'builtin/phone_server_healing.dart';
import 'builtin/setup/phone_setup.dart';
import 'builtin/setup/setup_finish.dart';
import 'builtin/setup/termux_setup_finish.dart';
import 'builtin/thermal_guard.dart' show ThermalNoticeKind;
import 'builtin/thermal_guard_teams.dart';
import 'desktop/window_icon.dart';
import 'desktop/window_state.dart';
import 'diagnostics/app_diagnostics.dart';
import 'diagnostics/perf_trace.dart';
import 'diagnostics/report_problem_startup.dart';
import 'domain/connection_status.dart';
import 'domain/server_gateway.dart' show ProductException;
import 'l10n/app_localizations.dart';
import 'platform/launch_shortcut.dart';
import 'platform/session_link.dart';
import 'state/session_address_controller.dart'
    show SessionAddressFailure, sessionAddressProvider;
import 'platform/platform_capabilities.dart';
import 'platform/share_intent.dart';
import 'domain/session_handoff.dart';
import 'domain/while_away.dart' show AutomaticActKind;
import 'domain/team_link.dart';
import 'state/connection.dart';
import 'state/automation_policy.dart';
import 'state/local_server_controls.dart';
import 'termux/bridge.dart';
import 'state/profiles.dart';
import 'update/desktop_release_check.dart';
import 'update/shorebird_update_notice.dart';
import 'ui/app_theme.dart';
import 'ui/capability_flows.dart';
import 'ui/desktop/desktop_interaction.dart';
import 'ui/desktop/shortcuts.dart';
import 'ui/kit/kit.dart';
import 'ui/theme_packs.dart';
import 'ui/navigation/attention_landing.dart' show chatLandingPage;
import 'ui/navigation/chat_route.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/product_states.dart' show productErrorText;
import 'ui/widgets/saved_server_connection_card.dart';
import 'ui/widgets/session_address_sheets.dart';
import 'ui/widgets/last_known_sessions.dart';
import 'ui/widgets/app_connection_status.dart';
import 'ui/widgets/phone_server_card.dart' show serverDisplayName;
import 'ui/screens/guide_screen.dart';
import 'ui/screens/about_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/activity_screen.dart';
import 'ui/screens/team_conversation/team_conversation.dart'
    show TeamConversation;
import 'ui/screens/this_phone_screen.dart';
import 'state/phone_host.dart' show PhoneHostKind;
import 'ui/screens/phone_setup/phone_setup_routes.dart'
    show openPhoneSetupFromNotification, openPhoneSetupStart;
import 'ui/screens/app_diagnostics_screen.dart';

Future<void> main() async {
  // First thing: starts the trace clock, so every later OCTRACE `at=` reads
  // as time since launch.
  PerfTrace.markOnce('app.main');
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    // Restores the remembered size, position and maximized state, clamped to
    // a display that still exists, and saves it again on close. Android never
    // reaches this call. See lib/desktop/window_state.dart.
    //
    // The one platform branch that deliberately stays on dart:io rather than
    // PlatformCapabilities: this is about the process that is actually
    // running — whether a native window exists to size — not about a feature
    // a test needs to pump both ways. `main` is never entered by the suite,
    // so routing it through an overridable seam would only add a way for a
    // stray override to leave a real desktop window unshown.
    //
    // The icon is applied after, not inside: setUpDesktopWindow completes
    // only once waitUntilReadyToShow has shown and focused the window, and
    // GTK needs a realised window to hang an icon on.
    unawaited(setUpDesktopWindow().then((_) => applyDesktopWindowIcon()));
  }
  final diagnostics = AppDiagnosticsController();
  installAppErrorCapture(diagnostics);
  runApp(AppBootstrapGate(diagnostics: diagnostics));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PerfTrace.markOnce('app.first_frame');
    // Disk-backed diagnostics are not needed to paint the opening state.
    // Capture imports buffered errors/timings when the store attaches, so
    // installing in-memory error capture above still protects early failures.
    unawaited(ReportProblemStartup.start(diagnostics));
  });
}

typedef AppBootstrapLoader = Future<AppBootstrap> Function();

/// Renders immediately so a preferences or secure-storage failure can never
/// leave Android showing a blank native window.
class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({
    super.key,
    required this.diagnostics,
    this.loader,
    this.controllerFactory,
    this.resetSavedSignIns,
  });

  final AppDiagnosticsController diagnostics;
  final AppBootstrapLoader? loader;

  /// Supplies controlled transports for startup ordering tests.
  @visibleForTesting
  final ConnectionController Function(
    ProfileStore store,
    AppDiagnosticsController diagnostics,
  )?
  controllerFactory;

  /// Injectable boundary for the confirmed reset; never loads saved metadata.
  final Future<void> Function()? resetSavedSignIns;

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  AppBootstrap? _bootstrap;
  ConnectionController? _controller;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  bool _resetting = false;
  bool _resetFailed = false;
  bool _resetConfirming = false;
  final Set<Future<void>> _loads = {};

  /// When this attempt to open began: after 8 s the page says it is still
  /// opening and offers Try again (STATE-5).
  DateTime _since = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Every kit error state offers "Report a problem" (P8.3, C26): Report a
    // problem opens with the failure attached, from the very first page on,
    // so even a start that fails can be reported.
    KitReportHook.handler = (context, report) =>
        openReportProblem(context, error: report);
    // Even the synchronous part of preferences/Keystore setup waits until
    // the opening state has painted. Draft/photo/notification prerequisites
    // below still complete before any conversation or connection is exposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load(initial: true));
    });
  }

  Future<void> _load({bool initial = false}) {
    if (_resetting) return Future<void>.value();
    final pending = _runLoad(initial: initial);
    _loads.add(pending);
    unawaited(pending.whenComplete(() => _loads.remove(pending)));
    return pending;
  }

  Future<void> _runLoad({bool initial = false}) async {
    final generation = ++_generation;
    // Initial fields already describe the opening state. Do not schedule a
    // redundant opening-state rebuild merely because work starts post-frame.
    if (!initial) {
      setState(() {
        _loading = true;
        _resetFailed = false;
        _error = null;
        _since = DateTime.now();
      });
    }
    ConnectionController? pendingController;
    try {
      final bootstrap = await PerfTrace.span(
        'app.bootstrap',
        widget.loader ?? AppBootstrap.create,
      );
      if (!mounted || generation != _generation) return;
      final controller =
          widget.controllerFactory?.call(bootstrap.store, widget.diagnostics) ??
          ConnectionController(
            bootstrap.store,
            diagnostics: widget.diagnostics,
          );
      pendingController = controller;
      // Before any conversation reads its draft: the older drafts move into
      // Saved prompts, then a photo the camera handed back after Android
      // stopped the app joins its own conversation's draft (P3.2). Both keep
      // their source on failure and retry on the next start.
      await controller.migrateOlderDrafts();
      if (platformCapabilities.supportsPromptPhotos) {
        await controller.recoverPendingPhoto();
      }
      // Before anything can alert: quiet hours and Wi-Fi only become one
      // shared definition. Idempotent, and a failure leaves the legacy
      // per-server records in charge.
      try {
        await controller.migrateNotificationPreferences();
      } catch (error, stack) {
        widget.diagnostics.record(error, stack, source: 'notify-migration');
      }
      if (!mounted || generation != _generation) {
        controller.dispose();
        return;
      }
      _controller?.dispose();
      pendingController = null;
      setState(() {
        _bootstrap = bootstrap;
        _controller = controller;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => PerfTrace.markOnce('app.shell_frame'),
      );
    } catch (error, stack) {
      pendingController?.dispose();
      widget.diagnostics.record(error, stack, source: 'bootstrap');
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _startFresh(BuildContext context) async {
    if (_resetting || _resetConfirming) return;
    _resetConfirming = true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showKitConfirm(
      context,
      kind: KitConfirmKind.destructive,
      title: l10n.bootstrapStartFreshTitle,
      body: l10n.bootstrapStartFreshBody,
      confirmLabel: l10n.bootstrapStartFreshConfirm,
      confirmKey: const ValueKey('confirm-start-fresh'),
    );
    _resetConfirming = false;
    if (!confirmed || !mounted) return;
    await _resetSignIns();
  }

  Future<void> _resetSignIns() async {
    if (_resetting || !mounted) return;
    // Invalidate loaders before waiting: no old result can mount a controller
    // or reconnect with the credentials this reset is about to erase.
    ++_generation;
    setState(() {
      _resetting = true;
      _error = null;
    });
    await Future.wait(_loads.toList());
    if (!mounted) return;
    _controller?.dispose();
    _controller = null;
    _bootstrap = null;
    try {
      await (widget.resetSavedSignIns ?? AppBootstrap.resetSavedSignIns)();
      if (!mounted) return;
      setState(() => _resetting = false);
      await _load();
    } catch (error, stack) {
      widget.diagnostics.record(error, stack, source: 'bootstrap-reset');
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _loading = false;
        _resetFailed = true;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = _bootstrap;
    final controller = _controller;
    if (bootstrap != null && controller != null) {
      return ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(bootstrap),
          connProvider.overrideWithValue(controller),
        ],
        child: const OcApp(),
      );
    }
    return MaterialApp(
      title: 'OpenCode Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => _Ground(
          child: KitScreen(
            width: KitScreenWidth.reading,
            body: _bootstrapState(context),
          ),
        ),
      ),
    );
  }

  /// The app opening (map page bootstrap-gate): "Opening…" while the saved
  /// servers are read, then, if that fails, what failed in words with Try
  /// again, Copy details and Report a problem; the reason is under Details.
  Widget _bootstrapState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_resetting) {
      return KitStateView(
        key: const ValueKey('app-bootstrap-resetting'),
        icon: AppIconography.waiting,
        tone: AppStatusTone.progress,
        title: l10n.bootstrapResettingTitle,
        body: l10n.bootstrapResettingBody,
        progress: const KitProgress.waiting(),
      );
    }
    final retry = KitAction(
      key: const ValueKey('retry-app-bootstrap'),
      label: l10n.commonRetry,
      onPressed: () => unawaited(_resetFailed ? _resetSignIns() : _load()),
    );
    final reset = KitAction(
      key: const ValueKey('start-fresh-app-bootstrap'),
      label: l10n.bootstrapStartFresh,
      onPressed: () => unawaited(_startFresh(context)),
    );
    final error = _error;
    if (_loading || error == null) {
      return KitStateView(
        key: const ValueKey('app-bootstrap-opening'),
        icon: AppIconography.waiting,
        tone: AppStatusTone.progress,
        title: l10n.bootstrapOpeningTitle,
        body: l10n.bootstrapOpeningBody,
        progress: const KitProgress.waiting(),
        since: _since,
        onSlow: [retry],
      );
    }
    return KitStateView.error(
      key: const ValueKey('app-bootstrap-failed'),
      title: _resetFailed
          ? l10n.bootstrapResetFailedTitle
          : l10n.bootstrapFailedTitle,
      body: _resetFailed
          ? l10n.bootstrapResetFailedBody
          : l10n.bootstrapFailedBody,
      error: error,
      details: widget.diagnostics.sanitize(error.toString(), limit: 300),
      retry: retry,
      secondary: reset,
      reportSource: 'bootstrap-gate',
    );
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }
}

class OcApp extends ConsumerStatefulWidget {
  const OcApp({
    super.key,
    this.updateService,
    this.shareIntent,
    this.launchShortcut,
    this.sessionLinkIntent,
  });

  final AppUpdateService? updateService;

  /// Text shared in from other apps; injectable so tests can drive it.
  final ShareIntent? shareIntent;

  /// Home-screen shortcut actions (Connect, New task); injectable so tests
  /// can drive it. Absent, the app owns a real [LaunchShortcut].
  final LaunchShortcut? launchShortcut;

  /// Session handoff links (`opencode-mobile://session`) opened on this
  /// phone; injectable so tests can drive it. Absent, the app owns a real
  /// [SessionLinkIntent].
  final SessionLinkIntent? sessionLinkIntent;

  @override
  ConsumerState<OcApp> createState() => _OcAppState();
}

class _OcAppState extends ConsumerState<OcApp> with WidgetsBindingObserver {
  late final ConnectionController _controller;
  late final AppUpdateService _updateService;
  final _navigatorKey = GlobalKey<NavigatorState>();
  // Desktop only: the shell shortcut registry. Surfaces claim intents through
  // it, and the Ctrl+K launcher dispatches the same intents the keyboard does.
  final _shortcutSignals = AppShortcutSignals();
  bool _codingAlertRouteScheduled = false;
  late final ShareIntent _share;
  bool _shareRouteScheduled = false;
  String? _failedShareText;
  bool _shareWaitingNoticeShown = false;
  late final LaunchShortcut _launchShortcut;
  bool _launchRouteScheduled = false;
  bool _launchWaitingNoticeShown = false;
  late final SessionLinkIntent _sessionLink;
  bool _linkRouteScheduled = false;
  bool _teamLinkRouteScheduled = false;
  bool _addressLinkRouteScheduled = false;
  bool _addressSheetOpen = false;
  bool _linkWaitingNoticeShown = false;
  // Tracks the route on top of the shell navigator so a shortcut never
  // stacks a second servers screen over one already showing.
  final _routeTracker = _TopRouteTracker();
  final _routeTiming = PerfTraceNavigatorObserver();

  /// The app's own condition in every screen's one status line (added to
  /// KitStatusScope above the navigator): a share or a launch waiting for
  /// the server, and what became of one that could not open. It replaced
  /// the snackbars and the share banner (G1).
  final _notice = ValueNotifier<KitStatus?>(null);
  Timer? _noticeTimer;
  Object? _shareFailure;
  int _shareFailures = 0;

  static const _waitingNotice = 'app:waiting';
  static const _shareWaitingNotice = 'app:share-waiting';
  static const _shareFailedNotice = 'app:share-failed';
  static const _oneShotNotice = 'app:notice';

  @override
  void initState() {
    super.initState();
    unawaited(_harvestDynamicColors());
    _controller = ref.read(connProvider);
    // Every capabilities.json enable flow resolves to its page (C20), so a
    // missing capability offers "Turn it on" wherever that can happen here.
    registerCapabilityFlows(_controller);
    ref.read(phoneServerHealingProvider);
    _controller.addListener(_controllerChanged);
    _share = widget.shareIntent ?? ShareIntent();
    _share.pending.addListener(_scheduleShareRoute);
    unawaited(_share.start());
    _launchShortcut = widget.launchShortcut ?? LaunchShortcut();
    _launchShortcut.pending.addListener(_scheduleLaunchRoute);
    _launchShortcut.pendingSession.addListener(_scheduleLaunchRoute);
    unawaited(_launchShortcut.start());
    _sessionLink = widget.sessionLinkIntent ?? SessionLinkIntent();
    _sessionLink.pending.addListener(_scheduleSessionLinkRoute);
    _sessionLink.pendingTeam.addListener(_scheduleTeamLinkRoute);
    _sessionLink.pendingAddress.addListener(_scheduleAddressLinkRoute);
    _sessionLink.pendingAddressFailure.addListener(_scheduleAddressLinkRoute);
    unawaited(_sessionLink.start());
    // Only the Android build is Shorebird-released; desktop gets its update
    // news from the GitHub release check in DesktopReleaseNotice below.
    _updateService =
        widget.updateService ??
        (platformCapabilities.supportsCodePush
            ? ShorebirdAppUpdateService()
            : const UnavailableAppUpdateService());
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_controller.restoreBackgroundLiveMode());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(phoneServerHealingProvider)
        .setForeground(state == AppLifecycleState.resumed);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_resumeAndConsumeCodingAlert());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _controller.suspendForLifecycle();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _resumeAndConsumeCodingAlert() async {
    // Start destination capture before wake reconciliation performs any
    // potentially slow health or catalog requests, while allowing transport
    // recovery to proceed in parallel. Routing still waits for a usable
    // transport when the background connection had been suspended.
    await Future.wait<void>([
      _controller.consumeCodingAlertOpen(),
      _resumeTransport(),
    ]);
  }

  /// Resume uses the same durable recovery budget as crash monitoring.
  Future<void> _resumeTransport() async {
    final profile = _controller.profile;
    final healing = ref.read(phoneServerHealingProvider);
    if (looksLikeInAppServer(profile)) await healing.check(profile!);
    await _controller.resumeFromLifecycle();
    if (looksLikeInAppServer(profile)) await healing.connectIfNeeded(profile!);
  }

  /// Shows [status] as the app's line. A [lasting] one stays until its
  /// condition ends; any other goes after the kit's undo window, except
  /// under accessible navigation, where it waits for Dismiss.
  void _showNotice(KitStatus status, {bool lasting = false}) {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _notice.value = status;
    if (lasting) return;
    _noticeTimer = Timer(KitMotion.undoWindow, () {
      final context = _navigatorKey.currentContext;
      if (context != null && MediaQuery.accessibleNavigationOf(context)) {
        return;
      }
      _clearNotice(status.id!);
    });
  }

  void _clearNotice(String id) {
    if (_notice.value?.id != id) return;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _notice.value = null;
  }

  /// A line that says what just happened, with Dismiss. [supporting] is
  /// words ([productErrorText]), never the raw failure.
  void _say(String message, {String? supporting, bool failed = false}) {
    _showNotice(
      KitStatus(
        // `work`: the person's own act, above "Update ready".
        kind: KitStatusKind.work,
        id: _oneShotNotice,
        icon: failed ? AppIconography.error : AppIconography.info,
        tone: failed ? AppStatusTone.failure : AppStatusTone.neutral,
        message: message,
        supporting: supporting,
        onDismiss: () => _clearNotice(_oneShotNotice),
      ),
    );
  }

  /// A launch, link or share that opens once the server answers.
  void _showWaiting(String id, String message) {
    _showNotice(
      KitStatus(
        kind: KitStatusKind.work,
        id: id,
        icon: AppIconography.waiting,
        message: message,
      ),
      lasting: true,
    );
  }

  void _controllerChanged() {
    _scheduleCodingAlertRoute();
    _scheduleShareRoute();
    _scheduleLaunchRoute();
    _scheduleSessionLinkRoute();
    _scheduleTeamLinkRoute();
  }

  /// Text shared from another app becomes the first prompt of a new session.
  /// Until a server is connected the text waits, and the user is told once
  /// where it went, so a share never silently disappears.
  void _scheduleShareRoute() {
    if (_shareRouteScheduled ||
        _share.pending.value == null ||
        _share.pending.value == _failedShareText) {
      return;
    }
    final connected =
        _controller.hasConnectedServer &&
        !_controller.connectionLoading &&
        !_controller.locationLoading;
    if (!connected) {
      if (!_shareWaitingNoticeShown) {
        _shareWaitingNoticeShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (!mounted || context == null) return;
          _showWaiting(
            _shareWaitingNotice,
            AppLocalizations.of(context).shareWaitingForServer,
          );
        });
      }
      return;
    }
    _shareRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _shareWaitingNoticeShown = false;
      _clearNotice(_shareWaitingNotice);
      if (!mounted) return;
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _shareRouteScheduled = false;
        _scheduleShareRoute();
        return;
      }
      if (_controller.connectionLoading || _controller.locationLoading) {
        _shareRouteScheduled = false;
        return;
      }
      final text = _share.pending.value;
      if (text == null) {
        _shareRouteScheduled = false;
        return;
      }
      final location = _controller.locationRevision;
      final api = _controller.api;
      final repository = _controller.repository;
      try {
        final session = await _controller.createSession();
        if (!mounted) return;
        if (location != _controller.locationRevision ||
            !identical(api, _controller.api) ||
            !identical(repository, _controller.repository)) {
          throw ProductException(
            AppLocalizations.of(navigator.context).shareConnectionChanged,
          );
        }
        unawaited(
          navigator.push(
            KitPageRoute<void>(
              builder: (_) =>
                  ChatScreen(sessionID: session.id, initialText: text),
            ),
          ),
        );
        if (_share.pending.value == text) _share.take();
        _failedShareText = null;
        _shareFailure = null;
        _shareFailures = 0;
        _clearNotice(_shareFailedNotice);
      } catch (error) {
        if (!mounted) return;
        // A newer share replaced this text meanwhile: that one goes next.
        if (_share.pending.value == text) {
          _failedShareText = text;
          _shareFailure = error;
          _shareFailures += 1;
          _showShareFailed(text);
        }
      } finally {
        _shareRouteScheduled = false;
        if (mounted) _scheduleShareRoute();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The shared text could not open a conversation (map page
  /// share-session-failed-banner): it stays saved, the line says why in
  /// words, Try again opens it, and More copies or discards it, so the text
  /// is never lost behind a dismissed banner. A second failure says so.
  void _showShareFailed(String text) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final l10n = AppLocalizations.of(context);
    final failure = _shareFailure;
    _showNotice(
      KitStatus(
        kind: KitStatusKind.work,
        id: _shareFailedNotice,
        icon: AppIconography.outbox,
        tone: AppStatusTone.failure,
        message: _shareFailures > 1
            ? l10n.shareFailedAgainLine
            : l10n.shareFailedLine,
        supporting: failure == null
            ? null
            : productErrorText(failure, l10n: l10n),
        action: KitAction(
          key: const ValueKey('share-failed-retry'),
          label: l10n.commonRetry,
          onPressed: _retryShare,
        ),
        more: [
          KitAction(
            key: const ValueKey('share-failed-copy'),
            label: l10n.shareFailedCopy,
            icon: AppIconography.copy,
            onPressed: () {
              final target = _routeTracker.topContext;
              if (target == null) return;
              // The person's own words: copied as they are (SEC-13).
              unawaited(KitCopy.copy(target, text, redact: false));
            },
          ),
          KitAction(
            key: const ValueKey('share-failed-discard'),
            label: l10n.shareFailedDiscard,
            icon: AppIconography.delete,
            destructive: true,
            onPressed: () => _discardShare(text),
          ),
        ],
      ),
      lasting: true,
    );
  }

  void _retryShare() {
    if (!mounted) return;
    _failedShareText = null;
    _clearNotice(_shareFailedNotice);
    _scheduleShareRoute();
  }

  /// Discards the saved shared text with Undo: it is dropped only when the
  /// Undo bar goes.
  void _discardShare(String text) {
    // The top page's context: under the overlay the Undo bar goes into.
    final context = _routeTracker.topContext;
    if (context == null) return;
    _clearNotice(_shareFailedNotice);
    showKitUndo(
      context,
      key: const ValueKey('share-discarded'),
      message: AppLocalizations.of(context).shareDiscarded,
      onCommit: () {
        if (_share.pending.value == text) _share.take();
        if (_failedShareText == text) _failedShareText = null;
        _shareFailure = null;
        _shareFailures = 0;
      },
      onUndo: () {
        if (mounted && _share.pending.value == text) _showShareFailed(text);
      },
    );
  }

  /// The active connection can open a session right now: transport,
  /// repository are ready and nothing is mid-flight. Mirrors
  /// the readiness the share route waits for.
  bool get _launchConnectionReady =>
      _controller.hasConnectedServer &&
      !_controller.connectionLoading &&
      !_controller.locationLoading;

  bool get _launchProfileNeedsReentry {
    final profile = _controller.profile;
    return profile != null &&
        (profile.requiresPasswordReentry || profile.requiresCodexTokenReentry);
  }

  /// A saved server is on its way: either a connect is in flight, or nothing
  /// has failed yet and the root screen is about to start one (cold start).
  /// A missing profile, a credential re-entry, or a recorded failure is
  /// final and never counts as waiting.
  bool get _launchNewTaskWaiting {
    if (_controller.profile == null || _launchProfileNeedsReentry) return false;
    if (_launchConnectionReady) return false;
    if (_controller.connectionLoading || _controller.locationLoading) {
      return true;
    }
    return _controller.lastError == null;
  }

  /// A pinned-session shortcut waits under the same rule as New task, but
  /// only for its own server: a launch stamped with another profile is
  /// final and is dropped with a notice instead of waiting for a server that
  /// is never going to be the active one.
  bool _sessionLaunchWaiting(SessionLaunch launch) =>
      _controller.profile?.id == launch.profileID && _launchNewTaskWaiting;

  /// A home-screen shortcut arrives as an action or as session IDs, never
  /// as text. Connect opens the servers screen over whatever is showing,
  /// leaving the current connection alone. New task waits for the saved
  /// server to become ready and then opens an empty session. A pinned
  /// session waits the same way and then opens exactly that chat. The Quick
  /// Settings tile opens Activity. Nothing is ever sent on the user's
  /// behalf, and a launch that cannot complete is consumed with a notice
  /// rather than left pending indefinitely.
  void _scheduleLaunchRoute() {
    if (_launchRouteScheduled) return;
    final action = _launchShortcut.pending.value;
    final session = _launchShortcut.pendingSession.value;
    if (action == null && session == null) return;
    final waiting = action == null
        ? _sessionLaunchWaiting(session!)
        : action == LaunchAction.newTask && _launchNewTaskWaiting;
    if (waiting) {
      if (!_launchWaitingNoticeShown) {
        _launchWaitingNoticeShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (!mounted || context == null || !_launchWaitingNoticeShown) {
            return;
          }
          final l10n = AppLocalizations.of(context);
          _showWaiting(
            _waitingNotice,
            action == null
                ? l10n.launchUiSessionWaiting
                : l10n.launchShortcutWaiting,
          );
        });
      }
      return;
    }
    _launchRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final navigator = _navigatorKey.currentState;
        if (navigator == null) return;
        final current = _launchShortcut.pending.value;
        if (current == null) {
          final launch = _launchShortcut.pendingSession.value;
          if (launch != null) _openSessionForLaunch(navigator, launch);
          return;
        }
        switch (current) {
          case LaunchAction.connect:
            _consumeLaunchAction(current);
            _showServersForLaunch(navigator);
          case LaunchAction.newTask:
            await _openNewTaskForLaunch(navigator, current);
          case LaunchAction.activity:
            _openActivityForLaunch(navigator, current);
          case LaunchAction.phoneSetup:
          case LaunchAction.phoneSetupDone:
            // Never waits on the connection: setup has its own screens, and
            // the job's state (read from setup.json) decides where to land.
            _consumeLaunchAction(current);
            await openPhoneSetupFromNotification(
              navigator,
              topRouteName: _routeTracker.topName,
            );
        }
      } finally {
        _launchRouteScheduled = false;
        // A retained action re-evaluates against the current state; a
        // consumed one returns immediately.
        if (mounted) _scheduleLaunchRoute();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openNewTaskForLaunch(
    NavigatorState navigator,
    LaunchAction action,
  ) async {
    final l10n = AppLocalizations.of(navigator.context);
    if (_controller.profile == null) {
      _consumeLaunchAction(action);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.launchShortcutNoServer);
      return;
    }
    if (_launchProfileNeedsReentry) {
      _consumeLaunchAction(action);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.launchShortcutReentry);
      return;
    }
    if (!_launchConnectionReady) {
      // The state moved between scheduling and this frame; the listener
      // re-evaluates the retained action when the connection settles.
      if (_launchNewTaskWaiting) return;
      _consumeLaunchAction(action);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.launchShortcutConnectionFailed);
      return;
    }
    final location = _controller.locationRevision;
    final api = _controller.api;
    final repository = _controller.repository;
    try {
      final session = await _controller.createSession();
      if (!mounted) return;
      if (location != _controller.locationRevision ||
          !identical(api, _controller.api) ||
          !identical(repository, _controller.repository)) {
        throw ProductException(l10n.e7LocaleUiConnectionChanged);
      }
      _consumeLaunchAction(action);
      unawaited(
        navigator.pushNamed(
          '/chat/${session.id}',
          arguments: const ChatRouteArguments.newlyCreated(),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _consumeLaunchAction(action);
      _say(
        l10n.appNewConversationFailed,
        supporting: productErrorText(error, l10n: l10n),
        failed: true,
      );
    }
  }

  /// Opens the exact pinned session a launcher shortcut named, by IDs only.
  /// The chat is pushed without a draft and without any send; a launch for
  /// another server is dropped with a notice rather than switching servers
  /// silently, mirroring widget-row taps.
  void _openSessionForLaunch(NavigatorState navigator, SessionLaunch launch) {
    final l10n = AppLocalizations.of(navigator.context);
    final profile = _controller.profile;
    if (profile == null) {
      _consumeSessionLaunch(launch);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.launchUiSessionNoServer);
      return;
    }
    if (profile.id != launch.profileID) {
      _consumeSessionLaunch(launch);
      _showLaunchNotice(l10n.launchUiSessionOtherServer);
      return;
    }
    if (_launchProfileNeedsReentry) {
      _consumeSessionLaunch(launch);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.launchUiSessionReentry);
      return;
    }
    if (!_launchConnectionReady) {
      // The state moved between scheduling and this frame; the listener
      // re-evaluates the retained launch when the connection settles.
      if (_sessionLaunchWaiting(launch)) return;
      _consumeSessionLaunch(launch);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.launchUiSessionConnectionFailed);
      return;
    }
    _consumeSessionLaunch(launch);
    final route = '/chat/${launch.sessionID}';
    // A warm tap on the chat that is already showing stays where it is.
    if (_routeTracker.topName == route) return;
    unawaited(navigator.pushNamed(route));
  }

  /// The Quick Settings tile opens Activity — the single needs-attention
  /// destination — over whatever is showing. Activity reflects the
  /// connection as it settles, so the tap never waits; without a saved
  /// server there is nothing to show and the servers screen opens instead.
  void _openActivityForLaunch(NavigatorState navigator, LaunchAction action) {
    _consumeLaunchAction(action);
    if (_controller.profile == null) {
      _showServersForLaunch(navigator);
      _showLaunchNotice(
        AppLocalizations.of(navigator.context).launchUiActivityNoServer,
      );
      return;
    }
    if (_routeTracker.topName == _activityLaunchRoute) return;
    unawaited(
      navigator.push(
        KitPageRoute<void>(
          settings: const RouteSettings(name: _activityLaunchRoute),
          builder: (_) => ActivityScreen(controller: _controller),
        ),
      ),
    );
  }

  static const _activityLaunchRoute = '/activity/launch';

  /// Consumes [action] only if it is still the pending one, so an action that
  /// arrived while this one was being handled is not swallowed with it.
  void _consumeLaunchAction(LaunchAction action) {
    _launchWaitingNoticeShown = false;
    _clearNotice(_waitingNotice);
    if (_launchShortcut.pending.value == action) _launchShortcut.take();
  }

  /// Same single-consumption rule for a pinned-session launch.
  void _consumeSessionLaunch(SessionLaunch launch) {
    _launchWaitingNoticeShown = false;
    _clearNotice(_waitingNotice);
    if (_launchShortcut.pendingSession.value == launch) {
      _launchShortcut.takeSession();
    }
  }

  /// Pushes the servers screen unless one is already on top. Routes beneath
  /// stay: an open chat keeps its draft, and the connection is untouched.
  void _showServersForLaunch(NavigatorState navigator) {
    final top = _routeTracker.topName;
    final rootShowsServers =
        top == '/' &&
        (_controller.profile == null || _launchProfileNeedsReentry);
    if (top == '/servers' || rootShowsServers) return;
    unawaited(navigator.pushNamed('/servers'));
  }

  void _showLaunchNotice(String message) => _say(message);

  ServerProfile? _savedProfile(String id) {
    for (final profile in _controller.store.profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// A session handoff link (F4-S2) names a saved server and a session and
  /// nothing else. Known server: open that exact session with explicit
  /// navigation, switching the connection first when the link names a
  /// saved server other than the active one. Unknown server: an honest
  /// banner with a way to the servers screen. Nothing is ever sent, created
  /// or resumed on the user's behalf, and a link that cannot complete is
  /// consumed with a notice rather than retried forever.
  void _scheduleSessionLinkRoute() {
    if (_linkRouteScheduled) return;
    final link = _sessionLink.pending.value;
    if (link == null) return;
    final target = _savedProfile(link.profileID);
    final targetIsActive =
        target != null && target.id == _controller.profile?.id;
    if (targetIsActive && _launchNewTaskWaiting) {
      if (!_linkWaitingNoticeShown) {
        _linkWaitingNoticeShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (!mounted || context == null || !_linkWaitingNoticeShown) return;
          _showWaiting(
            _waitingNotice,
            AppLocalizations.of(context).handoffUiLinkWaiting,
          );
        });
      }
      return;
    }
    _linkRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final navigator = _navigatorKey.currentState;
        if (navigator == null) return;
        final current = _sessionLink.pending.value;
        if (current == null) return;
        await _openSessionForLink(navigator, current);
      } finally {
        _linkRouteScheduled = false;
        if (mounted) _scheduleSessionLinkRoute();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openSessionForLink(
    NavigatorState navigator,
    SessionLink link,
  ) async {
    final l10n = AppLocalizations.of(navigator.context);
    final target = _savedProfile(link.profileID);
    if (target == null) {
      _consumeSessionLink(link);
      _showSessionLinkServerMissing(navigator, l10n);
      return;
    }
    if (target.requiresPasswordReentry || target.requiresCodexTokenReentry) {
      _consumeSessionLink(link);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.handoffUiLinkReentry);
      return;
    }
    if (target.id != _controller.profile?.id) {
      // Another saved server: switch the connection first. The servers
      // screen does the same on a tap, then lands on home.
      Object? failure;
      try {
        await _controller.connect(target);
      } catch (error) {
        failure = error;
      }
      if (!mounted) return;
      if (failure != null || _controller.api == null) {
        _consumeSessionLink(link);
        _showServersForLaunch(navigator);
        _showLaunchNotice(l10n.handoffUiLinkConnectionFailed);
        return;
      }
      _consumeSessionLink(link);
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
      unawaited(navigator.pushNamed('/chat/${link.sessionID}'));
      return;
    }
    if (!_launchConnectionReady) {
      // The state moved between scheduling and this frame; the listener
      // re-evaluates the retained link when the connection settles.
      if (_launchNewTaskWaiting) return;
      _consumeSessionLink(link);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.handoffUiLinkConnectionFailed);
      return;
    }
    _consumeSessionLink(link);
    unawaited(navigator.pushNamed('/chat/${link.sessionID}'));
  }

  /// A conversation link that carries the server's address (P3.9). Taken
  /// once into the one address coordinator, which stays network-silent; the
  /// sheet then asks before every step and says plainly when this link type
  /// is not available yet. Only a found, existing conversation navigates,
  /// through the same path as a local link. A link arriving while the sheet
  /// is up replaces the one it shows.
  void _scheduleAddressLinkRoute() {
    if (_addressLinkRouteScheduled) return;
    if (_sessionLink.pendingAddress.value == null &&
        _sessionLink.pendingAddressFailure.value == null) {
      return;
    }
    _addressLinkRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addressLinkRouteScheduled = false;
      final navigator = _navigatorKey.currentState;
      if (!mounted || navigator == null) return;
      unawaited(_openAddressLink(navigator));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openAddressLink(NavigatorState navigator) async {
    final addresses = ref.read(sessionAddressProvider);
    var failure = _sessionLink.takeAddressFailure();
    final link = _sessionLink.takeAddress();
    if (link != null) {
      failure = null;
      try {
        addresses.receive(link.encode());
      } on SessionAddressFailure catch (error) {
        addresses.cancel();
        failure = error.code;
      }
    }
    if (_addressSheetOpen) return;
    _addressSheetOpen = true;
    try {
      final opened = await showSessionAddressSheet(
        navigator.context,
        controller: addresses,
        failure: failure,
        onAddServer: (origin) async {
          await navigator.pushNamed(
            '/servers',
            arguments: ServersRouteRequest.add(initialUrl: origin),
          );
        },
        onSignIn: (profileId) async {
          await navigator.pushNamed(
            '/servers',
            arguments: ServersRouteRequest.connect(profileId),
          );
        },
      );
      if (opened == null || !mounted) return;
      final route = SessionLink.tryCreate(
        profileID: opened.profileId,
        sessionID: opened.sessionId,
      );
      if (route != null) await _openSessionForLink(navigator, route);
    } finally {
      _addressSheetOpen = false;
    }
  }

  /// An AI Team link (TEAM-203) names a saved server and a gate or run and
  /// nothing else: the notification tap and the `opencode-mobile://team`
  /// link both land here. Known, active server: Activity opens with the
  /// exact Gate sheet (or the task's conversation). Another saved server: switch
  /// first, as the session link does. Unknown server: the same honest
  /// banner. Opening never answers anything.
  void _scheduleTeamLinkRoute() {
    if (_teamLinkRouteScheduled) return;
    final link = _sessionLink.pendingTeam.value;
    if (link == null) return;
    final target = _savedProfile(link.profileId);
    final targetIsActive =
        target != null && target.id == _controller.profile?.id;
    if (targetIsActive && _launchNewTaskWaiting) return;
    _teamLinkRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final navigator = _navigatorKey.currentState;
        if (navigator == null) return;
        final current = _sessionLink.pendingTeam.value;
        if (current == null) return;
        await _openTeamLink(navigator, current);
      } finally {
        _teamLinkRouteScheduled = false;
        if (mounted) _scheduleTeamLinkRoute();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openTeamLink(NavigatorState navigator, TeamLink link) async {
    final l10n = AppLocalizations.of(navigator.context);
    final target = _savedProfile(link.profileId);
    if (target == null) {
      _consumeTeamLink(link);
      _showSessionLinkServerMissing(navigator, l10n);
      return;
    }
    if (target.requiresPasswordReentry || target.requiresCodexTokenReentry) {
      _consumeTeamLink(link);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.handoffUiLinkReentry);
      return;
    }
    if (target.id != _controller.profile?.id) {
      Object? failure;
      try {
        await _controller.connect(target);
      } catch (error) {
        failure = error;
      }
      if (!mounted) return;
      if (failure != null || _controller.api == null) {
        _consumeTeamLink(link);
        _showServersForLaunch(navigator);
        _showLaunchNotice(l10n.handoffUiLinkConnectionFailed);
        return;
      }
      _consumeTeamLink(link);
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
      _pushTeamDestination(navigator, link);
      return;
    }
    if (!_launchConnectionReady) {
      if (_launchNewTaskWaiting) return;
      _consumeTeamLink(link);
      _showServersForLaunch(navigator);
      _showLaunchNotice(l10n.handoffUiLinkConnectionFailed);
      return;
    }
    _consumeTeamLink(link);
    _pushTeamDestination(navigator, link);
  }

  /// Activity with the gate's sheet opening on top (it waits for the
  /// plugin's first snapshot), or the task's conversation for a run. A
  /// profile without the plugin gets the plain Activity list.
  void _pushTeamDestination(NavigatorState navigator, TeamLink link) {
    final team = _controller.orchestration;
    switch (link.kind) {
      case TeamLinkKind.gate:
        navigator.push(
          KitPageRoute<void>(
            builder: (_) => ActivityScreen(
              controller: _controller,
              initialTeamGateId: team == null ? null : link.id,
            ),
          ),
        );
      case TeamLinkKind.run:
        if (team == null) {
          navigator.push(
            KitPageRoute<void>(
              builder: (_) => ActivityScreen(controller: _controller),
            ),
          );
          return;
        }
        // The task's one page: its conversation, as every other door to a
        // task opens (docs/design/team-conversation-2026-09-26.md).
        navigator.push(TeamConversation.route(team, runId: link.id));
    }
  }

  void _consumeTeamLink(TeamLink link) {
    if (_sessionLink.pendingTeam.value == link) _sessionLink.takeTeam();
  }

  /// Consumes [link] only if it is still the pending one, so a link that
  /// arrived while this one was being handled is not swallowed with it.
  void _consumeSessionLink(SessionLink link) {
    _linkWaitingNoticeShown = false;
    _clearNotice(_waitingNotice);
    if (_sessionLink.pending.value == link) _sessionLink.take();
  }

  /// A link for a server this phone has not saved: the link names only the
  /// sending phone's profile id (never the server's address, see
  /// [SessionLink.profileID]), so the sheet cannot fill anything in. It
  /// offers Add server itself, not the list to find it on (P3.9).
  void _showSessionLinkServerMissing(
    NavigatorState navigator,
    AppLocalizations l10n,
  ) {
    unawaited(() async {
      final add = await showKitConfirm(
        navigator.context,
        title: l10n.handoffUiLinkAddTitle,
        body: l10n.handoffUiLinkServerMissing,
        confirmLabel: l10n.handoffUiLinkAddServer,
        cancelLabel: l10n.handoffUiLinkDismiss,
        icon: AppIconography.add,
        sheetKey: const Key('session-link-server-missing'),
        confirmKey: const Key('session-link-add-server'),
      );
      if (!add || !mounted) return;
      unawaited(
        _navigatorKey.currentState?.pushNamed(
          '/servers',
          arguments: const ServersRouteRequest.add(),
        ),
      );
    }());
  }

  void _scheduleCodingAlertRoute() {
    if (_codingAlertRouteScheduled ||
        _controller.pendingCodingAlertOpen == null ||
        (_controller.pendingCodingAlertOpen?.monitorToken.isEmpty != false &&
            !_controller.hasConnectedServer)) {
      return;
    }
    _codingAlertRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codingAlertRouteScheduled = false;
      if (!mounted) return;
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _scheduleCodingAlertRoute();
        return;
      }
      final target = _controller.takePendingCodingAlertOpen();
      if (target == null) return;
      if (target.kind.isTeam) {
        // AI Team alerts (TEAM-203) carry a gate or run id and the saved
        // server's id, nothing else; they route like the team deep link.
        final link = TeamLink.tryCreate(
          kind: target.kind == CodingAlertKind.teamCompleted
              ? TeamLinkKind.run
              : TeamLinkKind.gate,
          profileId: target.profileID.isEmpty
              ? _controller.profile?.id
              : target.profileID,
          id: target.sessionID,
        );
        if (link != null) unawaited(_openTeamLink(navigator, link));
        return;
      }
      if (target.kind == CodingAlertKind.quota) {
        unawaited(
          _controller.quotaMonitor
              .resolveRoute(target.profileID, target.monitorToken)
              .then((route) {
                if (!mounted) {
                  return;
                }
                if (route == null) {
                  _say(
                    lookupAppLocalizations(
                      Localizations.localeOf(navigator.context),
                    ).quotaMonitorSourceChanged,
                  );
                  return;
                }
                navigator.push(
                  KitPageRoute<void>(
                    // Quota monitoring is part of Usage → Remaining.
                    builder: (_) => UsageHubScreen(
                      controller: _controller,
                      initialSection: UsageSection.remaining,
                    ),
                  ),
                );
              }),
        );
        return;
      }
      if (target.monitorToken.isNotEmpty) {
        final route = _controller.profileMonitor.routeForToken(
          target.profileID,
          target.monitorToken,
        );
        if (route != null && route.sessionID == target.sessionID) {
          unawaited(
            openMonitoredRequest(navigator.context, _controller, route),
          );
        } else {
          _say(
            lookupAppLocalizations(
              Localizations.localeOf(navigator.context),
            ).monitorOpenFailed,
          );
        }
        return;
      }
      if (target.kind == CodingAlertKind.question) {
        navigator.push(
          KitPageRoute<void>(
            builder: (_) => ActivityScreen(
              controller: _controller,
              initialQuestionSessionID: target.sessionID,
            ),
          ),
        );
        return;
      }
      navigator.push(
        KitPageRoute<void>(
          builder: (_) => ChatScreen(sessionID: target.sessionID),
        ),
      );
    });
  }

  // ------------------------------------------------------------------
  // Desktop shortcut layer (no-op on Android: AppShortcuts passes through).
  // ------------------------------------------------------------------

  Future<void> _startNewSession() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    try {
      final session = await _controller.createSession();
      await navigator.pushNamed(
        '/chat/${session.id}',
        arguments: const ChatRouteArguments.newlyCreated(),
      );
    } catch (error) {
      if (!mounted) return;
      _say(
        AppLocalizations.of(navigator.context).appNewConversationFailed,
        supporting: productErrorText(error),
        failed: true,
      );
    }
  }

  void _openSettings() {
    _navigatorKey.currentState?.push(
      KitPageRoute<void>(
        builder: (_) => SettingsScreen(controller: _controller),
      ),
    );
  }

  List<DesktopCommand> _shellCommands(BuildContext context) {
    final mod = shortcutModifierLabel;
    final l10n = AppLocalizations.of(context);
    void go(int index) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      dispatchAtShellRoot(
        navigator,
        _shortcutSignals,
        SelectDestinationIntent(index),
      );
    }

    final scope = SearchScope(
      controller: _controller,
      hasShell: true,
      thermalGuard: ref.read(thermalGuardSlotProvider).value != null,
    );
    return [
      DesktopCommand(
        label: l10n.e7LocaleUiNewSession,
        icon: Icons.add_rounded,
        hint: l10n.e7LocaleUiNewSessionHint,
        keys: '$mod + N',
        onInvoke: () => unawaited(_startNewSession()),
      ),
      DesktopCommand(
        label: l10n.e7LocaleUiWorkspace,
        icon: Icons.workspaces_outline,
        hint: l10n.e7LocaleUiWorkspaceHint,
        keys: '$mod + 1',
        onInvoke: () => go(0),
      ),
      // Same order as the dock: the number in the hint is the tab's position.
      DesktopCommand(
        label: l10n.e7LocaleUiActivity,
        icon: Icons.notifications_outlined,
        hint: l10n.e7LocaleUiActivityHint,
        keys: '$mod + 2',
        onInvoke: () => go(1),
      ),
      DesktopCommand(
        label: l10n.e7LocaleUiFiles,
        icon: Icons.folder_outlined,
        hint: l10n.e7LocaleUiFilesHint,
        keys: '$mod + 3',
        onInvoke: () => go(2),
      ),
      // One Settings command: the fourth tab is the hub. "$mod + ," still
      // opens the same hub over the current screen without leaving it.
      DesktopCommand(
        label: l10n.e7LocaleUiSettings,
        icon: Icons.settings_outlined,
        hint: l10n.e7LocaleUiMoreHint,
        keys: '$mod + 4',
        onInvoke: () => go(3),
      ),
      DesktopCommand(
        label: l10n.e7LocaleUiKeyboardShortcuts,
        icon: Icons.keyboard_outlined,
        keys: '$mod + /',
        onInvoke: () => unawaited(showShortcutsHelp(context)),
      ),
      DesktopCommand(
        label: l10n.e7LocaleUiRefreshSessions,
        icon: Icons.refresh_rounded,
        onInvoke: () => unawaited(_controller.refreshSessions()),
      ),
      DesktopCommand(
        label: l10n.e7LocaleUiDiagnostics,
        icon: Icons.bug_report_outlined,
        hint: l10n.e7LocaleUiDiagnosticsHint,
        onInvoke: () => _navigatorKey.currentState?.pushNamed('/debug'),
      ),
      // The rest of the launcher is the app-wide search index, so a setting
      // or a Project tool is found here exactly as it is in Settings. The
      // four tabs are the numbered commands above.
      for (final entry in searchIndex(l10n, scope))
        if (!entry.id.startsWith('tab-') &&
            entry.id != 'library-keyboard-shortcuts' &&
            entry.id != 'app-diagnostics-entry')
          DesktopCommand(
            label: entry.title,
            icon: entry.icon,
            hint: entry.parent == null
                ? null
                : l10n.discoverSearchIn(entry.parent!),
            keywords: entry.keywords,
            onInvoke: () {
              // A context under the navigator: the launcher's own is gone by
              // the time a command runs.
              final target = _navigatorKey.currentState?.overlay?.context;
              if (target != null) unawaited(entry.open(target, scope));
            },
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppAppearance>(
      valueListenable: _controller.appearance,
      builder: (context, appearance, _) => ListenableBuilder(
        listenable: Listenable.merge([
          _controller.themePack,
          _controller.appLocale,
          harvestedDynamicPack,
        ]),
        builder: (context, _) {
          final pack = effectiveThemePack(_controller.themePack.value);
          return MaterialApp(
            navigatorKey: _navigatorKey,
            navigatorObservers: [_routeTracker, _routeTiming],
            builder: (context, child) {
              // Global text-scale safety net: only the extreme top end is
              // capped (KitText.appScaler).
              return Theme(
                data: AppTheme.forLocale(
                  Theme.of(context),
                  Localizations.localeOf(context),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: KitText.appScaler(
                      MediaQuery.textScalerOf(context),
                      max: AppTheme.maxTextScale,
                    ),
                  ),
                  // The app's own line joins the conditions every screen's
                  // status slot reads; the update notices below add theirs.
                  child: AppConnectionStatusScope(
                    controller: _controller,
                    navigatorKey: _navigatorKey,
                    child: ValueListenableBuilder<KitStatus?>(
                      valueListenable: _notice,
                      builder: (context, notice, notices) =>
                          UpdateStatusScope(status: notice, child: notices!),
                      child: ShorebirdUpdateNotice(
                        service: _updateService,
                        currentProfileId: () => _controller.profile?.id,
                        allowsAutomaticUpdate: (id) =>
                            AutomationPolicyController.forProfile(
                              _controller.store.prefs,
                              id,
                            ).value.allows(AutomationBehavior.applyCodePush),
                        onDownloaded:
                            ({
                              required profileId,
                              required eventId,
                              required at,
                            }) async {
                              await _controller.recordServerAct(
                                profileId: profileId,
                                kind: AutomaticActKind.update,
                                eventId: eventId,
                                at: at,
                              );
                            },
                        child: DesktopReleaseNotice(
                          navigatorKey: _navigatorKey,
                          // Desktop only. On Android this returns its child
                          // untouched, so the touch product gains no key handling.
                          child: AppShortcuts(
                            navigatorKey: _navigatorKey,
                            signals: _shortcutSignals,
                            handlers: AppShortcutHandlers(
                              onNewSession: () => unawaited(_startNewSession()),
                              onOpenSettings: _openSettings,
                              paletteCommands: _shellCommands,
                            ),
                            // Settings › Appearance › Effects, above the
                            // navigator so every route and its transitions read
                            // the same choices. Calls without a context (a send
                            // from a controller) obey Vibration via the flag.
                            child: ValueListenableBuilder<KitEffects>(
                              valueListenable: _controller.effects,
                              builder: (context, effects, navigator) {
                                KitHaptics.enabled = effects.haptics;
                                return KitEffectsScope(
                                  effects: effects,
                                  child: navigator!,
                                );
                              },
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            scrollBehavior: const KitScrollBehavior(),
            title: 'OpenCode Mobile',
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: _controller.appLocale.value,
            debugShowCheckedModeBanner: false,
            themeMode: switch (appearance) {
              AppAppearance.system => ThemeMode.system,
              AppAppearance.light => ThemeMode.light,
              AppAppearance.dark => ThemeMode.dark,
            },
            theme: AppTheme.light(pack),
            darkTheme: AppTheme.dark(pack),
            initialRoute: '/',
            routes: {
              '/': (_) => _Root(say: _say),
              '/servers': (_) => const ServersScreen(),
              '/home': (_) => const HomeScreen(),
              '/guide': (_) => GuideScreen(embedded: false),
              '/about': (_) => const AboutScreen(),
              // This phone (in the app or in Termux) exists only on
              // Android: a desktop deep link, or any leftover push, must not
              // land on a page with no phone behind it.
              if (platformCapabilities.supportsTermux)
                thisPhoneRoute: (context) => ThisPhoneScreen(
                  kind:
                      ModalRoute.of(context)?.settings.arguments
                          as PhoneHostKind?,
                ),
              '/debug': (_) => AppDiagnosticsScreen(controller: _controller),
            },
            onGenerateRoute: (settings) {
              if (settings.name?.startsWith('/chat/') == true) {
                final id = settings.name!.substring('/chat/'.length);
                final arguments = settings.arguments;
                final chat = arguments is ChatRouteArguments
                    ? arguments
                    : const ChatRouteArguments();
                // Built once for the page (P4.2a landing scope).
                final page = chatLandingPage(
                  sessionID: id,
                  discardIfUntouched: chat.discardIfUntouched,
                  focusComposer: chat.focusComposer,
                  landOnRequestID: chat.landOnRequestID,
                  landOnFailure: chat.landOnFailure,
                  menuAction: chat.menuAction,
                );
                return KitPageRoute<void>(builder: (_) => page);
              }
              return null;
            },
          );
        },
      ),
    );
  }

  Future<void> _harvestDynamicColors() async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (palette == null) return;
      harvestedDynamicPack.value = dynamicThemePack(
        lightScheme: palette.toColorScheme(brightness: Brightness.light),
        darkScheme: palette.toColorScheme(brightness: Brightness.dark),
      );
    } catch (_) {
      // Below Android 12, on desktop, or in tests: Material You stays
      // unavailable and the OpenCode pack remains the fallback.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_controllerChanged);
    _share.pending.removeListener(_scheduleShareRoute);
    if (widget.shareIntent == null) _share.dispose();
    _launchShortcut.pending.removeListener(_scheduleLaunchRoute);
    _launchShortcut.pendingSession.removeListener(_scheduleLaunchRoute);
    if (widget.launchShortcut == null) _launchShortcut.dispose();
    _sessionLink.pending.removeListener(_scheduleSessionLinkRoute);
    _sessionLink.pendingTeam.removeListener(_scheduleTeamLinkRoute);
    _sessionLink.pendingAddress.removeListener(_scheduleAddressLinkRoute);
    _sessionLink.pendingAddressFailure.removeListener(
      _scheduleAddressLinkRoute,
    );
    if (widget.sessionLinkIntent == null) _sessionLink.dispose();
    _noticeTimer?.cancel();
    _notice.dispose();
    super.dispose();
  }
}

/// Remembers which route sits on top of the shell navigator. Only the name
/// matters: unnamed routes (dialogs, sheets, pushed pages) report null.
class _TopRouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  String? get topName => _stack.isEmpty ? null : _stack.last.settings.name;

  /// A context inside the top page (below the navigator's overlay), for
  /// the app-level parts that need one: the Undo bar, Copy.
  BuildContext? get topContext {
    for (final route in _stack.reversed) {
      if (route is ModalRoute && route.subtreeContext != null) {
        return route.subtreeContext;
      }
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _stack.removeAt(index);
      } else {
        _stack[index] = newRoute;
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
  }
}

/// Decides the start destination from persisted state.
class _Root extends ConsumerStatefulWidget {
  const _Root({required this.say});

  /// The app's one-shot line (the shell's status notice).
  final void Function(String message, {String? supporting, bool failed}) say;

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  bool _started = false;
  int _attempts = 0;
  late final ConnectionController _controller;
  late final BuiltinServerStarter _builtin;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(connProvider)..addListener(_changed);
    _builtin = ref.read(builtinServerStarterProvider)..addListener(_changed);
    _attachPhoneSetup();
    _recoverFromLastExit();
    // The status scope is above this route. Publish the guard after mounting
    // so its slot notification cannot rebuild an ancestor during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startThermalGuard();
    });
  }

  void _startThermalGuard() {
    // Pause the AI Team on this phone while Android says it is hot.
    startThermalGuard(
      ref.read(thermalGuardSlotProvider),
      store: _controller.store,
      linux: ref.read(builtinLinuxProvider),
      diagnostics: _controller.diagnostics,
      // Every confirmed pause, stop and resume is filed in that server's
      // While you were away (P6.2); the guard still decides alone.
      onAct: (kind, team, since, at) => unawaited(
        _controller.recordServerAct(
          profileId: team.id,
          kind: switch (kind) {
            ThermalNoticeKind.paused => AutomaticActKind.heatPause,
            ThermalNoticeKind.stopped => AutomaticActKind.heatStop,
            ThermalNoticeKind.resumed => AutomaticActKind.heatResume,
          },
          eventId: 'thermal.${kind.name}:${since.microsecondsSinceEpoch}',
          at: at,
        ),
      ),
    );
  }

  /// Once per process: why Android last ended the app, and bring back the
  /// phone's OpenCode (and the AI Team) it stopped with it.
  void _recoverFromLastExit() {
    unawaited(
      ref
          .read(appExitRecoveryProvider)
          .runOnce(
            store: _controller.store,
            active: _controller.profile,
            starter: _builtin,
            diagnostics: _controller.diagnostics,
            recover: ref.read(phoneServerHealingProvider).check,
          ),
    );
  }

  /// The phone setup engine ends every job by starting OpenCode and
  /// connecting; only the app shell has the profiles and the connection.
  void _attachPhoneSetup() {
    AppLocalizations strings() {
      final locale =
          _controller.appLocale.value ?? PlatformDispatcher.instance.locale;
      final supported = AppLocalizations.supportedLocales.any(
        (candidate) => candidate.languageCode == locale.languageCode,
      );
      return lookupAppLocalizations(
        supported ? Locale(locale.languageCode) : const Locale('en'),
      );
    }

    PhoneSetup.attach(
      strings: strings,
      // Built when the step runs, so the shell reads the profile store only
      // when a setup job actually needs it.
      finisher: (request) => BuiltinSetupFinisher(
        store: ref.read(bootstrapProvider).store,
        starter: _builtin,
        strings: strings,
        isConnectedTo: (profile) =>
            _controller.profile?.id == profile.id &&
            _controller.hasConnectedServer,
        connect: (profile) async {
          await _controller.connect(profile);
          if (_controller.hasConnectedServer) return null;
          final l10n = strings();
          return l10n.builtinServerConnectFailed(
            _controller.lastError ?? l10n.builtinServerStopped,
          );
        },
      ).call(request),
      // The Termux host ends the same way, through Termux's own manager.
      termuxFinisher: (request) => TermuxSetupFinisher(
        store: ref.read(bootstrapProvider).store,
        strings: strings,
        isConnectedTo: (profile) =>
            _controller.profile?.id == profile.id &&
            _controller.hasConnectedServer,
        connect: (profile) async {
          await _controller.connect(profile);
          if (_controller.hasConnectedServer) return null;
          final l10n = strings();
          return l10n.builtinServerConnectFailed(
            _controller.lastError ?? l10n.e7SetupAuthFailed,
          );
        },
      ).call(request),
    );
  }

  void _changed() {
    if (!mounted) return;
    // A successful connect resets the streak, so the next failure after a
    // long healthy session starts its count from one again.
    if (_controller.hasConnectedServer) _attempts = 0;
    setState(() {});
  }

  bool _startingPhoneServer = false;

  Future<void> _startPhoneServer() async {
    if (_startingPhoneServer) return;
    setState(() => _startingPhoneServer = true);
    final strings = lookupAppLocalizations(Localizations.localeOf(context));
    try {
      await LocalServerControls(
        store: _controller.store,
        connection: _controller,
      ).restart();
    } on LocalServerControlFailure catch (failure) {
      // What failed in words; Termux's own text stays in diagnostics.
      widget.say(
        strings.rootPhoneServerStartFailed,
        supporting: productErrorText(failure, l10n: strings),
        failed: true,
      );
    } finally {
      if (mounted) setState(() => _startingPhoneServer = false);
    }
    if (!mounted) return;
    _started = false;
    _connectSaved();
  }

  void _connectSaved() {
    if (_started) return;
    final conn = _controller;
    // A connection may already be in flight (for example a launch intent).
    // Mounting the root must not replace its gateway while health is pending.
    if (conn.api != null) return;
    final profile = conn.profile;
    if (profile == null ||
        profile.requiresPasswordReentry ||
        profile.requiresCodexTokenReentry) {
      return;
    }
    _started = true;
    _attempts += 1;
    if (looksLikeInAppServer(profile)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_autoStartThenConnect(profile)),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => conn.connect(profile));
  }

  /// Launch joins the same foreground recovery owner as resume and polling.
  Future<void> _autoStartThenConnect(ServerProfile profile) async {
    final healing = ref.read(phoneServerHealingProvider);
    await healing.check(profile);
    if (mounted) await healing.connectIfNeeded(profile);
  }

  Future<void> _startInAppServer() async {
    final profile = _controller.profile;
    if (profile == null || _builtin.starting) return;
    final failure = await _builtin.start(profile);
    if (!mounted || failure != null || _controller.profile?.id != profile.id) {
      return;
    }
    // This explicit action also authorizes connecting when automatic
    // reconnect is off. The recovery owner may already have connected it.
    _started = true;
    await ref
        .read(phoneServerHealingProvider)
        .connectIfNeeded(profile, automatic: false);
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connProvider);
    if (conn.profile == null) return const ServersScreen();
    if (conn.hasConnectedServer) {
      return const HomeScreen();
    }
    if (conn.profile!.requiresPasswordReentry ||
        conn.profile!.requiresCodexTokenReentry) {
      return const ServersScreen();
    }
    _connectSaved();
    final navigator = Navigator.of(context);
    final profile = conn.profile!;
    final inApp = _builtin.recognises(profile);
    final startFailure = _builtin.failureFor(profile);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    // Cached opening shell (docs/qa/codex-speed-2026-09-28 item 1): the
    // titles this server listed last time, read-only under the honest
    // connection state. Nothing here marks the server connected, fills the
    // live session map or enables a live action.
    final status = conn.connectionStatus;
    final cached = conn.cachedSessionInventory;
    final lastKnown = cached != null && cached.sessions.isNotEmpty
        ? cached
        : null;
    final opening = lastKnown != null;
    final error = startFailure != null
        ? l10n.builtinServerStartFailed(startFailure.reason(l10n))
        : conn.lastError;
    final card = SavedServerConnectionCard(
      size: opening ? KitStateSize.inline : KitStateSize.page,
      profileName: serverDisplayName(profile, l10n, among: conn.store.profiles),
      usesConnectionToken: conn.usesConnectionToken,
      requiresTokenReentry: profile.requiresCodexTokenReentry,
      baseUrl: profile.baseUrl,
      // The raw failure: the card diagnoses it into words and keeps
      // the text itself under Details only.
      error: error,
      attempts: _attempts,
      // The controller's one eight-second clock, shared with every status
      // line; `since` is set once an attempt actually began (P4.4).
      notAnswering:
          status.phase == ConnectionStatusPhase.notAnswering &&
          status.since != null,
      inAppServer: inApp,
      startingInAppServer: inApp && _builtin.starting,
      inAppStartFailed: startFailure != null,
      onOpenInAppSetup: startFailure != null
          ? () => openPhoneSetupStart(context)
          : null,
      supportsTermux:
          !inApp &&
          !conn.usesConnectionToken &&
          platformCapabilities.supportsTermux,
      onChangeServer: () =>
          navigator.pushNamedAndRemoveUntil('/servers', (_) => false),
      onUpdateToken: () => navigator.pushNamedAndRemoveUntil(
        '/servers',
        (_) => false,
        arguments: 'edit-active',
      ),
      onUpdatePassword: () => navigator.pushNamedAndRemoveUntil(
        '/servers',
        (_) => false,
        arguments: 'edit-active',
      ),
      onOpenTermuxSetup:
          !inApp &&
              !conn.usesConnectionToken &&
              platformCapabilities.supportsTermux
          // The phone's own Termux server goes to This phone (Start is
          // there); any other server on this phone goes to phone setup.
          ? () => TermuxBridge.managesServerUrl(profile.baseUrl)
                ? openThisPhone(context, kind: PhoneHostKind.termux)
                : openPhoneSetupStart(context)
          : null,
      // The app's own phone server: when nothing answers, it is stopped
      // (a phone restart, Android closing Termux, the app closed for
      // OpenCode inside the app), and one tap starts it.
      onStartPhoneServer: inApp
          ? _startInAppServer
          : !conn.usesConnectionToken &&
                platformCapabilities.supportsTermux &&
                TermuxBridge.managesServerUrl(profile.baseUrl)
          ? _startPhoneServer
          : null,
      startingPhoneServer: inApp ? _builtin.starting : _startingPhoneServer,
      onRetry: () {
        _builtin.clearFailure();
        _started = false;
        _connectSaved();
      },
    );
    // A KitScreen, so the app's line (a share waiting for this server)
    // shows above the card (map page root-connecting). The card is this
    // server's connection state, with its own Try again and Details, so the
    // slot leaves the shared connection line out here (`bodySays`): the
    // page says it once. Every other app line still shows (P4.4).
    return _Ground(
      child: KitScreen(
        bodySays: const {KitStatusKind.connection},
        width: opening ? KitScreenWidth.list : KitScreenWidth.full,
        body: lastKnown != null
            ? ListView(
                key: const ValueKey('opening-shell'),
                children: [
                  card,
                  LastKnownSessions(
                    preview: lastKnown,
                    refreshing:
                        error == null && !profile.requiresCodexTokenReentry,
                  ),
                ],
              )
            : card,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _builtin.removeListener(_changed);
    super.dispose();
  }
}

/// The page ground under a bar-less root page (the app opening, the saved
/// server connecting): a KitScreen draws its ground and keeps out of the
/// system bars only with a top bar, so this does both. The ground runs
/// under the status and navigation bars; the content (the app's status
/// line first) stays inside the safe area.
class _Ground extends StatelessWidget {
  const _Ground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => KitSurface(
    level: KitSurfaceLevel.ground,
    shape: KitShape.square,
    padding: KitSurfacePadding.none,
    clip: false,
    child: SafeArea(child: child),
  );
}
