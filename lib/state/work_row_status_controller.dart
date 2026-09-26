import 'package:flutter/foundation.dart';

import '../domain/work_row_status.dart';

export '../domain/work_row_status.dart';

/// In-memory status source for ONE profile/location. The integration owner
/// creates/disposes it with that scope; [clear] also handles profile deletion.
/// It does not subscribe to a transport or poll. Feed confirmed gateway reads
/// and events through [observe], never cached state from a rebuild.
class WorkRowStatusController extends ChangeNotifier {
  bool _connected = false;
  int _generation = 0;
  final Map<String, ({WorkRowFacts facts, DateTime at, int generation})> _rows =
      {};

  /// Capture before a gateway request. Old in-flight replies cannot revive a
  /// disconnected row, even if they arrive after reconnection or [clear].
  int get generation => _generation;

  void setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    _generation++;
    notifyListeners();
  }

  /// Returns false for disconnected, old-generation or out-of-order evidence.
  /// [observedAt] is the time of the successful read/event, not the UI rebuild.
  bool observe(
    String key,
    WorkRowFacts facts, {
    required DateTime observedAt,
    required int generation,
  }) {
    if (!_connected || generation != _generation) return false;
    final old = _rows[key];
    if (old != null && observedAt.isBefore(old.at)) return false;
    _rows[key] = (facts: facts, at: observedAt, generation: generation);
    notifyListeners();
    return true;
  }

  WorkRowStatus? statusFor(String key) {
    final row = _rows[key];
    if (row == null) return null;
    return WorkRowStatus(
      facts: row.facts,
      observedAt: row.at,
      isFresh: _connected && row.generation == _generation,
    );
  }

  void remove(String key) {
    if (_rows.remove(key) != null) notifyListeners();
  }

  /// Clears all references and invalidates in-flight reads. Reconnect explicitly
  /// before accepting observations in the new profile/location scope.
  void clear() {
    _rows.clear();
    _connected = false;
    _generation++;
    notifyListeners();
  }
}
