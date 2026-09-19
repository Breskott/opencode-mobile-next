import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/sse.dart';
import '../../domain/server_gateway.dart' show ServerCapabilities;
import '../../state/connection.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../desktop/shortcuts.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/glass_surface.dart';
import '../widgets/retained_tab_view.dart';
import '../widgets/server_switcher_sheet.dart';
import 'activity_screen.dart';
import 'servers_screen.dart' show ServersRouteRequest;
import 'project_hub_screen.dart';
import 'settings_screen.dart';
import 'terminal_screen.dart';
import 'workspace_screen.dart';

/// Main mobile product shell for a connected OpenCode server.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AppShortcutSurface {
  // Tab ids follow the visible order, so Ctrl/Cmd+1..4 and `initialTab` mean
  // "the nth destination" and never drift from what the dock shows.
  static const _workTab = 0;
  static const _inboxTab = 1;
  static const _projectTab = 2;
  static const _settingsTab = 3;

  late int _tab;

  /// Bumped by Ctrl+F while the Project destination is showing. The hub opens
  /// Files and focuses its search field. Desktop-only in practice — nothing
  /// dispatches shortcuts off desktop.
  final _findInFiles = ValueNotifier<int>(0);
  final _projectBack = ProjectHubBackController();

  @override
  void initState() {
    super.initState();
    final conn = ref.read(connProvider);
    _tab = _safeTab(widget.initialTab, conn.capabilities);
    conn.addListener(_onConnChanged);
    // If the SSE stream cannot connect at all, fall back to polling.
    if (conn.status == StreamStatus.disconnected) {
      conn.enablePollingFallback();
    }
  }

  /// The shell's own share of the shortcut layer: primary destinations, and
  /// routing Find to the one destination that has a find field.
  @override
  bool onAppShortcut(Intent intent) {
    switch (intent) {
      case SelectDestinationIntent(:final index) when index >= 0 && index <= 3:
        final conn = ref.read(connProvider);
        final next = _safeTab(index, conn.capabilities);
        _selectTab(next);
        return true;
      case FindInSurfaceIntent()
          when _tab == _projectTab &&
              ref.read(connProvider).capabilities.fileBrowsing:
        _findInFiles.value++;
        return true;
      case OpenTerminalIntent()
          when ref.read(connProvider).capabilities.terminal:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TerminalPage(controller: ref.read(connProvider)),
          ),
        );
        return true;
      default:
        return false;
    }
  }

  void _selectTab(int next) {
    if (_tab == next) return;
    _lastBackAt = null;
    setState(() => _tab = next);
  }

  void _onConnChanged() {
    if (!mounted) return;
    final next = _safeTab(_tab, ref.read(connProvider).capabilities);
    setState(() => _tab = next);
  }

  static int _safeTab(int requested, ServerCapabilities capabilities) {
    final tab = requested.clamp(_workTab, _settingsTab);
    return tab == _projectTab && !ProjectHub.isAvailable(capabilities)
        ? _workTab
        : tab;
  }

  @override
  void dispose() {
    try {
      ref.read(connProvider).removeListener(_onConnChanged);
    } catch (_) {}
    _findInFiles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connProvider);
    final activeTab = _safeTab(_tab, conn.capabilities);
    final showDock =
        MediaQuery.sizeOf(context).width < 760 &&
        MediaQuery.viewInsetsOf(context).bottom == 0;

    // One tab per noun (UX plan 5.1): Work, Inbox, Project, Settings. The
    // Inbox carries the product's single pending badge. Project is absent
    // only when the server offers none of its tools (Codex, Paseo today).
    final hasProjectTools = ProjectHub.isAvailable(conn.capabilities);
    final tabs = <Widget>[
      WorkspaceScreen(controller: conn),
      ActivityScreen(controller: conn, embedded: true),
      if (hasProjectTools)
        ProjectHub(
          controller: conn,
          focusSearchSignal: _findInFiles,
          backController: _projectBack,
        )
      else
        const SizedBox.shrink(),
      SettingsScreen(controller: conn, embedded: true),
    ];
    final pending = conn.unifiedAttentionCount;
    final destinations = <({int id, NavigationDestination destination})>[
      (
        id: _workTab,
        destination: NavigationDestination(
          icon: AppGlyph(AppIconography.workspace),
          selectedIcon: AppGlyph(AppIconography.workspaceSelected),
          label: _l10n(context).shellTabWork,
        ),
      ),
      (
        id: _inboxTab,
        destination: NavigationDestination(
          icon: _ActivityIcon(pending: pending, icon: AppIconography.activity),
          selectedIcon: _ActivityIcon(
            pending: pending,
            icon: AppIconography.activitySelected,
          ),
          label: _l10n(context).shellTabInbox,
        ),
      ),
      if (hasProjectTools)
        (
          id: _projectTab,
          destination: NavigationDestination(
            icon: AppGlyph(AppIconography.files),
            selectedIcon: AppGlyph(AppIconography.filesSelected),
            label: _l10n(context).shellTabProject,
          ),
        ),
      (
        id: _settingsTab,
        destination: NavigationDestination(
          icon: Icon(AppIconography.settings),
          selectedIcon: Icon(AppIconography.settings),
          label: _l10n(context).librarySettingsTitle,
        ),
      ),
    ];
    final selectedDestination = destinations.indexWhere(
      (entry) => entry.id == activeTab,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onRootPop,
      child: Scaffold(
        // Scaffold publishes the measured dock height as body bottom padding.
        // Root lists consume it as scroll space, so content can pass beneath
        // the frosted surface while final rows and fixed actions remain usable.
        extendBody: showDock,
        appBar: AppBar(
          title: _WorkspaceAppBarTitle(
            onOpenSwitcher: () => unawaited(_openServerSwitcher(conn)),
            profileName: conn.profile?.name ?? 'OpenCode',
            tabTitle: _titles[activeTab],
            status: conn.status,
            compact: MediaQuery.sizeOf(context).width < 600,
          ),
          // No overflow menu: Disconnect moved into the server switcher
          // (and stays in Settings), the model lives on the composer, and
          // pull-to-refresh covers the two tabs that list conversations.
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              children: [
                if (conn.status != StreamStatus.connected)
                  ConnectionStatusBanner(controller: conn),
                Expanded(
                  child: RetainedTabView(
                    index: activeTab,
                    reduceMotion: GlassSurface.reduceEffects(context),
                    children: tabs,
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 760) return content;
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedDestination,
                  extended: constraints.maxWidth >= 1040,
                  onDestinationSelected: (index) =>
                      _selectTab(destinations[index].id),
                  destinations: [
                    for (final entry in destinations)
                      NavigationRailDestination(
                        icon: entry.destination.icon,
                        selectedIcon: entry.destination.selectedIcon,
                        label: Text(entry.destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          },
        ),
        bottomNavigationBar: showDock
            ? SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: GlassSurface(
                  child: LayoutBuilder(
                    builder: (context, constraints) => _ShellNavigation(
                      width: constraints.maxWidth,
                      destinations: [
                        for (final entry in destinations) entry.destination,
                      ],
                      selectedIndex: selectedDestination,
                      onSelected: (index) => _selectTab(destinations[index].id),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// The switcher only chooses. Connecting, credentials, adding and
  /// forgetting all run on the Servers screen, which already owns the
  /// runtime-choice detour and shows a failed connect next to its fix.
  Future<void> _openServerSwitcher(ConnectionController conn) async {
    final navigator = Navigator.of(context);
    final choice = await showServerSwitcher(context, conn);
    if (choice == null || !navigator.mounted) return;
    switch (choice) {
      case ServerSwitcherOpenServers(:final ServersRouteRequest? request):
        unawaited(navigator.pushNamed('/servers', arguments: request));
      case ServerSwitcherOpenPhoneSetup():
        unawaited(navigator.pushNamed('/termux-setup'));
      case ServerSwitcherLeave(:final alreadyDisconnected):
        if (!alreadyDisconnected) await conn.disconnect();
        if (!navigator.mounted) return;
        unawaited(navigator.pushNamedAndRemoveUntil('/servers', (_) => false));
    }
  }

  /// Project first unwinds Files and returns to its hub, then destinations
  /// return home.
  /// Only Work uses the double-back exit guard.
  void _onRootPop(bool didPop, Object? result) {
    if (didPop) return;
    if (_tab == _projectTab && _projectBack.handleBack()) {
      _lastBackAt = null;
      return;
    }
    if (_tab != _workTab) {
      _selectTab(_workTab);
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_l10n(context).e7WorkspaceBackExit),
          duration: Duration(seconds: 2),
        ),
      );
  }

  DateTime? _lastBackAt;

  List<String> get _titles => [
    _l10n(context).shellTabWork,
    _l10n(context).shellTabInbox,
    _l10n(context).shellTabProject,
    _l10n(context).librarySettingsTitle,
  ];
}

/// Label metrics depend on typography and available width, not connection
/// traffic or which destination happens to be selected.
class _ShellNavigation extends StatefulWidget {
  const _ShellNavigation({
    required this.width,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final double width;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_ShellNavigation> createState() => _ShellNavigationState();
}

class _ShellNavigationState extends State<_ShellNavigation> {
  Object? _metricsKey;
  double _maxScale = 1;
  double _labelHeight = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigation = theme.navigationBarTheme;
    // Resolve partial theme styles before both measuring and painting labels;
    // otherwise Text inherits body metrics while TextPainter measures defaults.
    final labelBase = theme.textTheme.labelSmall!;
    final normal = labelBase
        .merge(navigation.labelTextStyle?.resolve({}))
        .copyWith(color: GlassSurface.foregroundColor(theme));
    final selected = labelBase
        .merge(navigation.labelTextStyle?.resolve({WidgetState.selected}))
        .copyWith(color: GlassSurface.foregroundColor(theme));
    final direction = Directionality.of(context);
    final key = (
      widget.width,
      widget.destinations
          .map((destination) => destination.label)
          .join('\u0000'),
      normal,
      selected,
      direction,
    );
    if (_metricsKey != key) {
      _metricsKey = key;
      _maxScale = 2;
      _labelHeight = 0;
      for (final destination in widget.destinations) {
        for (final style in [normal, selected]) {
          final painter = TextPainter(
            text: TextSpan(text: destination.label, style: style),
            textDirection: direction,
          )..layout();
          final fit =
              (widget.width / widget.destinations.length - 8) / painter.width;
          if (fit < _maxScale) _maxScale = fit;
          if (painter.height > _labelHeight) _labelHeight = painter.height;
          painter.dispose();
        }
      }
      _maxScale = _maxScale.clamp(1.0, 2.0);
    }
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _maxScale);
    // The painted indicator is 32dp high. Its whole destination remains a
    // 72dp touch target; counting a separate 48dp icon hit box made the dock
    // unnecessarily tall. Leave at least 8dp above and below the visible stack.
    final requiredHeight = 32 + 4 + scaler.scale(_labelHeight) + 16;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxScale,
      child: NavigationBarTheme(
        data: navigation.copyWith(
          // Muted/primary roles can lose contrast when a bright or dark row
          // passes beneath the translucent dock. Keep its foreground robust.
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: GlassSurface.foregroundColor(theme)),
          ),
        ),
        child: NavigationBar(
          height: requiredHeight > 72 ? requiredHeight : 72,
          backgroundColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? selected : normal,
          ),
          animationDuration: GlassSurface.reduceEffects(context)
              ? Duration.zero
              : RetainedTabView.duration,
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onSelected,
          destinations: widget.destinations,
        ),
      ),
    );
  }
}

/// The product's single pending badge (audit UX-P0-01). Semantics carry the
/// count in words so the number is not colour- or shape-only.
class _ActivityIcon extends StatelessWidget {
  final int pending;
  final IconData icon;

  const _ActivityIcon({required this.pending, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (pending <= 0) return AppGlyph(icon);
    return Semantics(
      label: _l10n(context).e7WorkspaceAttentionCount(pending),
      child: Badge(
        key: const ValueKey('activity-pending-badge'),
        label: Text('$pending'),
        child: AppGlyph(icon),
      ),
    );
  }
}

class _WorkspaceAppBarTitle extends StatelessWidget {
  final VoidCallback onOpenSwitcher;
  final String profileName;
  final String tabTitle;
  final StreamStatus status;
  final bool compact;

  const _WorkspaceAppBarTitle({
    required this.onOpenSwitcher,
    required this.profileName,
    required this.tabTitle,
    required this.status,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = Tooltip(
      message: profileName,
      child: Semantics(
        label: _l10n(context).e7WorkspaceServerName(profileName),
        excludeSemantics: true,
        child: Text(
          profileName,
          key: const ValueKey('server-profile-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
    final page = Text(
      tabTitle,
      key: const ValueKey('current-tab-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: AppTheme.mutedOf(theme),
      ),
    );
    final server = Row(
      children: [
        _StatusDot(status: status),
        const SizedBox(width: 8),
        Flexible(child: profile),
        // The visible handle: the name is a control, not a caption.
        Icon(
          AppIconography.chevronDown,
          size: 18,
          color: AppTheme.mutedOf(theme),
        ),
      ],
    );
    // The whole block is the target so it clears 48dp in the app bar; the
    // name alone would be a 20dp strip.
    Widget switcher(Widget child) => Semantics(
      button: true,
      hint: _l10n(context).serverSwitcherOpen,
      child: InkWell(
        key: const ValueKey('server-switcher-button'),
        borderRadius: BorderRadius.circular(8),
        onTap: onOpenSwitcher,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: child,
        ),
      ),
    );

    if (compact) {
      return switcher(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            server,
            const SizedBox(height: 1),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 18),
              child: page,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: switcher(server)),
        const SizedBox(width: 12),
        page,
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final StreamStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (tone, pulse) = switch (status) {
      StreamStatus.connected => (AppStatusTone.ok, false),
      StreamStatus.connecting ||
      StreamStatus.reconnecting => (AppStatusTone.progress, true),
      StreamStatus.disconnected => (AppStatusTone.failure, false),
    };
    final color = AppTheme.statusColor(theme, tone);
    final label = switch (status) {
      StreamStatus.connected => _l10n(context).e7WorkspaceConnected,
      StreamStatus.connecting => _l10n(context).e7WorkspaceConnecting,
      StreamStatus.reconnecting => _l10n(context).mcpReconnecting,
      StreamStatus.disconnected => _l10n(context).e7WorkspaceOffline,
    };
    return Semantics(
      label: _l10n(context).e7WorkspaceServerStatus(label),
      child: Tooltip(
        message: label,
        child: pulse && !GlassSurface.reduceEffects(context)
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
      ),
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
