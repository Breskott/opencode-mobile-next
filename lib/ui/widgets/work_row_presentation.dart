/// How a row shows a [WorkRowStatus] (slice-P5.5): one mark and one state
/// line for Work and Inbox rows, from the same source as the header word
/// and notification copy. A row that is not fresh never gets a live mark:
/// a disconnected "Working" rests still and says when it was last seen.
library;

import 'package:flutter/material.dart';

import '../../domain/work_row_status.dart';
import '../../l10n/app_localizations.dart';
import '../kit/kit_task_mark.dart';
import '../kit/kit_text.dart';

/// The leading mark for [status]. Waiting-like phases (and a stalled task,
/// which is not moving) share the still waiting ring.
KitTaskState workRowTaskState(WorkRowStatus status) =>
    switch (status.facts.phase) {
      WorkRowPhase.needsYou => KitTaskState.needsYou,
      WorkRowPhase.working =>
        status.showLiveMark ? KitTaskState.working : KitTaskState.waiting,
      WorkRowPhase.done => KitTaskState.done,
      WorkRowPhase.failed => KitTaskState.failed,
      WorkRowPhase.stopped => KitTaskState.stopped,
      WorkRowPhase.stalled ||
      WorkRowPhase.waiting ||
      WorkRowPhase.queued ||
      WorkRowPhase.ready ||
      WorkRowPhase.review ||
      WorkRowPhase.unknown => KitTaskState.waiting,
    };

/// The state words at label weight, the start of a row's supporting line
/// (STATE-9): "Working", "Failed", "Needs you · as of 28/09 14:02". A live
/// request is the kit's needs-you row, with its attention tone; a line
/// read from here is a state, in the primary tone.
TextSpan workRowStatusSpan(
  BuildContext context,
  AppLocalizations l10n,
  WorkRowStatus status, {
  required DateTime now,
}) => TextSpan(
  text: status.line(l10n, now: now),
  style: KitText.styleOf(context, KitTextRole.label, tone: KitTextTone.primary),
);
