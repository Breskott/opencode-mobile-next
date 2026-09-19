import 'package:flutter/material.dart';

import '../../domain/profile_monitor.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../../state/profile_monitor.dart' show ProfileMonitor;
import '../app_theme.dart';
import 'activity_screen.dart' show showQuestionSheet;
import 'chat/form_flow.dart';
import 'chat/permission_sheet.dart';
import 'chat_screen.dart' show ChatScreen;
import 'settings_screen.dart' show NotificationsSettingsScreen;

/// Shared explicit route: revalidates profile, location and exact request before
/// displaying the existing resolver. It never answers from monitor metadata.
Future<void> openMonitoredRequest(
  BuildContext context,
  ConnectionController controller,
  MonitoredRoute route,
) async {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  if (controller.profile?.id != route.profileID &&
      controller.busySessions.isNotEmpty) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.monitorSwitchTitle),
        content: Text(l10n.monitorSwitchDetail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.monitorSwitch),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
  }
  try {
    if (!await controller.prepareMonitoredRequest(route) || !context.mounted) {
      throw StateError('Changed');
    }
    switch (route.kind) {
      case MonitoredRequestKind.permission:
        final request = controller.permissions[route.requestID];
        if (request == null || request.sessionID != route.sessionID) {
          throw StateError('Changed');
        }
        await showPermissionSheet(
          context,
          permission: request,
          controller: controller,
        );
      case MonitoredRequestKind.question:
        final request = controller.questions[route.requestID];
        if (request == null || request.sessionID != route.sessionID) {
          throw StateError('Changed');
        }
        await showQuestionSheet(context, controller, request);
      case MonitoredRequestKind.form:
        final request = controller.forms[route.requestID];
        if (request == null || request.sessionID != route.sessionID) {
          throw StateError('Changed');
        }
        await presentConnectionForm(context, controller, request);
      case MonitoredRequestKind.checkIn:
        // The reminder's answer is the conversation itself, on the existing
        // chat route; nothing is sent or resolved on the user's behalf.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(sessionID: route.sessionID),
          ),
        );
    }
    await controller.profileMonitor.refresh();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.monitorOpenFailed)));
    }
  }
}

class ProfileMonitorScreen extends StatelessWidget {
  const ProfileMonitorScreen({super.key, required this.controller});
  final ConnectionController controller;
  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monitorTitle),
        actions: [
          IconButton(
            tooltip: l10n.monitorRefresh,
            onPressed: controller.profileMonitor.refresh,
            icon: const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.monitorScope),
              // The list lives here; how it notifies lives in one place.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('monitor-notification-settings'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          NotificationsSettingsScreen(controller: controller),
                    ),
                  ),
                  icon: const Icon(AppIconography.notificationImportant),
                  label: Text(l10n.monitorNotificationSettings),
                ),
              ),
              if (controller.store.profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.monitorNoServers),
                ),
              for (final profile in controller.store.profiles)
                if (controller.isProfileReadable(profile.id))
                  _MonitorProfile(controller: controller, profile: profile),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMonitorInbox extends StatelessWidget {
  const ProfileMonitorInbox({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final ConnectionController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (controller.isIsolated) return const SizedBox.shrink();
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final monitor = controller.profileMonitor;
    final summary = ListTile(
      leading: const Icon(AppIconography.server),
      title: Text(compact ? l10n.activitySavedServers : l10n.monitorTitle),
      subtitle: Text(
        compact
            ? [
                if (controller.unifiedAttentionCount > 0)
                  l10n.activityPendingCount(controller.unifiedAttentionCount),
                if (controller.unknownAttentionProfileCount > 0)
                  l10n.activityUnknownCount(
                    controller.unknownAttentionProfileCount,
                  ),
                l10n.activitySelectedLocationsOnly,
              ].join(' · ')
            : l10n.monitorPendingSummary(
                controller.unifiedAttentionCount,
                controller.unknownAttentionProfileCount,
              ),
      ),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileMonitorScreen(controller: controller),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) summary,
        if (!compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.monitorScope,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final profile in controller.store.profiles)
          if (controller.isProfileReadable(profile.id))
            if (monitor.snapshotFor(profile.id) case final snapshot
                when snapshot.isCurrent) ...[
              if (profile.id != controller.profile?.id)
                for (final request in snapshot.requests)
                  _MonitorRequestRow(
                    controller: controller,
                    profile: profile,
                    request: request,
                  ),
              for (final interval in snapshot.dueCheckIns(
                monitor.rulesFor(profile.id),
              ))
                _MonitorRequestRow(
                  controller: controller,
                  profile: profile,
                  request: interval.toRequest(),
                ),
            ],
        if (compact) summary,
      ],
    );
  }
}

