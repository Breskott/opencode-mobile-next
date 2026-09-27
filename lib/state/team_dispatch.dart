import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/orchestration_gateway.dart';
import 'orchestration.dart';

/// Local submission state, distinct from evidence that a worker started.
enum TeamDispatchPhase {
  idle,
  unavailable,
  invalidInput,
  submitting,
  rejected,
  unconfirmed,
  awaitingWorker,
  workerObserved,
}

/// One user-triggered task attempt. Listen for receipt and snapshot changes.
///
/// Create one instance per task composer and dispose it before its source.
/// [submit] invokes the existing create-then-assign path exactly once; later
/// taps return the same future, even after an uncertain result. A new instance
/// is required for a deliberately new task. Nothing retries, resumes a pool,
/// adds a timer, or persists additional state. Host mutation records remain
/// the restart/deletion source of truth. This is not a dispatch latency SLA.
class TeamDispatchController extends ChangeNotifier {
  TeamDispatchController(this._source) {
    _source.addListener(_changed);
  }

  final OrchestrationController _source;
  Future<void>? _submission;
  bool _disposed = false;
  TeamDispatchPhase _phase = TeamDispatchPhase.idle;
  MutationRecord? _created;
  MutationRecord? _assigned;

  /// Both capabilities are required BEFORE creating any task.
  bool get canSubmit =>
      !_disposed &&
      _submission == null &&
      _source.phase == OrchestrationPhase.ready &&
      !_source.isStale &&
      _source.capabilities.controlCreateWork &&
      _source.capabilities.controlAssign;

  MutationRecord? get _currentCreated =>
      _created == null ? null : _source.mutation(_created!.key) ?? _created;
  MutationRecord? get _currentAssigned =>
      _assigned == null ? null : _source.mutation(_assigned!.key) ?? _assigned;

  String? get workId => _currentCreated?.receipt?.createdId;
  String? get createMutationKey => _created?.key;
  String? get assignMutationKey => _assigned?.key;
  MutationStatus? get createStatus => _currentCreated?.status;
  MutationStatus? get assignStatus => _currentAssigned?.status;
  MutationReceiptStatus? get assignmentReceipt =>
      _currentAssigned?.receipt?.status;

  /// Current snapshot evidence only: a named, explicitly running session
  /// attached to this exact task. An unrelated member of the same pool and
  /// an agent's generic working state are insufficient. Null is unknown,
  /// including after disconnect; it does not prove a worker never started.
  String? get workerSessionId {
    final id = workId;
    if (id == null ||
        _source.phase != OrchestrationPhase.ready ||
        _source.isStale ||
        _source.lastError != null) {
      return null;
    }
    for (final agent in _source.snapshot.agents) {
      final session = agent.sessionId;
      if (agent.currentWorkId == id &&
          agent.sessionRunning == true &&
          session != null &&
          session.isNotEmpty) {
        return session;
      }
    }
    return null;
  }

  TeamDispatchPhase get phase {
    if (_created == null) return _phase;
    if (workerSessionId != null) return TeamDispatchPhase.workerObserved;
    if (createStatus == MutationStatus.rejected ||
        assignStatus == MutationStatus.rejected) {
      return TeamDispatchPhase.rejected;
    }
    if (workId == null ||
        _assigned == null ||
        createStatus == MutationStatus.unconfirmed ||
        assignStatus == MutationStatus.unconfirmed) {
      return TeamDispatchPhase.unconfirmed;
    }
    return TeamDispatchPhase.awaitingWorker;
  }

  /// Explicit user action only. Unsupported/empty input sends nothing and
  /// remains editable. Task content is sent unchanged; the existing store
  /// redacts persisted records. A restart retry uses that redacted record.
  ///
  /// Raw transport errors/receipts are never surfaced here. An unexpected
  /// failure leaves [phase] unconfirmed: check host state before trying again.
  Future<void> submit({
    required String title,
    String? description,
    required String projectId,
    required String agentId,
  }) {
    if (_disposed) return Future<void>.value();
    final existing = _submission;
    if (existing != null) return existing;
    if (!canSubmit) {
      _phase = TeamDispatchPhase.unavailable;
      notifyListeners();
      return Future<void>.value();
    }
    if (title.trim().isEmpty ||
        projectId.trim().isEmpty ||
        agentId.trim().isEmpty) {
      _phase = TeamDispatchPhase.invalidInput;
      notifyListeners();
      return Future<void>.value();
    }
    final done = Completer<void>();
    _submission = done.future;
    _phase = TeamDispatchPhase.submitting;
    notifyListeners();
    unawaited(() async {
      try {
        final result = await _source.giveTask(
          title: title,
          description: description,
          projectId: projectId,
          agentId: agentId,
        );
        if (!_disposed) {
          _created = result.created;
          _assigned = result.assigned;
        }
      } catch (_) {
        if (!_disposed) _phase = TeamDispatchPhase.unconfirmed;
      } finally {
        if (!_disposed) notifyListeners();
        done.complete();
      }
    }());
    return done.future;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _source.removeListener(_changed);
    super.dispose();
  }
}
