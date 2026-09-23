import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../builtin/builtin_server.dart';
import '../../../builtin/setup/phone_setup.dart';
import '../../../builtin/setup/setup_contract.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../../state/profiles.dart';
import '../../../state/termux_running_server.dart';
import '../../app_theme.dart';
import '../../widgets/product_states.dart' show productErrorText;
import '../servers_screen.dart' show ServersRouteRequest;
import 'phone_setup_routes.dart';
import 'phone_setup_selection.dart';

/// Screen A of phone setup v2 (docs/design/phone-setup-v2-2026-09-24.md):
/// "On this phone". One promise, one filled button, and the less common ways
/// folded away underneath.
///
/// The hero follows what is true on the phone right now, in this order:
/// a setup that is running or stopped part way ("Setup is 42% done"), an
/// OpenCode that is ready in the app, one that Termux already runs, and only
/// then the first-time promise. Every number in the promise comes from the
/// component registry, so adding a component changes it with no screen code.
class PhoneSetupStartScreen extends ConsumerStatefulWidget {
  const PhoneSetupStartScreen({
    super.key,
    this.termuxProbe,
    this.inAppProbe,
    this.openProgress = _openFirstSetupProgress,
  });

  /// Looks for an OpenCode that the Termux path already set up. Defaults to
  /// the read-only [detectTermuxRunningServer]; tests stand in for Termux.
  final Future<TermuxRunningServer> Function()? termuxProbe;

  /// Whether the in-app OpenCode is installed even though no setup job says
  /// so (it was set up before setup v2 kept a job). Defaults to a saved
  /// in-app profile plus the Linux base being there.
  final Future<bool> Function()? inAppProbe;

  /// Screen B. A parameter so tests can see the hand-over without building
  /// the progress screen.
  final Future<void> Function(BuildContext context) openProgress;

  @override
  ConsumerState<PhoneSetupStartScreen> createState() =>
      _PhoneSetupStartScreenState();
}

enum _Hero { loading, fresh, progress, ready, termux }

class _PhoneSetupStartScreenState extends ConsumerState<PhoneSetupStartScreen> {
  late final SetupEngine _engine;
  late Set<String> _selection;

  /// Until the persisted job is read, the screen cannot know whether to
  /// promise a first setup or offer to continue one, so it promises nothing.
  bool _restored = false;
  bool _inAppInstalled = false;
  TermuxRunningServer? _termux;
  bool _busy = false;
  String? _failure;

  /// Leaving the screen stops a Termux look that is still waiting, so its
  /// deadlines do not outlive the page.
  final _discovery = TermuxDiscoveryCancellation();

