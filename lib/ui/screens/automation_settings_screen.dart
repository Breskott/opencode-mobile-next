import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/automation_policy.dart';
import '../../state/connection.dart';
import '../../state/profiles.dart';
import '../../state/team_planning.dart' show TeamSupervision;
import '../app_theme.dart';
import '../kit/kit.dart';
import '../widgets/phone_server_card.dart' show serverDisplayName;
import 'saved_permissions_screen.dart';
import 'settings_screen.dart' show NotificationsSettingsScreen;
import 'team/start_run_sheet.dart' show teamSupervisionCopy;

/// What the "What runs by itself" page can show for the current server.
/// Each part is present only where something real sits behind it: the
/// team's level only with a team, the saved rules only where the server
/// lists them, watching only for a server the monitor can read.
@immutable
class AutomationSettingsSections {
  const AutomationSettingsSections({
    required this.team,
    required this.savedRules,
    required this.watch,
  });

  /// How much the AI Team decides alone (the level new tasks start at).
  final bool team;

  /// The server's "Always allowed actions".
  final bool savedRules;

  /// Watching this server in the background for requests.
  final bool watch;

  bool get any => team || savedRules || watch;

  /// The sections [controller]'s current server supports; [team] overrides
  /// whether the AI Team is set up (tests describe it without a host).
  static AutomationSettingsSections of(
    ConnectionController controller, {
    bool? team,
  }) {
    final profile = controller.profile;
    if (profile == null) {
      return const AutomationSettingsSections(
        team: false,
        savedRules: false,
        watch: false,
      );
    }
    return AutomationSettingsSections(
      team: team ?? controller.orchestration != null,
      savedRules: controller.capabilities.savedPermissionList,
      watch:
          !controller.isIsolated &&
          controller.isProfileReadable(profile.id) &&
          controller.profileMonitor.supportsProfile(profile),
    );
  }
}

/// Settings › What runs by itself (`automation-settings`, P6.1): what the
/// app and the agent do on the current server without asking first, and
/// the place to turn each of it off.
///
/// One page per server, built from kit parts: an intro line naming the
/// server, the AI Team's supervision as a [KitChoiceList] (stored in this
/// server's [AutomationPolicy], `oc.automation.<profileId>`; new team tasks
/// start at it), and one [KitRowGroup] of doors to where the rest already
/// lives: Always allowed actions (the server's saved rules) and watching
/// this server in the background (Notifications, whose switch the monitor
/// reads). A door shows the state it leads to, so nothing is set in two
/// places. A choice is said as chosen only once storage took it.
class AutomationSettingsScreen extends StatefulWidget {
  const AutomationSettingsScreen({
    super.key,
    required this.controller,
    this.teamAvailable,
  });

  final ConnectionController controller;

  /// Whether the AI Team is set up for this server; null reads the
  /// connection. Tests pass it to describe a team without a host.
  final bool? teamAvailable;

  @override
  State<AutomationSettingsScreen> createState() =>
      _AutomationSettingsScreenState();
}

