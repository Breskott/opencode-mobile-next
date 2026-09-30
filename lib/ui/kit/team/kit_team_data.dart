import 'package:flutter/material.dart';

/// Presentation state; the caller supplies localized explanation and age.
enum KitTeamState {
  empty,
  loading,
  running,
  needsYou,
  stalled,
  failed,
  done,
  stale,
}

@immutable
class KitTeamItem {
  const KitTeamItem({
    required this.title,
    this.detail,
    this.meta,
    this.state = KitTeamState.done,
    this.onPressed,
  });
  final String title;
  final String? detail;
  final String? meta;
  final KitTeamState state;
  final VoidCallback? onPressed;
}

enum KitFindingSeverity { critical, major, minor }

@immutable
class KitTeamFinding {
  const KitTeamFinding({
    required this.id,
    required this.title,
    required this.severityLabel,
    this.severity = KitFindingSeverity.minor,
    this.detail,
    this.location,
    this.selected = false,
    this.onChanged,
  });
  final String id;
  final String title;
  final String severityLabel;
  final KitFindingSeverity severity;
  final String? detail;
  final String? location;
  final bool selected;
  final ValueChanged<bool>? onChanged;
}
