/// New conversation's chooser (map `new-conversation-sheet`, target-ia
/// "New (8)"; revamp unit slice-P4.5): the Work tab's one New conversation
/// button asks how to start, where the server supports more than one way.
///
/// - **Solo**: a conversation with the assistant, here.
/// - **Team**: a task for the AI Team; while the team is off on this server
///   the row says so and opens the team's off state (its intro) instead.
/// - **In a separate copy of (project)**: the isolated-task sheet, reached
///   only from here, which ends in the conversation in that copy.
/// - **On (cloud machine)**: one row per managed workspace of the project;
///   the conversation starts there.
///
/// The last choice is remembered per server (`oc.newConversationMode.`
/// plus the profile id, swept with the profile) and marked "Last used".
/// With only Solo possible the chooser is skipped (a choice of one is no
/// choice).
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit_bidi.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_sheet.dart';

/// The ways a conversation can start.
enum NewConversationKind { solo, team, separateCopy, cloud }

/// One way to start, as the chooser returns it and the memory stores it.
@immutable
class NewConversationChoice {
  const NewConversationChoice.solo()
    : kind = NewConversationKind.solo,
      workspaceId = null;
  const NewConversationChoice.team()
    : kind = NewConversationKind.team,
      workspaceId = null;
  const NewConversationChoice.separateCopy()
    : kind = NewConversationKind.separateCopy,
      workspaceId = null;
  const NewConversationChoice.cloud(String this.workspaceId)
    : kind = NewConversationKind.cloud;

  final NewConversationKind kind;

  /// The cloud machine (managed workspace) for [NewConversationKind.cloud].
  final String? workspaceId;

  /// The stored form: `solo`, `team`, `copy` or `cloud:<workspace id>`.
  /// `solo` and `team` are the values the earlier Solo · Team switch
  /// stored under the same key, so a remembered Team survives the update.
  String get stored => switch (kind) {
    NewConversationKind.solo => 'solo',
    NewConversationKind.team => 'team',
    NewConversationKind.separateCopy => 'copy',
    NewConversationKind.cloud => 'cloud:$workspaceId',
  };

  /// The choice [value] stores, or null when it is none of them.
  static NewConversationChoice? parse(String? value) {
    if (value == null) return null;
    if (value == 'solo') return const NewConversationChoice.solo();
    if (value == 'team') return const NewConversationChoice.team();
    if (value == 'copy') return const NewConversationChoice.separateCopy();
    if (value.startsWith('cloud:') && value.length > 'cloud:'.length) {
      return NewConversationChoice.cloud(value.substring('cloud:'.length));
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NewConversationChoice &&
      other.kind == kind &&
      other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(kind, workspaceId);

  @override
  String toString() => 'NewConversationChoice($stored)';
}

/// The last way this person started a conversation on a server.
abstract final class NewConversationMemory {
  /// Per profile, so the deletion sweep finds it.
  static String key(String profileId) => 'oc.newConversationMode.$profileId';

  static NewConversationChoice? read(
    SharedPreferences prefs,
    String profileId,
  ) => NewConversationChoice.parse(prefs.getString(key(profileId)));

  static Future<void> remember(
    SharedPreferences prefs,
    String profileId,
    NewConversationChoice choice,
  ) => prefs.setString(key(profileId), choice.stored);
}

/// A cloud machine the conversation can start on.
@immutable
class NewConversationCloud {
  const NewConversationCloud({
    required this.id,
    required this.name,
    this.status,
  });

  final String id;
  final String name;

  /// The machine's state as the server words it, when it sends one.
  final String? status;
}

/// What this server and project support, which decides the rows.
@immutable
class NewConversationOptions {
  const NewConversationOptions({
    this.project,
    this.team = false,
    this.teamOn = false,
    this.separateCopy = false,
    this.clouds = const [],
  });

  /// The project a Solo conversation starts in, and the one a separate
  /// copy is made of.
  final String? project;

  /// This server can run an AI Team (on or not).
  final bool team;

  /// The AI Team is on here; false with [team] opens its off state.
  final bool teamOn;

  /// This server can make a separate copy (a fresh worktree) of [project].
  final bool separateCopy;

  /// The project's cloud machines other than the one in use.
  final List<NewConversationCloud> clouds;

  /// Every choice these options offer, in the chooser's order.
  List<NewConversationChoice> get choices => [
    const NewConversationChoice.solo(),
    if (team) const NewConversationChoice.team(),
    if (separateCopy && project != null)
      const NewConversationChoice.separateCopy(),
    for (final cloud in clouds) NewConversationChoice.cloud(cloud.id),
  ];

  /// Solo is the only way: the button starts it without asking.
  bool get onlySolo => choices.length == 1;
}

/// Asks how to start. Returns the choice, or null when dismissed; the
/// caller remembers it and starts it. [remembered] is marked "Last used"
/// when it is still offered.
Future<NewConversationChoice?> showNewConversationSheet(
  BuildContext context, {
  required NewConversationOptions options,
  NewConversationChoice? remembered,
}) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return showKitSheet<NewConversationChoice>(
    context,
    title: l10n.workspaceNewSession,
    sheetKey: const ValueKey('new-conversation-sheet'),
    body: (sheetContext) => NewConversationChoices(
      options: options,
      remembered: remembered,
      onChosen: (choice) => Navigator.of(sheetContext).pop(choice),
    ),
  );
}

/// The chooser's rows: one per way this server supports, each naming what
/// it starts and where, the remembered one marked.
class NewConversationChoices extends StatelessWidget {
  const NewConversationChoices({
    super.key,
    required this.options,
    required this.onChosen,
    this.remembered,
  });