class _MonitorRequestRow extends StatelessWidget {
  const _MonitorRequestRow({
    required this.controller,
    required this.profile,
    required this.request,
  });
  final ConnectionController controller;
  final ServerProfile profile;
  final MonitoredRequest request;
  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final checked = controller.profileMonitor.snapshotFor(profile.id).checkedAt;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        key: ValueKey('monitor-row-${request.identity}'),
        leading: request.kind == MonitoredRequestKind.checkIn
            ? const Icon(AppIconography.waitingStart, size: 20)
            : const ServerAttentionDot(current: true),
        title: Text(
          request.title?.trim().isNotEmpty == true
              ? request.title!
              : l10n.monitorSession,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          l10n.monitorRequestSummary(
            profile.name,
            switch (request.kind) {
              MonitoredRequestKind.permission => l10n.monitorPermission,
              MonitoredRequestKind.question => l10n.monitorQuestion,
              MonitoredRequestKind.form => l10n.monitorForm,
              MonitoredRequestKind.checkIn => l10n.monitorCheckInDue,
            },
            l10n.monitorLastChecked,
            _time(context, checked),
          ),
        ),
        onTap: () => openMonitoredRequest(
          context,
          controller,
          MonitoredRoute(
            profileID: profile.id,
            requestID: request.id,
            sessionID: request.sessionID,
            kind: request.kind,
            createdAt: checked ?? DateTime.now(),
            serverUrl: profile.baseUrl,
            sourceIdentity: ProfileMonitor.routeSourceIdentity(profile),
            directory: request.directory,
            workspace: request.workspace,
          ),
        ),
      ),
    );
  }
}

/// A server-status dot always paired with textual status by its parent row.
class ServerAttentionDot extends StatelessWidget {
  const ServerAttentionDot({super.key, required this.current});
  final bool current;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      AppIconography.statusDot,
      size: 12,
      color: AppTheme.statusColor(
        Theme.of(context),
        current ? AppStatusTone.ok : AppStatusTone.neutral,
      ),
    ),
  );
}

String _time(BuildContext context, DateTime? value) => value == null
    ? lookupAppLocalizations(Localizations.localeOf(context)).monitorUnknown
    : '${MaterialLocalizations.of(context).formatShortDate(value.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()))}';
String monitorStatusText(AppLocalizations l10n, ProfileMonitorStatus status) =>
    switch (status) {
      ProfileMonitorStatus.disabled => l10n.monitorDisabled,
      ProfileMonitorStatus.waiting => l10n.monitorWaiting,
      ProfileMonitorStatus.checking => l10n.monitorChecking,
      ProfileMonitorStatus.current => l10n.monitorCurrent,
      ProfileMonitorStatus.unavailable => l10n.monitorUnavailable,
      ProfileMonitorStatus.wifiRequired => l10n.monitorWifiRequired,
      ProfileMonitorStatus.paused => l10n.monitorPaused,
    };

/// One saved server in the live list: its status and what the last check
/// found. Whether it is monitored, and how that notifies, is set in
/// Notifications; this screen only shows the result.
class _MonitorProfile extends StatelessWidget {
  const _MonitorProfile({required this.controller, required this.profile});
  final ConnectionController controller;
  final ServerProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final monitor = controller.profileMonitor, id = profile.id;
    final rules = monitor.rulesFor(id), snapshot = monitor.snapshotFor(id);
    final supported = monitor.supportsProfile(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ServerAttentionDot(current: snapshot.isCurrent),
          title: Text(
            profile.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            supported
                ? monitorStatusText(l10n, snapshot.status)
                : l10n.e7ProjectMonitorUnsupported,
          ),
        ),
        if (supported && rules.enabled) ...[
          Text(
            l10n.monitorLabeledTime(
              l10n.monitorLastChecked,
              _time(context, snapshot.checkedAt),
            ),
          ),
          Text(
            l10n.monitorLabeledTime(
              l10n.monitorNextCheck,
              _time(context, snapshot.nextCheckAt),
            ),
          ),
          if (snapshot.isCurrent && snapshot.requests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n.monitorAllClear),
            ),
          if (snapshot.isCurrent)
            for (final request in snapshot.requests)
              _MonitorRequestRow(
                controller: controller,
                profile: profile,
                request: request,
              ),
          if (snapshot.isCurrent && rules.checkInAfterMinutes != null)
            for (final interval in snapshot.busyIntervals)
              _BusyIntervalRow(
                controller: controller,
                profile: profile,
                interval: interval,
                due: interval.isDue(rules),
                checkedAt: snapshot.checkedAt,
              ),
        ],
      ],
    );
  }
}

/// One session the last poll saw busy. The row names the time between busy
/// samples without claiming continuous work or the current run's duration.
class _BusyIntervalRow extends StatelessWidget {
  const _BusyIntervalRow({
    required this.controller,
    required this.profile,
    required this.interval,
    required this.due,
    required this.checkedAt,
  });
  final ConnectionController controller;
  final ServerProfile profile;
  final ObservedBusyInterval interval;
  final bool due;
  final DateTime? checkedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final title = interval.title?.trim().isNotEmpty == true
        ? interval.title!
        : l10n.monitorSession;
    final observed = l10n.monitorObservedBusy(
      interval.observedFor.inMinutes,
      _time(context, interval.firstObservedBusyAt),
    );
    return ListTile(
      key: ValueKey('monitor-busy-${interval.sessionID}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        due ? AppIconography.waitingStart : AppIconography.waitingEmpty,
        color: due ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(due ? '${l10n.monitorCheckInDue} · $observed' : observed),
      trailing: due ? const Icon(AppIconography.chevronRight) : null,
      onTap: () => openMonitoredRequest(
        context,
        controller,
        MonitoredRoute(
          profileID: profile.id,
          requestID: interval.id,
          sessionID: interval.sessionID,
          kind: MonitoredRequestKind.checkIn,
          createdAt: checkedAt ?? DateTime.now(),
          serverUrl: profile.baseUrl,
          sourceIdentity: ProfileMonitor.routeSourceIdentity(profile),
          directory: interval.directory,
          workspace: interval.workspace,
        ),
      ),
    );
  }
}
