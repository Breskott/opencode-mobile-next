import 'ui/screens/profile_monitor_screen.dart';
import 'ui/screens/usage_hub_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background/live_background.dart';
import 'desktop/window_icon.dart';
import 'desktop/window_state.dart';
import 'diagnostics/app_diagnostics.dart';
import 'domain/server_gateway.dart' show ProductException;
import 'l10n/app_localizations.dart';
import 'platform/launch_shortcut.dart';
import 'platform/session_link.dart';
import 'platform/platform_capabilities.dart';
import 'platform/share_intent.dart';
import 'domain/session_handoff.dart';
import 'domain/team_link.dart';
import 'state/connection.dart';
import 'state/profiles.dart';
import 'update/desktop_release_check.dart';
import 'update/shorebird_update_notice.dart';
import 'ui/app_theme.dart';
import 'ui/desktop/desktop_interaction.dart';
import 'ui/desktop/shortcuts.dart';
import 'ui/theme_packs.dart';
import 'ui/navigation/chat_route.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/product_states.dart' show productErrorText;
import 'ui/widgets/saved_server_connection_card.dart';
import 'ui/screens/guide_screen.dart';
import 'ui/screens/about_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/activity_screen.dart';
import 'ui/screens/team/run_screen.dart';
import 'ui/screens/termux_setup_screen.dart';
import 'ui/screens/app_diagnostics_screen.dart';

Future<void> main() async {
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
}

typedef AppBootstrapLoader = Future<AppBootstrap> Function();

