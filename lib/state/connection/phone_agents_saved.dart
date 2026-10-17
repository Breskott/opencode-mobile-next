part of '../connection.dart';

// The agents' saved rows: what the list shows before a folder is read live.
extension _PhoneAgentSavedRows on _ConnectionControllerPhoneAgents {
  /// This profile's saved rows, read from the cache once per owner.
  List<({ChatFeedItem item, bool canReopen})> get _paSavedRows {
    final id = _paProfile?.id;
    if (id == null || !phoneAgentsAvailable) return const [];
    if (_paCacheOwner != id) {
      _paCacheOwner = id;
      _paCacheRows = _paCache.read(id);
    }
    return _paCacheRows ?? const [];
  }

  /// The saved row for [item] while its folder has not been read live yet.
  ({ChatFeedItem item, bool canReopen})? _paSavedRowFor(ChatFeedItem item) {
    if (_paLoadedDirs.contains(item.directory)) return null;
    for (final row in _paSavedRows) {
      if (row.item.identity == item.identity) return row;
    }
    return null;
  }

  /// Folders read live replace their saved rows; the rest are kept.
  void _paSaveRows(MergedChatFeed merged) {
    final id = _paProfile?.id;
    if (id == null) return;
    final checks = merged.sourceChecks;
    for (final entry in _paSources.keys) {
      final check = checks[_paseoSourceId(entry)];
      if (check != null && (check.complete || check.items.isNotEmpty)) {
        _paLoadedDirs.add(entry);
      }
    }
    final live = merged
        .chatFeed(const ChatFeedFilter(includeSubagents: true))
        .items
        .where(
          (item) =>
              item.sourceId != _openCodeSourceId &&
              _paLoadedDirs.contains(item.directory),
        )
        .map(
          (item) => (
            item: _paPersistableRow(item),
            canReopen: agentResumeNotice(item).canReopen,
          ),
        )
        .toList();
    final rows = [
      ...live,
      for (final row in _paSavedRows)
        if (!_paLoadedDirs.contains(row.item.directory)) row,
    ]..sort((a, b) => compareChatFeedItems(a.item, b.item));
    _paCacheRows = List.unmodifiable(rows);
    _paCacheOwner = id;
    unawaited(_paCache.write(id, rows));
  }

  /// Saved rows outlive the gateway's draft aliases: persist the daemon's ids.
  ChatFeedItem _paPersistableRow(ChatFeedItem item) {
    final gateway = _paSources[item.directory]?.gateway;
    if (gateway == null || item.sourceId != _paseoSourceId(item.directory)) {
      return item;
    }
    final id = gateway.daemonSessionId(item.sessionID);
    final parent = item.parentID == null
        ? null
        : gateway.daemonSessionId(item.parentID!);
    if (id == item.sessionID && parent == item.parentID) return item;
    return ChatFeedItem(
      sessionID: id,
      title: item.title,
      directory: item.directory,
      projectName: item.projectName,
      isGit: item.isGit,
      status: item.status,
      lastActivity: item.lastActivity,
      preview: item.preview,
      parentID: parent,
      agentId: item.agentId,
      agentLabel: item.agentLabel,
      sourceId: item.sourceId,
      sourceLabel: item.sourceLabel,
      finishedUnseen: item.finishedUnseen,
      contextUsage: item.contextUsage,
    );
  }
}
