/// Usage snapshot for the host: counts and spend as far as the provider
/// reports them. Every figure is optional; absent means "not reported".
class OrchestrationUsage {
  const OrchestrationUsage({
    this.capturedAt,
    this.activeAgents,
    this.runsInProgress,
    this.workOpen,
    this.workReady,
    this.workInProgress,
    this.inputTokens,
    this.outputTokens,
    this.costUsd,
    this.raw = const {},
  });

  final DateTime? capturedAt;
  final int? activeAgents;
  final int? runsInProgress;

  /// Gas City `/status` `work.open`.
  final int? workOpen;

  /// Gas City `/status` `work.ready`.
  final int? workReady;

  /// Gas City `/status` `work.in_progress`.
  final int? workInProgress;
  final int? inputTokens;
  final int? outputTokens;
  final double? costUsd;

  /// Untouched provider payload.
  final Map<String, Object?> raw;

  /// True when no figure at all was reported.
  bool get isEmpty =>
      activeAgents == null &&
      runsInProgress == null &&
      workOpen == null &&
      workReady == null &&
      workInProgress == null &&
      inputTokens == null &&
      outputTokens == null &&
      costUsd == null;

  @override
  String toString() =>
      'OrchestrationUsage(open: $workOpen, ready: $workReady, '
      'inProgress: $workInProgress)';
}