/// Renders immediately so a preferences or secure-storage failure can never
/// leave Android showing a blank native window.
class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({super.key, required this.diagnostics, this.loader});

  final AppDiagnosticsController diagnostics;
  final AppBootstrapLoader? loader;

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  AppBootstrap? _bootstrap;
  ConnectionController? _controller;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bootstrap = await (widget.loader ?? AppBootstrap.create)();
      if (!mounted || generation != _generation) return;
      final controller = ConnectionController(
        bootstrap.store,
        diagnostics: widget.diagnostics,
      );
      if (platformCapabilities.supportsPromptPhotos) {
        await controller.promptPhotos.recoverLostData();
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
      setState(() {
        _bootstrap = bootstrap;
        _controller = controller;
        _loading = false;
      });
    } catch (error, stack) {
      widget.diagnostics.record(error, stack, source: 'bootstrap');
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
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
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _loading
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 18),
                            Text(
                              AppLocalizations.of(context).e7LocaleUiStarting,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).e7LocaleUiStartFailed,
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.diagnostics.sanitize(
                                _error?.toString() ??
                                    AppLocalizations.of(
                                      context,
                                    ).e7LocaleUiUnknownStartupError,
                                limit: 300,
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              key: const ValueKey('retry-app-bootstrap'),
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                AppLocalizations.of(context).e7LocaleUiRetry,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
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
  bool _linkWaitingNoticeShown = false;
  // Tracks the route on top of the shell navigator so a shortcut never
  // stacks a second servers screen over one already showing.
  final _routeTracker = _TopRouteTracker();

  @override
  void initState() {
    super.initState();
    unawaited(_harvestDynamicColors());
    _controller = ref.read(connProvider);
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
      _controller.resumeFromLifecycle(),
    ]);
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
          _messengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).shareWaitingForServer,
                ),
              ),
            );
        });
      }
      return;
    }
    _shareRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _shareWaitingNoticeShown = false;
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
            AppLocalizations.of(navigator.context).e7LocaleUiShareScopeChanged,
          );
        }
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ChatScreen(sessionID: session.id, initialText: text),
            ),
          ),
        );
        if (_share.pending.value == text) _share.take();
        _failedShareText = null;
        _messengerKey.currentState?.hideCurrentMaterialBanner();
      } catch (_) {
        if (!mounted) return;
        if (_share.pending.value == text) _failedShareText = text;
        final l10n = AppLocalizations.of(navigator.context);
        _messengerKey.currentState
          ?..hideCurrentMaterialBanner()
          ..showMaterialBanner(
            MaterialBanner(
              content: Text(l10n.shareSessionFailed),
              actions: [
                TextButton(
                  child: Text(l10n.commonRetry),
                  onPressed: () {
                    if (!mounted) return;
                    _failedShareText = null;
                    _messengerKey.currentState?.hideCurrentMaterialBanner();
                    _scheduleShareRoute();
                  },
                ),
              ],
            ),
          );
      } finally {
        _shareRouteScheduled = false;
        if (mounted) _scheduleShareRoute();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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
          if (!mounted || context == null) return;
          final l10n = AppLocalizations.of(context);
          _showLaunchNotice(
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
      _showLaunchNotice(
        l10n.launchShortcutNewTaskFailed(productErrorText(error)),
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
        MaterialPageRoute<void>(
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
    if (_launchShortcut.pending.value == action) _launchShortcut.take();
  }

  /// Same single-consumption rule for a pinned-session launch.
  void _consumeSessionLaunch(SessionLaunch launch) {
    _launchWaitingNoticeShown = false;
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

  void _showLaunchNotice(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
          if (!mounted || context == null) return;
          _showLaunchNotice(AppLocalizations.of(context).handoffUiLinkWaiting);
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

  /// An AI Team link (TEAM-203) names a saved server and a gate or run and
  /// nothing else: the notification tap and the `opencode-mobile://team`
  /// link both land here. Known, active server: Activity opens with the
  /// exact Gate sheet (or the run screen). Another saved server: switch
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
  /// plugin's first snapshot), or the run screen for a completed run. A
  /// profile without the plugin gets the plain Activity list.
  void _pushTeamDestination(NavigatorState navigator, TeamLink link) {
    final team = _controller.orchestration;
    switch (link.kind) {
      case TeamLinkKind.gate:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(
              controller: _controller,
              initialTeamGateId: team == null ? null : link.id,
            ),
          ),
        );
      case TeamLinkKind.run:
        if (team == null) {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ActivityScreen(controller: _controller),
            ),
          );
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => RunScreen(controller: team, runId: link.id),
          ),
        );
    }
  }

  void _consumeTeamLink(TeamLink link) {
    if (_sessionLink.pendingTeam.value == link) _sessionLink.takeTeam();
  }

  /// Consumes [link] only if it is still the pending one, so a link that
  /// arrived while this one was being handled is not swallowed with it.
  void _consumeSessionLink(SessionLink link) {
    _linkWaitingNoticeShown = false;
    if (_sessionLink.pending.value == link) _sessionLink.take();
  }

  void _showSessionLinkServerMissing(
    NavigatorState navigator,
    AppLocalizations l10n,
  ) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          key: const Key('session-link-server-missing'),
          content: Text(l10n.handoffUiLinkServerMissing),
          actions: [
            TextButton(
              onPressed: () {
                _messengerKey.currentState?.hideCurrentMaterialBanner();
              },
              child: Text(l10n.handoffUiLinkDismiss),
            ),
            TextButton(
              onPressed: () {
                _messengerKey.currentState?.hideCurrentMaterialBanner();
                final navigator = _navigatorKey.currentState;
                if (navigator != null) _showServersForLaunch(navigator);
              },
              child: Text(l10n.handoffUiLinkOpenServers),
            ),
          ],
        ),
      );
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
                  _messengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(
                        lookupAppLocalizations(
                          Localizations.localeOf(navigator.context),
                        ).quotaMonitorSourceChanged,
                      ),
                    ),
                  );
                  return;
                }
                navigator.push(
                  MaterialPageRoute<void>(
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
          _messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                lookupAppLocalizations(
                  Localizations.localeOf(navigator.context),
                ).monitorOpenFailed,
              ),
            ),
          );
        }
        return;
      }
      if (target.kind == CodingAlertKind.question) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(
              controller: _controller,
              initialQuestionSessionID: target.sessionID,
            ),
          ),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(
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
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(productErrorText(error))));
    }
  }

  void _openSettings() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
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
            navigatorObservers: [_routeTracker],
            scaffoldMessengerKey: _messengerKey,
            builder: (context, child) {
              // Global text-scale safety net: the system setting passes
              // through untouched below the ceiling — including scales under
              // 1.0, which users pick deliberately — and only the extreme top
              // end is capped so a runaway scale cannot break the shell.
              final scale = MediaQuery.textScalerOf(context).scale(1);
              return Theme(
                data: AppTheme.forLocale(
                  Theme.of(context),
                  Localizations.localeOf(context),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      scale > AppTheme.maxTextScale
                          ? AppTheme.maxTextScale
                          : scale,
                    ),
                  ),
                  child: ShorebirdUpdateNotice(
                    service: _updateService,
                    messengerKey: _messengerKey,
                    child: DesktopReleaseNotice(
                      messengerKey: _messengerKey,
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
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              );
            },
            scrollBehavior: const AppScrollBehavior(),
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
              '/': (_) => _Root(),
              '/servers': (_) => const ServersScreen(),
              '/home': (_) => const HomeScreen(),
              '/guide': (_) => GuideScreen(embedded: false),
              '/about': (_) => const AboutScreen(),
              // Termux is an Android app. Registering the route everywhere
              // meant a desktop deep link, or any leftover push, landed on a
              // setup flow with no bridge behind it.
              if (platformCapabilities.supportsTermux)
                '/termux-setup': (_) => const TermuxSetupScreen(),
              '/debug': (_) => AppDiagnosticsScreen(controller: _controller),
            },
            onGenerateRoute: (settings) {
              if (settings.name?.startsWith('/chat/') == true) {
                final id = settings.name!.substring('/chat/'.length);
                final arguments = settings.arguments;
                return MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    sessionID: id,
                    discardIfUntouched:
                        arguments is ChatRouteArguments &&
                        arguments.discardIfUntouched,
                    focusComposer:
                        arguments is ChatRouteArguments &&
                        arguments.focusComposer,
                  ),
                );
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
    if (widget.sessionLinkIntent == null) _sessionLink.dispose();
    super.dispose();
  }
}

/// Remembers which route sits on top of the shell navigator. Only the name
/// matters: unnamed routes (dialogs, sheets, pushed pages) report null.
class _TopRouteTracker extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  String? get topName => _stack.isEmpty ? null : _stack.last.settings.name;

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
  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  bool _started = false;
  int _attempts = 0;
  late final ConnectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(connProvider)..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    // A successful connect resets the streak, so the next failure after a
    // long healthy session starts its count from one again.
    if (_controller.hasConnectedServer) _attempts = 0;
    setState(() {});
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
    WidgetsBinding.instance.addPostFrameCallback((_) => conn.connect(profile));
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
    return Scaffold(
      body: SafeArea(
        child: SavedServerConnectionCard(
          profileName: conn.profile!.name,
          usesConnectionToken: conn.usesConnectionToken,
          requiresTokenReentry: conn.profile!.requiresCodexTokenReentry,
          baseUrl: conn.profile!.baseUrl,
          error: conn.lastError == null
              ? null
              : productErrorText(conn.lastError!),
          attempts: _attempts,
          supportsTermux:
              !conn.usesConnectionToken && platformCapabilities.supportsTermux,
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
              !conn.usesConnectionToken && platformCapabilities.supportsTermux
              ? () => navigator.pushNamed('/termux-setup')
              : null,
          onRetry: () {
            _started = false;
            _connectSaved();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    super.dispose();
  }
}
