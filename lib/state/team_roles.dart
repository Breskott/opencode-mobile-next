/// AI Team roles (personas): named instruction sets a task is given to —
/// Product, Frontend, Backend, Tester, or the person's own. On the phone
/// one worker runs at a time and "puts on" the task's role: the role's
/// instructions travel in the task's description and its model (if any)
/// is applied just before the task is handed over. No extra processes.
///
/// CONTRACT (frozen 2026-09-29 for the roles slices): names, fields and
/// signatures below are shared by the state slice (which implements the
/// bodies) and the UI slice (which only calls them). Do not rename.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orchestration.dart';

/// Ids of the roles every team starts with. Their display names and
/// one-line purposes are UI copy (l10n, keyed by id); their [TeamRole
/// .instructions] are English prompt text sent to the model.
abstract final class TeamRoleIds {
  static const general = 'general';
  static const product = 'product';
  static const frontend = 'frontend';
  static const backend = 'backend';
  static const tester = 'tester';

  static const builtIn = [general, product, frontend, backend, tester];
}

@immutable
class TeamRole {
  const TeamRole({
    required this.id,
    required this.name,
    required this.purpose,
    required this.instructions,
    this.model,
    this.builtIn = false,
  });

  /// Stable id: a [TeamRoleIds] value, or `custom-<random>` for the
  /// person's own roles.
  final String id;

  /// Shown name. For a built-in role the stored name is empty until the
  /// person renames it; the UI then shows the l10n name for [id].
  final String name;

  /// One line: what this role is for. Shown under the name and used as the
  /// hint when the app suggests a role for a task. Empty for an unedited
  /// built-in (UI shows the l10n purpose).
  final String purpose;

  /// Prompt text put in front of the task for the worker. Empty for
  /// [TeamRoleIds.general] (the task goes as written).
  final String instructions;

  /// `provider/model` (see `isValidTeamModel`), or null: the team's model.
  final String? model;

  final bool builtIn;

  TeamRole copyWith({
    String? name,
    String? purpose,
    String? instructions,
    String? Function()? model,
  }) => TeamRole(
    id: id,
    name: name ?? this.name,
    purpose: purpose ?? this.purpose,
    instructions: instructions ?? this.instructions,
    model: model == null ? this.model : model(),
    builtIn: builtIn,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'purpose': purpose,
    'instructions': instructions,
    if (model != null) 'model': model,
    'builtIn': builtIn,
  };

  static TeamRole? fromJson(Object? json) =>
      throw UnimplementedError('state slice');
}

/// The roles of one profile's team and which role each task was given.
///
/// Storage (swept with the profile by the scoped-key deletion):
/// - `oc.teamRoles.<profileId>`: JSON list of [TeamRole] (built-ins stored
///   only once edited; missing built-ins come from [TeamRoles.defaults]).
/// - `oc.teamTaskRoles.<profileId>`: JSON map work/run id -> role id.
class TeamRolesController extends ChangeNotifier {
  TeamRolesController(this.prefs, this.profileId);

  final SharedPreferences prefs;
  final String profileId;

  static String rolesKey(String profileId) => 'oc.teamRoles.$profileId';
  static String taskRolesKey(String profileId) => 'oc.teamTaskRoles.$profileId';

  /// Built-ins first in [TeamRoleIds.builtIn] order, then the person's own
  /// in creation order.
  List<TeamRole> get roles => throw UnimplementedError('state slice');

  TeamRole? byId(String id) => throw UnimplementedError('state slice');

  /// Adds a role of the person's own; returns it with its new id.
  Future<TeamRole> add({
    required String name,
    required String purpose,
    required String instructions,
    String? model,
  }) => throw UnimplementedError('state slice');

  /// Saves an edited role (built-in or own).
  Future<void> update(TeamRole role) => throw UnimplementedError('state slice');

  /// Removes one of the person's own roles; built-ins cannot be removed.
  /// Tasks that had it keep showing its last name.
  Future<void> remove(String roleId) => throw UnimplementedError('state slice');

  /// Puts a built-in role back to how it shipped.
  Future<void> reset(String roleId) => throw UnimplementedError('state slice');

  /// The role the app suggests for a task, from its words (no network, no
  /// model call): matched against each role's name and purpose plus a
  /// small built-in vocabulary per built-in role. [TeamRoleIds.general]
  /// when nothing stands out.
  String suggest(String taskText) => throw UnimplementedError('state slice');

  /// The role a task was given, or null (tasks from before roles, or
  /// given elsewhere).
  String? roleOfTask(String workOrRunId) =>
      throw UnimplementedError('state slice');

  /// Remembers [roleId] for [workOrRunId].
  Future<void> rememberTaskRole(String workOrRunId, String roleId) =>
      throw UnimplementedError('state slice');
}

/// The description the worker receives: the role's instructions, then the
/// person's own description. Plain text; returns [description] unchanged
/// for a role without instructions.
String describeTaskForRole(TeamRole role, String? description) =>
    throw UnimplementedError('state slice');

/// Gives a task to the team as [role]: applies the role's model (or the
/// team's model when the role has none) through [applyModel] before the
/// hand-over — the in-app team's `BuiltinTeam.applyModel`; null for a
/// team on a computer, whose model the host decides — then
/// [OrchestrationController.giveTask] with [describeTaskForRole], then
/// remembers the role for the created work id. Never throws past what
/// giveTask throws.
Future<({MutationRecord created, MutationRecord? assigned})> giveTaskAsRole({
  required OrchestrationController team,
  required TeamRolesController roles,
  required TeamRole role,
  required String title,
  String? description,
  required String projectId,
  required String agentId,
  String? teamModel,
  Future<void> Function(String? model)? applyModel,
  ValueChanged<MutationRecord>? onCreated,
}) => throw UnimplementedError('state slice');
