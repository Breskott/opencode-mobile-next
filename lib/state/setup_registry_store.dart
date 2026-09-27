import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/setup_registry.dart';
import '../ui/kit/kit_redact.dart';

enum SetupRegistryStatus { disabled, loading, ready, empty, offline, error }

class SetupRegistrySnapshot {
  SetupRegistrySnapshot({
    required this.status,
    required this.optedIn,
    List<RegistryEntry> entries = const [],
    this.cachedAt,
    this.reason,
  }) : entries = List.unmodifiable(entries);

  final SetupRegistryStatus status;
  final bool optedIn;
  final List<RegistryEntry> entries;
  final DateTime? cachedAt;
  final String? reason;
}

/// Phone-side browsing is disabled by default and never follows entry URLs.
/// Instantiate per profile. Dispose before deleting or changing the profile.
class SetupRegistryStore {
  SetupRegistryStore(
    this._prefs, {
    required this.profileId,
    SetupRegistryClient? client,
  }) : _client = client ?? SetupRegistryClient(),
       _ownsClient = client == null {
    if (profileId.isEmpty || KitRedact.containsSecret(profileId)) {
      throw ArgumentError('A non-secret profile identifier is required.');
    }
  }

  final SharedPreferences _prefs;
  final String profileId;
  final SetupRegistryClient _client;
  final bool _ownsClient;
  final _changes = StreamController<SetupRegistrySnapshot>.broadcast();
  int _generation = 0;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();
  CancelToken? _pending;
  SetupRegistrySnapshot _snapshot = SetupRegistrySnapshot(
    status: SetupRegistryStatus.disabled,
    optedIn: false,
  );

  String get storageKey => 'oc.setupRegistry.$profileId';
  SetupRegistrySnapshot get snapshot => _snapshot;
  Stream<SetupRegistrySnapshot> get changes => _changes.stream;

  /// Read cache only; never implies consent or causes a network request.
  Future<void> load() async {
    _ensureOpen();
    try {
      final raw = _prefs.getString(storageKey);
      if (raw == null || raw.length > SetupRegistryClient.maxResponseBytes) {
        return;
      }
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1) return;
      final optedIn = data['optedIn'] == true;
      final entries = <RegistryEntry>[
        if (data['entries'] is List)
          for (final entry in (data['entries'] as List).take(100))
            ?RegistryEntry.fromJson(entry),
      ];
      _emit(
        SetupRegistrySnapshot(
          status: !optedIn
              ? SetupRegistryStatus.disabled
              : entries.isEmpty
              ? SetupRegistryStatus.empty
              : SetupRegistryStatus.ready,
          optedIn: optedIn,
          entries: entries,
          cachedAt: data['cachedAt'] is String
              ? DateTime.tryParse(data['cachedAt'] as String)
              : null,
        ),
      );
    } catch (_) {
      _emit(
        SetupRegistrySnapshot(
          status: SetupRegistryStatus.error,
          optedIn: false,
          reason: 'The saved registry list could not be read. Set up by hand.',
        ),
      );
    }
  }

  /// Consent is profile scoped. Enabling does not fetch. Disabling cancels any
  /// request, retains the safe cached list, and prevents future refreshes.
  Future<void> setOptIn(bool enabled) async {
    _ensureOpen();
    final generation = ++_generation;
    _pending?.cancel();
    final next = SetupRegistrySnapshot(
      status: !enabled
          ? SetupRegistryStatus.disabled
          : snapshot.entries.isEmpty
          ? SetupRegistryStatus.empty
          : SetupRegistryStatus.ready,
      optedIn: enabled,
      entries: snapshot.entries,
      cachedAt: snapshot.cachedAt,
    );
    // Disable network immediately, even if saving the preference fails.
    _emit(next);
    try {
      await _persist(next, generation: generation);
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _emit(
          SetupRegistrySnapshot(
            status: SetupRegistryStatus.error,
            optedIn: false,
            entries: next.entries,
            cachedAt: next.cachedAt,
            reason: 'The registry preference could not be saved.',
          ),
        );
      }
      throw const SetupRegistryException(
        'The registry preference could not be saved.',
      );
    }
  }

  /// User-requested refresh only. Offline and opt-out paths are cache-only.
  Future<void> refresh({bool online = true}) async {
    _ensureOpen();
    if (!snapshot.optedIn) return;
    if (!online) {
      _generation++;
      _pending?.cancel();
      _emit(
        SetupRegistrySnapshot(
          status: SetupRegistryStatus.offline,
          optedIn: true,
          entries: snapshot.entries,
          cachedAt: snapshot.cachedAt,
          reason:
              'You are offline. Showing saved listings; set up by hand is available.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    _pending?.cancel();
    final pending = CancelToken();
    _pending = pending;
    _emit(
      SetupRegistrySnapshot(
        status: SetupRegistryStatus.loading,
        optedIn: true,
        entries: snapshot.entries,
        cachedAt: snapshot.cachedAt,
      ),
    );
    try {
      final entries = await _client.fetch(cancelToken: pending);
      if (_disposed ||
          generation != _generation ||
          !_prefs.containsKey(storageKey)) {
        return;
      }
      final next = SetupRegistrySnapshot(
        status: entries.isEmpty
            ? SetupRegistryStatus.empty
            : SetupRegistryStatus.ready,
        optedIn: true,
        entries: entries,
        cachedAt: DateTime.now().toUtc(),
      );
      await _persist(next, generation: generation, requireExisting: true);
      if (!_disposed && generation == _generation) _emit(next);
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _emit(
          SetupRegistrySnapshot(
            status: SetupRegistryStatus.error,
            optedIn: snapshot.optedIn,
            entries: snapshot.entries,
            cachedAt: snapshot.cachedAt,
            reason:
                'The public registry could not be loaded. Showing saved listings.',
          ),
        );
      }
    }
  }

  /// Remove both the opt-in preference and cache without affecting profiles.
  Future<void> clear() async {
    _ensureOpen();
    _generation++;
    _pending?.cancel();
    _emit(
      SetupRegistrySnapshot(
        status: SetupRegistryStatus.disabled,
        optedIn: false,
      ),
    );
    try {
      await _enqueueWrite(() async {
        if (!await _prefs.remove(storageKey)) throw const FormatException();
      });
    } catch (_) {
      throw const SetupRegistryException(
        'The saved registry list could not be removed.',
      );
    }
  }

  Future<void> _persist(
    SetupRegistrySnapshot value, {
    required int generation,
    bool requireExisting = false,
  }) async {
    final encoded = KitRedact.text(
      jsonEncode({
        'version': 1,
        'optedIn': value.optedIn,
        'cachedAt': value.cachedAt?.toUtc().toIso8601String(),
        'entries': value.entries.map((entry) => entry.toJson()).toList(),
      }),
    );
    try {
      await _enqueueWrite(() async {
        if (_disposed ||
            generation != _generation ||
            (requireExisting && !_prefs.containsKey(storageKey))) {
          return;
        }
        if (!await _prefs.setString(storageKey, encoded)) {
          throw const FormatException();
        }
      });
    } catch (_) {
      throw const SetupRegistryException(
        'The registry preference could not be saved.',
      );
    }
  }

  Future<void> _enqueueWrite(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  void _emit(SetupRegistrySnapshot value) {
    _snapshot = value;
    if (!_disposed) _changes.add(value);
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('The registry store is closed.');
  }

  /// Await before profile deletion: already-started preference writes drain
  /// before this completes; queued stale writes and network responses are ignored.
  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _pending?.cancel();
    if (_ownsClient) _client.dispose();
    await _writes;
    await _changes.close();
  }
}