class _AutomationSettingsScreenState extends State<AutomationSettingsScreen> {
  AutomationPolicyController? _policy;
  String? _profileId;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_connectionChanged);
    widget.controller.profileMonitor.addListener(_changed);
    _bind();
  }

  @override
  void didUpdateWidget(covariant AutomationSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_connectionChanged);
    oldWidget.controller.profileMonitor.removeListener(_changed);
    widget.controller.addListener(_connectionChanged);
    widget.controller.profileMonitor.addListener(_changed);
    _bind();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_connectionChanged);
    widget.controller.profileMonitor.removeListener(_changed);
    _policy?.removeListener(_changed);
    super.dispose();
  }

  /// Follows the current server: another server's page never keeps showing
  /// (or writing) the previous one's choices.
  void _bind() {
    final profileId = widget.controller.profile?.id;
    if (_policy != null && profileId == _profileId) return;
    _policy?.removeListener(_changed);
    _profileId = profileId;
    _saveFailed = false;
    _policy = profileId == null
        ? null
        : AutomationPolicyController.forProfile(
            widget.controller.store.prefs,
            profileId,
          );
    _policy?.addListener(_changed);
  }

  void _connectionChanged() {
    if (!mounted) return;
    setState(_bind);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Choosing a level is the consent the contract asks for; it is stored
  /// before the page says so, and a refused write is said on the page.
  Future<void> _choose(AutomationSupervision level) async {
    final policy = _policy;
    if (policy == null || _saving || policy.value.supervision == level) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await policy.setSupervision(level);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await pushKitPage<void>(context, (_) => screen);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final profile = controller.profile;
    final policy = _policy;
    final sections = AutomationSettingsSections.of(
      controller,
      team: widget.teamAvailable,
    );

    final Widget body;
    if (profile == null || policy == null || !sections.any) {
      body = KitStateView(
        key: const ValueKey('automation-empty'),
        icon: AppIconography.sync,
        title: l10n.automationEmptyTitle,
        body: l10n.automationEmptyBody,
      );
    } else {
      final name = serverDisplayName(
        profile,
        l10n,
        among: controller.store.profiles,
      );
      body = ListView(
        key: const ValueKey('automation-settings-list'),
        padding: EdgeInsetsDirectional.only(
          start: tokens.gutter,
          end: tokens.gutter,
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          KitText(
            l10n.automationIntro(name),
            key: const ValueKey('automation-intro'),
            role: KitTextRole.secondary,
          ),
          SizedBox(height: tokens.sectionGap),
          if (_saveFailed) ...[
            KitNotice(
              key: const ValueKey('automation-save-failed'),
              tone: AppStatusTone.failure,
              message: l10n.automationSaveFailed,
            ),
            SizedBox(height: tokens.sectionGap),
          ],
          if (sections.team) ...[
            _supervision(l10n, tokens, policy.value.supervision),
            SizedBox(height: tokens.sectionGap),
          ],
          if (sections.savedRules || sections.watch)
            KitRowGroup(
              key: const ValueKey('automation-elsewhere'),
              label: l10n.automationWithoutAskingLabel,
              margin: EdgeInsetsDirectional.zero,
              children: [
                if (sections.savedRules)
                  KitRow(
                    key: const ValueKey('automation-saved-permissions'),
                    leading: KitRow.icon(context, AppIconography.privacy),
                    title: l10n.e7LibraryAlwaysAllowedActions,
                    supporting: TextSpan(text: l10n.automationSavedRulesDetail),
                    supportingMaxLines: 2,
                    trailing: const KitChevron(),
                    onTap: () =>
                        _open(SavedPermissionsScreen(controller: controller)),
                  ),
                if (sections.watch) _watchRow(l10n, profile),
              ],
            ),
        ],
      );
    }
    return KitScreen(
      topBar: KitTopBar(title: l10n.automationTitle),
      width: KitScreenWidth.reading,
      loading: _saving,
      loadingLabel: l10n.automationSaving,
      body: body,
    );
  }

  /// The team's level: where new team tasks start. The start sheet still
  /// lets one task run at another level.
  Widget _supervision(
    AppLocalizations l10n,
    KitTokens tokens,
    AutomationSupervision selected,
  ) {
    return Column(
      key: const ValueKey('automation-team'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space1,
            end: tokens.space1,
            bottom: tokens.labelGap,
          ),
          child: Semantics(
            header: true,
            child: KitText(
              l10n.automationTeamLabel,
              role: KitTextRole.label,
              tone: KitTextTone.secondary,
            ),
          ),
        ),
        KitChoiceList<AutomationSupervision>.single(
          semanticsLabel: l10n.automationTeamLabel,
          choices: [
            for (final level in AutomationSupervision.values)
              KitChoice(
                key: ValueKey('automation-supervision-${level.name}'),
                value: level,
                title: _levelCopy(l10n, level.team).$1,
                supporting: _levelCopy(l10n, level.team).$2,
                enabled: !_saving,
                disabledReason: _saving ? l10n.automationSaving : null,
              ),
          ],
          selected: selected,
          onSelected: (level) => unawaited(_choose(level)),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space1,
            end: tokens.space1,
            top: tokens.labelGap,
          ),
          child: KitText(
            l10n.automationTeamFootnote,
            role: KitTextRole.secondary,
            tone: KitTextTone.secondary,
          ),
        ),
      ],
    );
  }

  (String, String) _levelCopy(AppLocalizations l10n, TeamSupervision level) =>
      teamSupervisionCopy(l10n, level);

  /// A door, not a second switch: the monitor reads the switch on
  /// Notifications, so this row says how it is set and opens it there.
  Widget _watchRow(AppLocalizations l10n, ServerProfile profile) {
    final controller = widget.controller;
    final watched = controller.profileMonitor.rulesFor(profile.id).enabled;
    return KitRow(
      key: const ValueKey('automation-watch'),
      leading: KitRow.icon(context, AppIconography.notificationImportant),
      title: l10n.automationWatchTitle,
      supporting: TextSpan(text: l10n.automationWatchDetail),
      supportingMaxLines: 2,
      trailing: KitRowValue(
        watched ? l10n.automationValueOn : l10n.automationValueOff,
      ),
      onTap: () => _open(
        NotificationsSettingsScreen(
          controller: controller,
          initialSection: 'servers',
        ),
      ),
    );
  }
}
