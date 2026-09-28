import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/termux_migration.dart';
import 'migration_archive_store.dart';
import 'termux_migration_transport.dart';

abstract class TermuxMigrationJournal {
  Future<Map<String, dynamic>?> read(String sourceProfileId);
  Future<void> write(String sourceProfileId, Map<String, dynamic> value);
}

/// The existing profile deletion sweep includes this source-scoped key.
class PreferencesTermuxMigrationJournal implements TermuxMigrationJournal {
  PreferencesTermuxMigrationJournal(this.preferences, {this.mayWrite});
  final bool Function(String)? mayWrite;
  final SharedPreferences preferences;
  static String key(String id) => 'oc.termuxMigration.$id';
  @override
  Future<Map<String, dynamic>?> read(String sourceProfileId) async {
    final raw = preferences.getString(key(sourceProfileId));
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String sourceProfileId, Map<String, dynamic> value) async {
    if (mayWrite?.call(sourceProfileId) == false) {
      throw const TermuxMigrationException(TermuxMigrationFailure.cancelled);
    }
    if (!await preferences.setString(key(sourceProfileId), jsonEncode(value))) {
      throw const TermuxMigrationException(TermuxMigrationFailure.storage);
    }
    // A deletion can begin while SharedPreferences is writing. Do not
    // recreate a scoped key after its sweep or admit any subsequent writes.
    if (mayWrite?.call(sourceProfileId) == false) {
      await preferences.remove(key(sourceProfileId));
      throw const TermuxMigrationException(TermuxMigrationFailure.cancelled);
    }
  }
}

typedef MigrationProfileSwitch =
    Future<String> Function({
      required String sourceProfileId,
      required bool Function() stillWanted,
      required Map<String, String> verifiedProjectPaths,
    });

/// One foreground migration owner. Keep it above routes; do not start from
/// build(). The journal survives process death; resume is an explicit action.
/// No error/callback data from either bridge is exposed in snapshots.
class TermuxMigrationController extends ChangeNotifier {
  TermuxMigrationController({
    required this.transport,
    required this.archives,
    required this.journal,
    required this.availableBytes,
    required this.switchProfile,
    required this.sourceProfileExists,
    String Function()? newJobId,
  }) : _newJobId = newJobId ?? _randomId;

  final TermuxMigrationTransport transport;
  final TermuxMigrationArchiveStore archives;
  final TermuxMigrationJournal journal;
  final Future<int?> Function() availableBytes;
  final MigrationProfileSwitch switchProfile;
  final bool Function(String) sourceProfileExists;
  final String Function() _newJobId;
  static const maxArchiveBytes = 512 * 1024 * 1024;
  static const reserveBytes = 64 * 1024 * 1024;
  static TermuxMigrationController? _active;
  static const attemptLimit = Duration(minutes: 15);
  Stopwatch? _attempt;
  bool get _expired => (_attempt?.elapsed ?? Duration.zero) >= attemptLimit;
  bool _cancelled = false;
  bool _disposed = false;
  bool _busy = false;
  String? _jobId;
  String? _sourceProfileId;
  TermuxMigrationSnapshot _snapshot = const TermuxMigrationSnapshot(
    phase: TermuxMigrationPhase.checking,
  );
  TermuxMigrationSnapshot get snapshot => _snapshot;
  bool get busy => _busy;
  bool get _wanted =>
      !_cancelled &&
      !_disposed &&
      !_expired &&
      (_sourceProfileId == null || sourceProfileExists(_sourceProfileId!));

  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _publish(
    TermuxMigrationPhase phase, {
    TermuxMigrationFailure? failure,
    TermuxMigrationItem? item,
    TermuxMigrationSource? source,
    int? requiredBytes,
    int? available,
    String? destination,
  }) {
    _snapshot = TermuxMigrationSnapshot(
      phase: phase,
      failure: failure,
      jobId: _jobId,
      item: item,
      source: source ?? _snapshot.source,
      requiredBytes: requiredBytes,
      availableBytes: available,
      destinationProfileId: destination,
    );
    if (!_disposed) notifyListeners();
  }

  void _checkCancelled() {
    if (_expired) {
      throw const TermuxMigrationException(TermuxMigrationFailure.timedOut);
    }
    if (!_wanted) {
      throw const TermuxMigrationException(TermuxMigrationFailure.cancelled);
    }
  }