  @override
  void initState() {
    super.initState();
    _engine = PhoneSetup.engine;
    _selection = defaultSetupSelection(installableComponents(_engine.registry));
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      // An app restart leaves an interrupted job on disk; reading it is what
      // turns this screen into "Continue". A read that hangs must not hold
      // the screen hostage, so it gets a few seconds and then the screen
      // shows what it knows.
      await _engine.restore().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Nothing restored: the progress stays idle and the promise shows.
    }
    if (!mounted) return;
    setState(() => _restored = true);
    unawaited(_probeInApp());
    unawaited(_probeTermux());
  }

  Future<void> _probeInApp() async {
    bool installed;
    try {
      installed = await (widget.inAppProbe ?? _defaultInAppProbe)();
    } catch (_) {
      installed = false;
    }
    if (mounted && installed != _inAppInstalled) {
      setState(() => _inAppInstalled = installed);
    }
  }

  Future<bool> _defaultInAppProbe() async {
    final profile = _inAppProfile();
    if (profile == null) return false;
    return isInAppServer(profile, ref.read(builtinLinuxProvider));
  }

  Future<void> _probeTermux() async {
    TermuxRunningServer found;
    try {
      found =
          await (widget.termuxProbe ??
              () => detectTermuxRunningServer(
                profiles: ref.read(bootstrapProvider).store.profiles,
                cancellation: _discovery,
              ))();
    } catch (_) {
      found = const TermuxRunningServer.unavailable();
    }
    if (mounted) setState(() => _termux = found);
  }

  @override
  void dispose() {
    _discovery.cancel();
    super.dispose();
  }

  bool get _termuxPresent =>
      _termux != null && (_termux!.isRunning || _termux!.isStopped);

  _Hero _heroFor(SetupProgress progress) {
    if (!_restored) return _Hero.loading;
    switch (progress.state) {
      case SetupState.running:
      case SetupState.interrupted:
      case SetupState.failed:
      case SetupState.cancelled:
        return _Hero.progress;
      case SetupState.done:
        return _Hero.ready;
      case SetupState.idle:
        break;
    }
    if (_inAppInstalled) return _Hero.ready;
    if (_termuxPresent) return _Hero.termux;
    return _Hero.fresh;
  }

  /// The in-app profile to open: the active one when it is in-app, else the
  /// first saved one. The app keeps one per OpenCode generation.
  ServerProfile? _inAppProfile() {
    final store = ref.read(bootstrapProvider).store;
    ServerProfile? first;
    for (final profile in store.profiles) {
      if (!looksLikeInAppServer(profile)) continue;
      if (profile.id == store.activeId) return profile;
      first ??= profile;
    }
    return first;
  }

  /// The selection of the job on disk, so "Continue" resumes that job rather
  /// than whatever the switches say now.
  Set<String> _jobSelection(SetupProgress progress) =>
      progress.components.isEmpty
      ? _selection
      : {for (final component in progress.components) component.id};

  Future<void> _run(Set<String> ids) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      // Everything started here is the phone's first setup; the job keeps
      // that fact so a notification tap after the app was killed still ends
      // on "name your first project".
      await _engine.run(ids, params: SetupJobParams.firstSetup);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = _l10n.phoneSetupStartFailed(productErrorText(error));
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _showProgress();
  }

  Future<void> _showProgress() async {
    await widget.openProgress(context);
    // The person may come back after it finished; re-read what is installed
    // so the hero is not left on a stale promise.
    if (mounted) unawaited(_probeInApp());
  }

  Future<void> _continue(SetupProgress progress) async {
    if (progress.canContinue) {
      // The check scripts skip what is already installed, so running the
      // same selection again is exactly a resume.
      await _run(_jobSelection(progress));
    } else {
      await _showProgress();
    }
  }

  Future<void> _open(SetupProgress progress) async {
    final profile = _inAppProfile();
    if (profile == null) {
      // A finished job ends by starting OpenCode and connecting to it. With
      // no saved connection that last step never happened (or was forgotten),
      // and running the job again redoes just that: every check passes.
      await _run(_jobSelection(progress));
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final l10n = _l10n;
    final navigator = Navigator.of(context);
    String? failure;
    try {
      final connection = ref.read(connProvider);
      final alreadyThere =
          connection.hasConnectedServer && connection.profile?.id == profile.id;
      if (!alreadyThere) {
        var running = false;
        try {
          running =
              (await ref.read(builtinLinuxProvider).status()).serverRunning;
        } catch (_) {
          // Unknown counts as stopped; starting a running one only restarts.
        }
        if (!running) {
          final startFailure = await ref
              .read(builtinServerStarterProvider)
              .start(profile);
          if (startFailure != null) failure = startFailure.reason(l10n);
        }
        if (failure == null) {
          await connection.connect(profile);
          if (!connection.hasConnectedServer) {
            failure = connection.lastError ?? l10n.builtinServerStopped;
          }
        }
      }
    } catch (error) {
      failure = productErrorText(error);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure == null ? null : l10n.phoneSetupStartFailed(failure);
    });
    if (failure == null) {
      unawaited(navigator.pushNamedAndRemoveUntil('/home', (_) => false));
    }
  }

  /// Termux already runs OpenCode: hand over to the Servers screen, which
  /// owns connecting, restoring the phone's password and the start card.
  void _connectTermux() {
    final server = _termux;
    if (server == null) return;
    final profile = savedProfileForTermuxServer(
      ref.read(bootstrapProvider).store.profiles,
      server,
    );
    final ServersRouteRequest? request;
    if (!server.isRunning) {
      // Stopped: the Servers list leads with that phone server and its Start.
      request = null;
    } else if (profile != null) {
      request = ServersRouteRequest.connect(profile.id, detectedRunning: true);
    } else {
      request = ServersRouteRequest.enterPhoneCredentials(
        openCode2: server.flavor == ServerFlavor.v2,
      );
    }
    unawaited(
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/servers', (_) => false, arguments: request),
    );
  }

  Future<void> _useTermux() async {
    await Navigator.of(context).pushNamed('/termux-setup');
    // Setting Termux up there changes what this screen should lead with.
    if (mounted) unawaited(_probeTermux());
  }

  void _connectByAddress() {
    unawaited(
      Navigator.of(
        context,
      ).pushNamed('/servers', arguments: const ServersRouteRequest.add()),
    );
  }

  Future<void> _customize() async {
    final chosen = await showPhoneSetupCustomize(context, selected: _selection);
    if (chosen != null && mounted) setState(() => _selection = chosen);
  }

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.phoneSetupStartScreenTitle)),
      body: SafeArea(
        child: ValueListenableBuilder<SetupProgress>(
          valueListenable: _engine.progress,
          builder: (context, progress, _) {
            final hero = _heroFor(progress);
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: _Entrance(
                          reduceMotion: reduceMotion,
                          child: _body(context, l10n, hero, progress),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    _Hero hero,
    SetupProgress progress,
  ) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final install = expandSetupSelection(
      installableComponents(_engine.registry),
      _selection,
    );
    final included = includedToolNames(install);
    final includesText = included.isEmpty
        ? null
        : l10n.phoneSetupStartIncludes(joinSetupNames(l10n, included));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _PhoneSparkIllustration()),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(hero),
            child: _hero(context, l10n, hero, progress, install),
          ),
        ),
        if (_failure != null) ...[
          const SizedBox(height: 12),
          Text(
            _failure!,
            key: const ValueKey('phone-setup-start-failure'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (hero == _Hero.fresh && includesText != null) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                includesText,
                key: const ValueKey('phone-setup-start-includes'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
              TextButton(
                key: const ValueKey('phone-setup-start-customize'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _busy ? null : _customize,
                child: Text(l10n.phoneSetupStartCustomize),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        if (hero != _Hero.loading)
          _otherWays(context, l10n, hero, includesText),
      ],
    );
  }

  Widget _hero(
    BuildContext context,
    AppLocalizations l10n,
    _Hero hero,
    SetupProgress progress,
    List<SetupComponent> install,
  ) {
    final theme = Theme.of(context);
    if (hero == _Hero.loading) {
      // Holds the hero's place so the page does not jump when it arrives.
      return const SizedBox(height: 160);
    }
    final String headline;
    final String body;
    final String action;
    final VoidCallback onPressed;
    Widget? meter;
    switch (hero) {
      case _Hero.loading:
      case _Hero.fresh:
        final totals = setupTotals(install);
        final time = setupDurationText(l10n, totals.seconds);
        headline = l10n.phoneSetupStartHeadline;
        body = totals.bytes > 0
            ? l10n.phoneSetupStartPromise(
                time,
                setupSizeText(l10n, totals.bytes),
              )
            : l10n.phoneSetupStartPromiseNoSize(time);
        action = l10n.phoneSetupStartSetUp;
        onPressed = () => unawaited(_run(_selection));
      case _Hero.progress:
        // Never "100% done" while it is still going: the last step
        // (starting OpenCode) has no bar of its own.
        final percent = (progress.overall * 100).floor().clamp(0, 99);
        headline = l10n.phoneSetupStartProgressHeadline(percent);
        body = progress.state == SetupState.running
            ? l10n.phoneSetupStartRunningBody
            : l10n.phoneSetupStartStoppedBody;
        action = l10n.phoneSetupStartContinue;
        onPressed = () => unawaited(_continue(progress));
        meter = ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            key: const ValueKey('phone-setup-start-meter'),
            value: progress.overall.clamp(0, 1).toDouble(),
            minHeight: 4,
            color: progress.state == SetupState.running
                ? theme.colorScheme.primary
                : AppTheme.mutedOf(theme),
            backgroundColor: AppTheme.hairline(theme),
          ),
        );
      case _Hero.ready:
        headline = l10n.phoneSetupStartReadyHeadline;
        body = l10n.phoneSetupStartReadyBody;
        action = l10n.phoneSetupStartOpen;
        onPressed = () => unawaited(_open(progress));
      case _Hero.termux:
        headline = l10n.phoneSetupStartTermuxHeadline;
        body = l10n.phoneSetupStartTermuxBody;
        action = l10n.phoneSetupStartConnect;
        onPressed = _connectTermux;
    }
    return Column(
      key: ValueKey('phone-setup-start-hero-${hero.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            headline,
            key: const ValueKey('phone-setup-start-headline'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          key: const ValueKey('phone-setup-start-body'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.mutedOf(theme),
            height: 1.4,
          ),
        ),
        if (meter != null) ...[const SizedBox(height: 20), meter],
        const SizedBox(height: 28),
        FilledButton(
          key: const ValueKey('phone-setup-start-primary'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _busy ? null : onPressed,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(action, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _otherWays(
    BuildContext context,
    AppLocalizations l10n,
    _Hero hero,
    String? includesText,
  ) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Theme(
      // Lines, not boxes: the expander draws no borders of its own.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('phone-setup-start-other-ways'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          l10n.phoneSetupStartOtherWays,
          style: theme.textTheme.titleSmall?.copyWith(color: muted),
        ),
        children: [
          Divider(height: 1, color: AppTheme.hairline(theme)),
          // Termux already runs OpenCode, so Connect leads; the in-app setup
          // stays one tap away for someone who wants to move off Termux.
          if (hero == _Hero.termux)
            ListTile(
              key: const ValueKey('phone-setup-start-set-up-here'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIconography.phone),
              title: Text(l10n.phoneSetupStartSetUpHere),
              subtitle: includesText == null
                  ? null
                  : Text(includesText, style: TextStyle(color: muted)),
              trailing: const Icon(AppIconography.chevronRight),
              enabled: !_busy,
              onTap: () => unawaited(_run(_selection)),
            ),
          if (hero != _Hero.termux)
            ListTile(
              key: const ValueKey('phone-setup-start-use-termux'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIconography.terminal),
              title: Text(l10n.phoneSetupStartUseTermux),
              subtitle: Text(
                l10n.phoneSetupStartAdvanced,
                style: TextStyle(color: muted),
              ),
              trailing: const Icon(AppIconography.chevronRight),
              enabled: !_busy,
              onTap: () => unawaited(_useTermux()),
            ),
          ListTile(
            key: const ValueKey('phone-setup-start-by-address'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIconography.link),
            title: Text(l10n.phoneSetupStartByAddress),
            trailing: const Icon(AppIconography.chevronRight),
            enabled: !_busy,
            onTap: _connectByAddress,
          ),
        ],
      ),
    );
  }
}

/// A short rise and fade the first time the page shows, so it arrives
/// rather than blinks in. Reduce motion shows it in place at once.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.reduceMotion, required this.child});

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// The quiet picture at the top: a phone outline with a spark at its top
/// corner. Drawn rather than shipped as an image so it follows the theme's
/// colours in every pack and needs no asset.
class _PhoneSparkIllustration extends StatelessWidget {
  const _PhoneSparkIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: 120,
        height: 112,
        child: CustomPaint(
          painter: _PhoneSparkPainter(
            outline: AppTheme.mutedOf(theme),
            lines: AppTheme.hairline(theme),
            spark: theme.colorScheme.primary,
            wash: AppTheme.liveTint(theme, alpha: .10),
            direction: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _PhoneSparkPainter extends CustomPainter {
  _PhoneSparkPainter({
    required this.outline,
    required this.lines,
    required this.spark,
    required this.wash,
    required this.direction,
  });

  final Color outline;
  final Color lines;
  final Color spark;
  final Color wash;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    // Mirror for right-to-left so the spark sits at the reading end.
    if (direction == TextDirection.rtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.height / 2, Paint()..color = wash);

    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(-6, 4), width: 54, height: 86),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      phone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = outline,
    );
    // The speaker slot and three lines of "code" on the screen.
    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final top = phone.top;
    final left = phone.left;
    canvas.drawLine(
      Offset(phone.center.dx - 6, top + 8),
      Offset(phone.center.dx + 6, top + 8),
      stroke..color = outline,
    );
    stroke.color = lines;
    for (final (dy, width) in [(26.0, 26.0), (36.0, 34.0), (46.0, 20.0)]) {
      canvas.drawLine(
        Offset(left + 10, top + dy),
        Offset(left + 10 + width, top + dy),
        stroke,
      );
    }
    stroke.color = spark;
    canvas.drawLine(
      Offset(left + 10, top + 56),
      Offset(left + 22, top + 56),
      stroke,
    );

    _star(canvas, Offset(phone.right + 4, phone.top + 6), 14);
    _star(canvas, Offset(phone.right + 20, phone.top + 26), 6);
  }

  /// A four-point spark: four quadratic curves pulled in toward the middle.
  void _star(Canvas canvas, Offset c, double r) {
    final inner = r * .18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + inner, c.dy - inner, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + inner, c.dy + inner, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - inner, c.dy + inner, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - inner, c.dy - inner, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = spark);
  }

  @override
  bool shouldRepaint(_PhoneSparkPainter old) =>
      old.outline != outline ||
      old.lines != lines ||
      old.spark != spark ||
      old.wash != wash ||
      old.direction != direction;
}

/// Everything started from this screen is a first setup, so it ends on
/// "name your first project".
Future<void> _openFirstSetupProgress(BuildContext context) =>
    openPhoneSetupProgress(context, firstSetup: true);