  final NewConversationOptions options;
  final NewConversationChoice? remembered;
  final ValueChanged<NewConversationChoice> onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final project = options.project == null
        ? null
        : KitBidi.auto(options.project!);
    final last = options.choices.contains(remembered) ? remembered : null;

    Widget row({
      required NewConversationChoice choice,
      required Key key,
      required IconData icon,
      required String title,
      required String detail,
    }) {
      final current = choice == last;
      return KitRow(
        key: key,
        leading: KitRowIcon(icon, current: current),
        title: title,
        titleMaxLines: 2,
        selected: current,
        supporting: TextSpan(
          children: [
            if (current) kitCurrentSpan(context, l10n.newConversationLastUsed),
            TextSpan(text: detail),
          ],
        ),
        supportingMaxLines: 2,
        trailing: const KitChevron(),
        onTap: () => onChosen(choice),
      );
    }

    return KitRowGroup(
      children: [
        row(
          choice: const NewConversationChoice.solo(),
          key: const ValueKey('new-conversation-solo'),
          icon: AppIconography.chat,
          title: l10n.teamNewModeSolo,
          detail: project == null
              ? l10n.newConversationSoloDetail
              : l10n.newConversationSoloDetailIn(project),
        ),
        if (options.team)
          row(
            choice: const NewConversationChoice.team(),
            key: const ValueKey('new-conversation-team'),
            icon: AppIconography.agent,
            title: l10n.teamNewModeTeam,
            detail: options.teamOn
                ? l10n.newConversationTeamDetail
                : l10n.newConversationTeamOffDetail,
          ),
        if (options.separateCopy && project != null)
          row(
            choice: const NewConversationChoice.separateCopy(),
            key: const ValueKey('new-conversation-copy'),
            icon: AppIconography.branch,
            title: l10n.newConversationCopyTitle(project),
            detail: l10n.workspaceIsolatedTaskRowDetail,
          ),
        for (final cloud in options.clouds)
          row(
            choice: NewConversationChoice.cloud(cloud.id),
            key: ValueKey('new-conversation-cloud-${cloud.id}'),
            icon: AppIconography.cloud,
            title: l10n.newConversationCloudTitle(KitBidi.auto(cloud.name)),
            detail: [
              l10n.newConversationCloudDetail,
              if (cloud.status case final status? when status.isNotEmpty)
                status,
            ].join(' · '),
          ),
      ],
    );
  }
}