  /// Fresh inventory; no archive, destination or profile is written here.
  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    _cancelled = false;
    try {
      await _preflight();
    } catch (e) {
      _failure(e);
    } finally {
      _busy = false;
    }
  }

  /// Restores the exact selection without exposing paths or archive content.
  Future<Set<TermuxMigrationItem>?> savedSelection(
    String sourceProfileId,
  ) async {
    try {
      final record = await journal.read(sourceProfileId);
      if (record == null) return null;
      final names = record['selected'];
      if (names is! List || names.isEmpty) {
        throw const TermuxMigrationException(TermuxMigrationFailure.storage);
      }
      return names
          .map((name) => TermuxMigrationItem.values.byName(name as String))
          .toSet();
    } catch (_) {
      throw const TermuxMigrationException(TermuxMigrationFailure.storage);
    }
  }

  Future<void> resume(String sourceProfileId) async {
    try {
      final selection = await savedSelection(sourceProfileId);
      if (selection == null) {
        throw const TermuxMigrationException(
          TermuxMigrationFailure.invalidSelection,
        );
      }
      await start(sourceProfileId: sourceProfileId, selected: selection);
    } catch (error) {
      _failure(error);
    }
  }

  Future<TermuxMigrationSource?> _preflight() async {
    _publish(TermuxMigrationPhase.checking);
    if (!await archives.builtinInstalled()) {
      _publish(TermuxMigrationPhase.needsBuiltin);
      return null;
    }
    _checkCancelled();
    final source = await transport.inspect();
    _validateSource(source);
    _checkCancelled();
    _publish(TermuxMigrationPhase.ready, source: source);
    return source;
  }

  void _validateSource(TermuxMigrationSource source) {
    final seen = <TermuxMigrationItem>{};
    if (source.freeBytes < 0 ||
        source.items.any(
          (x) =>
              x.bytes < 0 ||
              x.files < 0 ||
              x.files > 20000 ||
              !seen.add(x.item),
        )) {
      throw const TermuxMigrationException(TermuxMigrationFailure.tooLarge);
    }
  }

  /// Start or resume the same source/selection. A different selection cannot
  /// mutate a saved job. Pass explicit selection after showing private-export
  /// and re-sign-in warnings; only projects become active files.
  Future<void> start({
    required String sourceProfileId,
    required Set<TermuxMigrationItem> selected,
  }) async {
    if (_busy || (_active != null && _active != this)) return;
    _busy = true;
    _active = this;
    _cancelled = false;
    _attempt = Stopwatch()..start();
    Map<String, dynamic>? record;
    try {
      if (!sourceProfileExists(sourceProfileId) || selected.isEmpty) {
        throw const TermuxMigrationException(
          TermuxMigrationFailure.invalidSelection,
        );
      }
      _sourceProfileId = sourceProfileId;
      record = await journal.read(sourceProfileId);
      final names = selected.map((x) => x.name).toList()..sort();
      if (record != null) {
        if (record['schema'] != 1 ||
            jsonEncode(record['selected']) != jsonEncode(names) ||
            record['job'] is! String ||
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(record['job'] as String)) {
          throw const TermuxMigrationException(
            TermuxMigrationFailure.invalidSelection,
          );
        }
        _jobId = record['job'] as String;
      } else {
        _jobId = _newJobId();
        if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(_jobId!)) {
          throw const TermuxMigrationException(
            TermuxMigrationFailure.invalidSelection,
          );
        }
        record = {
          'schema': 1,
          'job': _jobId,
          'selected': names,
          'archives': <String, dynamic>{},
        };
      }
      // Completed jobs verify their receipt/files, but do not need Termux or
      // restart/reselect a server on an idempotent UI retry.
      if (record['done'] == true) {
        for (final item in selected) {
          final expected = _expected(record, item);
          if (expected == null ||
              !await archives.imported(_jobId!, item, expected)) {
            throw const TermuxMigrationException(
              TermuxMigrationFailure.destinationConflict,
            );
          }
        }
        _publish(
          TermuxMigrationPhase.done,
          destination: record['destination'] as String?,
        );
        return;
      }
      final source = await _preflight();
      if (source == null) return;
      final items = source.items
          .where((x) => selected.contains(x.item))
          .toList();
      if (items.length != selected.length) {
        throw const TermuxMigrationException(
          TermuxMigrationFailure.invalidSelection,
        );
      }
      for (final item in items) {
        if (item.problem != null) throw TermuxMigrationException(item.problem!);
      }
      // Conservative retained disk budget: payload plus allocation per entry
      // and tar end blocks; include each source/app archive and extracted copy.
      final total = items.fold<int>(
        0,
        (n, x) => n + x.bytes + x.files * 4096 + 10240,
      );
      if (items.any(
        (x) => x.bytes + x.files * 1024 + 10240 > maxArchiveBytes,
      )) {
        throw const TermuxMigrationException(TermuxMigrationFailure.tooLarge);
      }
      // Both private sandboxes can occupy the same partition: source archive,
      // app archive and extracted tree all coexist. Conservatively budget all
      // three against BOTH free readings, before any packing or importing.
      final needed = 3 * total + reserveBytes;
      final free = await availableBytes();
      if (free == null || free < needed || source.freeBytes < needed) {
        _publish(
          TermuxMigrationPhase.needsSpace,
          requiredBytes: needed,
          available: free == null ? null : min(free, source.freeBytes),
        );
        return;
      }
      await journal.write(sourceProfileId, record);
      for (final item in selected) {
        _checkCancelled();
        if (!sourceProfileExists(sourceProfileId)) {
          throw const TermuxMigrationException(
            TermuxMigrationFailure.invalidSelection,
          );
        }
        var expected = _expected(record, item);
        if (expected != null &&
            await archives.imported(_jobId!, item, expected)) {
          continue;
        }
        _publish(TermuxMigrationPhase.packing, item: item);
        final packed = await transport.pack(
          _jobId!,
          item,
          maxBytes: maxArchiveBytes,
        );
        if (packed.bytes <= 0 ||
            packed.bytes > maxArchiveBytes ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(packed.sha256)) {
          throw const TermuxMigrationException(
            TermuxMigrationFailure.invalidArchive,
          );
        }
        if (expected != null &&
            (expected.sha256 != packed.sha256 ||
                expected.bytes != packed.bytes)) {
          throw const TermuxMigrationException(
            TermuxMigrationFailure.sourceChanged,
          );
        }
        expected = packed;
        (record['archives'] as Map<String, dynamic>)[item.name] = {
          'bytes': expected.bytes,
          'sha256': expected.sha256,
        };
        await journal.write(sourceProfileId, record);
        _checkCancelled();
        final file = File(
          '${archives.jobDirectory(_jobId!).path}/${item.name}.tar',
        );
        _publish(TermuxMigrationPhase.copying, item: item);
        await transport.copy(
          _jobId!,
          item,
          expected,
          file,
          cancelled: () => !_wanted,
        );
        _checkCancelled();
        _publish(TermuxMigrationPhase.verifying, item: item);
        await archives.verify(file, expected);
        _checkCancelled();
        _publish(TermuxMigrationPhase.unpacking, item: item);
        await archives.importItem(
          _jobId!,
          item,
          file,
          expected,
          cancelled: () => !_wanted,
        );
        _publish(TermuxMigrationPhase.verifying, item: item);
        if (!await archives.imported(_jobId!, item, expected)) {
          throw const TermuxMigrationException(
            TermuxMigrationFailure.checksumMismatch,
          );
        }
        _checkCancelled();
      }
      _checkCancelled();
      _publish(TermuxMigrationPhase.switching);
      final destination = await switchProfile(
        sourceProfileId: sourceProfileId,
        stillWanted: () => _wanted && sourceProfileExists(sourceProfileId),
        verifiedProjectPaths: selected.contains(TermuxMigrationItem.projects)
            ? {'/root/projects': '/root/projects/termux-$_jobId'}
            : const {},
      );
      _checkCancelled();
      record['done'] = true;
      record['destination'] = destination;
      await journal.write(sourceProfileId, record);
      // Private source archive remains available for recovery. Never remove
      // Termux projects/config/history; any source cleanup is a separate job.
      await archives.cleanupPartial(_jobId!);
      _publish(TermuxMigrationPhase.done, destination: destination);
    } catch (e) {
      _failure(e);
    } finally {
      _busy = false;
      if (_active == this) _active = null;
      _attempt?.stop();
      _attempt = null;
      _sourceProfileId = null;
    }
  }

  TermuxMigrationArchive? _expected(
    Map<String, dynamic> record,
    TermuxMigrationItem item,
  ) {
    final values = record['archives'];
    if (values is! Map) {
      throw const TermuxMigrationException(TermuxMigrationFailure.storage);
    }
    final value = values[item.name];
    if (value == null) return null;
    if (value is! Map || value['bytes'] is! int || value['sha256'] is! String) {
      throw const TermuxMigrationException(TermuxMigrationFailure.storage);
    }
    return TermuxMigrationArchive(
      bytes: value['bytes'] as int,
      sha256: value['sha256'] as String,
    );
  }

  void _failure(Object error) {
    final code = _expired
        ? TermuxMigrationFailure.timedOut
        : !_wanted
        ? TermuxMigrationFailure.cancelled
        : error is TermuxMigrationException
        ? error.code
        : TermuxMigrationFailure.storage;
    _publish(
      code == TermuxMigrationFailure.cancelled
          ? TermuxMigrationPhase.cancelled
          : code == TermuxMigrationFailure.unavailable
          ? TermuxMigrationPhase.termuxUnreachable
          : TermuxMigrationPhase.failed,
      failure: code,
    );
  }

  /// Stops admission immediately; the current bounded source command may
  /// take up to its timeout to exit. Await start() before offering Resume.
  Future<void> cancel() async {
    _cancelled = true;
    _publish(
      TermuxMigrationPhase.cancelled,
      failure: TermuxMigrationFailure.cancelled,
    );
    final job = _jobId;
    if (job != null) {
      try {
        await transport.cancel(job);
      } catch (_) {
        /* fixed public state */
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    final job = _jobId;
    if (_busy && job != null) {
      unawaited(transport.cancel(job).catchError((Object _) {}));
    }
    super.dispose();
  }
}
