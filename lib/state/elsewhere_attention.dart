import 'package:flutter/foundation.dart';

import '../api/models.dart' show EventEnvelope;

/// What is going on in a project other than the selected one.
@immutable
class ProjectActivity {
  const ProjectActivity({
    required this.directory,
    required this.running,
    required this.waiting,
  });

  final String directory;

  /// Conversations with a run in progress.
  final Set<String> running;

  /// Conversations stopped on a person: a permission or a question.
  final Set<String> waiting;

  bool get isEmpty => running.isEmpty && waiting.isEmpty;
}

/// Keeps track of the server's *other* projects from its server-wide event
/// channel.
///
/// The app shows one project and wipes its approvals, questions and running
/// state on every switch, so an agent that stopped on a permission in a
/// project you are not looking at waited unseen. The server-wide channel
/// already carries every project's events, stamped with their folder; this
/// reads the few that say "running", "needs you" and "done" and keeps a small
/// tally per project. It holds ids and folders only: answering still happens
/// in the conversation, in its own project.
class ElsewhereAttention extends ChangeNotifier {
  final _runningIn = <String, Set<String>>{};
  // Request id -> (folder, conversation). A reply names the request only.
  final _waitingRequests = <String, ({String directory, String sessionID})>{};

  /// Every other project with something going on, busiest first.
  List<ProjectActivity> activity({String? except}) {
    final directories = {
      ..._runningIn.keys,
      for (final request in _waitingRequests.values) request.directory,
    }..remove(except);
    final result = [
      for (final directory in directories)
        ProjectActivity(
          directory: directory,
          running: Set.unmodifiable(_runningIn[directory] ?? const <String>{}),
          waiting: Set.unmodifiable({
            for (final request in _waitingRequests.values)
              if (request.directory == directory) request.sessionID,
          }),
        ),
    ].where((project) => !project.isEmpty).toList();
    result.sort((a, b) {
      final byWaiting = b.waiting.length.compareTo(a.waiting.length);
      return byWaiting != 0
          ? byWaiting
          : b.running.length.compareTo(a.running.length);
    });
    return result;
  }

  /// Conversations in other projects that are stopped on a person.
  int waitingCount({String? except}) => {
    for (final request in _waitingRequests.values)
      if (request.directory != except) request.sessionID,
  }.length;

  ProjectActivity? forProject(String directory) =>
      activity().where((p) => p.directory == directory).firstOrNull;

  /// Feeds one event from the server-wide channel. Every project is tallied,
  /// the selected one included: readers leave it out with `except`, and the
  /// tally is already right for it the moment you switch away.
  void handle(EventEnvelope event) {
    final directory = event.directory;
    if (directory == null || directory.isEmpty) return;
    final props = event.properties;
    final sessionID = props['sessionID']?.toString();
    var changed = false;
    switch (event.type) {
      case 'permission.asked' ||
          'permission.v2.asked' ||
          'permission.updated' ||
          'question.asked' ||
          'question.updated' ||
          'question.v2.asked':
        final id = (props['id'] ?? props['requestID'])?.toString();
        if (id != null && id.isNotEmpty && sessionID != null) {
          _waitingRequests[id] = (directory: directory, sessionID: sessionID);
          changed = true;
        }
      case 'permission.replied' ||
          'permission.v2.replied' ||
          'question.replied' ||
          'question.rejected' ||
          'question.v2.replied' ||
          'question.v2.rejected':
        final id = (props['requestID'] ?? props['permissionID'] ?? props['id'])
            ?.toString();
        changed = id != null && _waitingRequests.remove(id) != null;
      case 'session.status':
        if (sessionID == null) break;
        final raw = props['status'];
        final status = raw is Map ? raw['type']?.toString() : raw?.toString();
        changed = status == 'idle'
            ? _settle(directory, sessionID)
            : (_runningIn.putIfAbsent(directory, () => {})).add(sessionID);
      case 'session.idle' || 'session.error':
        if (sessionID != null) changed = _settle(directory, sessionID);
      case 'session.deleted':
        final id = (props['info'] is Map ? props['info']['id'] : sessionID)
            ?.toString();
        if (id != null) changed = _settle(directory, id);
    }
    if (changed) notifyListeners();
  }

  bool _settle(String directory, String sessionID) {
    var changed = _runningIn[directory]?.remove(sessionID) ?? false;
    if (_runningIn[directory]?.isEmpty ?? false) _runningIn.remove(directory);
    // A run that ended is no longer waiting on anything.
    final before = _waitingRequests.length;
    _waitingRequests.removeWhere(
      (_, request) => request.sessionID == sessionID,
    );
    changed = changed || before != _waitingRequests.length;
    return changed;
  }

  /// A new server, or a lost connection: what was known may be stale.
  void clear() {
    if (_runningIn.isEmpty && _waitingRequests.isEmpty) return;
    _runningIn.clear();
    _waitingRequests.clear();
    notifyListeners();
  }
}
