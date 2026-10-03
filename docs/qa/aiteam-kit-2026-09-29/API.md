# AI Team kit API

Finish line: callers can render and operate the project, plan, phase, findings,
merge, promotion, digest, timeline, server and spec surfaces using localized
presentation data in an adaptive, accessible kit.
Non-goal: engine behavior, screen routing or persistence.

Import `ui/kit/kit.dart`. No domain model imports are required by these parts.

- `KitTeamState {empty, loading, running, needsYou, stalled, failed, done, stale}`.
- `KitTeamItem({required title, detail, meta, state = done, onPressed})`.
- `KitPlanCard`, `KitPhaseCard`, `KitMergeQueue`, `KitPromoteCard`, `KitDigest`,
  `KitTimelineDay`, `KitServerLane`: `({key, required String title, required String
  status, KitTeamState state = done, String? summary, List<KitTeamItem> items =
  const [], KitAction? primary, List<KitAction> actions = const []})`.
- `KitProjectRow`, `KitMilestoneRow`: `({key, required String title, required
  String status, KitTeamState state = done, String? detail, String? meta,
  VoidCallback? onPressed, int? completed, int? total})`. Progress is rendered
  only for a valid pair of actual step counts, never estimated from state.
- `KitFindingSeverity {critical, major, minor}`.
- `KitTeamFinding({required String id, required String title, required String
  severityLabel, severity = minor, String? detail, String? location,
  bool selected = false, ValueChanged<bool>? onChanged})`.
- `KitFindingsCard`: common card arguments with `findings` instead of `items`.
- `KitSpecBlock({key, required String label, required TextEditingController
  controller, String? helper, ValueChanged<String>? onChanged, bool readOnly =
  false})`.

Every string comes from caller localization or user data. Status must explain
empty/loading/failure/stall/wait/stale state, including last-known age. Actions
are controlled: callbacks mutate caller state. `KitAction.disabledReason` explains
unavailable actions. Stale and loading cards suppress mutation actions. Promotion
callbacks must open the app's explicit confirmation; the kit never promotes.

Cards apply only inner padding; rows apply vertical spacing and no side padding.
The host applies its page gutter exactly once. Children are flat, without nested
cards. Both wide and narrow layouts wrap metadata and actions. No ambient motion.

`KitTimelineDay` folds after ten events; optional `moreLabel` labels its existing
kit disclosure control (defaults to the localized Show all).
