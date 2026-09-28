import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/termux_migration_service.dart';
import 'connection.dart';
import 'profiles.dart';

/// What the owner last asked the migration to do, so "Try again" repeats it.
enum TermuxMigrationRequest { check, start, resume }

/// The one owner of the Termux migration, above every route (the backend's
/// hook-up contract, docs/qa/codex-termux-migration-2026-09-28/README.md):
/// it creates the controller once, runs one operation at a time, and stops
/// the copy when the app leaves the foreground, because Android gives the
/// copy no background lifetime. The page, This phone's row and the Servers
/// offer only read it and ask it to act.
///
/// It keeps three facts of its own, each scoped to the source profile so the
/// profile deletion sweep removes them (`oc.<what>.<profileId>`):
/// - `oc.termuxMigrationDone.<id>`: the job id of a move that finished and
///   was verified, so This phone says "Moved" and the page shows where the
///   files went instead of offering Resume (files the person edited since
///   are theirs: the receipts are not checked again on every visit);
/// - `oc.termuxMigrationProviders.<id>`: the names (never keys) of the AI
///   providers the Termux server was signed in to, for "Sign in again".
class TermuxMigrationOwner extends ChangeNotifier with WidgetsBindingObserver {
  TermuxMigrationOwner({this.create});

  /// The app's owner. Tests put their own here, as they do with
  /// `PhoneSetup.engine`.
  static TermuxMigrationOwner instance = TermuxMigrationOwner();

  /// Makes the controller; null uses [TermuxMigrationService.create].
  final Future<TermuxMigrationController> Function(
    ConnectionController connection,
    String builtinProfileName,
  )?
  create;

  static String doneKey(String profileId) =>
      'oc.termuxMigrationDone.$profileId';
  static String providersKey(String profileId) =>
      'oc.termuxMigrationProviders.$profileId';

  TermuxMigrationController? _controller;
  Future<TermuxMigrationController?>? _creating;
  Future<void>? _inFlight;
  bool _observing = false;
  bool _disposed = false;

  /// The source profile the last operation ran for.
  String? source;

  /// The last operation asked for.
  TermuxMigrationRequest? request;

  /// The items of the running or last copy, in the order the controller
  /// copies them (by name, the order its saved selection comes back in).
  List<TermuxMigrationItem> items = const [];

  /// The copy stopped because the app left the foreground.
  bool stoppedByLeaving = false;

  TermuxMigrationController? get controller => _controller;
  TermuxMigrationSnapshot? get snapshot => _controller?.snapshot;

  /// An operation is running (true until it has settled, even after Stop).
  bool get busy => _inFlight != null;

  /// A copy (not only a check) is running.
  bool get copying => busy && request != TermuxMigrationRequest.check;

  /// The controller, made once; null when this phone cannot make one (its
  /// private storage could not be read). A later call tries again.
  Future<TermuxMigrationController?> obtain(
    ConnectionController connection,
    String builtinProfileName,
  ) {
    final made = _controller;
    if (made != null) return Future.value(made);
    return _creating ??= () async {
      try {
        final made = await (create != null
            ? create!(connection, builtinProfileName)
            : TermuxMigrationService.create(
                connection: connection,
                builtinProfileName: builtinProfileName,
              ));
        if (_disposed) {
          made.dispose();
          return null;
        }
        _controller = made..addListener(_changed);
        if (!_observing) {
          WidgetsBinding.instance.addObserver(this);
          _observing = true;
        }
        return made;
      } catch (_) {
        return null;
      } finally {
        _creating = null;
      }
    }();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Items in the controller's own order.
  static List<TermuxMigrationItem> ordered(Iterable<TermuxMigrationItem> it) =>
      it.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> _run(
    String sourceId,
    TermuxMigrationRequest what,
    Future<void> Function(TermuxMigrationController c) op, {
    ProfileStore? store,
  }) {
    final c = _controller;
    if (c == null) return Future.value();
    final running = _inFlight;
    if (running != null) return running;
    source = sourceId;
    request = what;
    if (what != TermuxMigrationRequest.check) stoppedByLeaving = false;
    final done = () async {
      try {
        await op(c);
      } catch (_) {
        // The controller publishes every failure as a fixed state.
      }
      final job = c.snapshot.jobId;
      if (store != null &&
          job != null &&
          c.snapshot.phase == TermuxMigrationPhase.done) {
        await _remember(store, sourceId, job);
      }
    }();
    final settled = done.whenComplete(() {
      _inFlight = null;
      _changed();
    });
    _inFlight = settled;
    _changed();
    return settled;
  }

  /// A fresh look at Termux and the phone: sizes, space, the in-app server.
  Future<void> check(String sourceId) =>
      _run(sourceId, TermuxMigrationRequest.check, (c) => c.check());

  /// Starts copying [selected] from [sourceId]. [providerNames] are the AI
  /// providers the Termux server is signed in to (names only), kept for
  /// the "sign in again" step.
  Future<void> start(
    ConnectionController connection,
    String sourceId,
    Set<TermuxMigrationItem> selected, {
    List<String> providerNames = const [],
  }) {
    items = ordered(selected);
    if (providerNames.isNotEmpty && connection.isProfileReadable(sourceId)) {
      unawaited(
        connection.store.prefs
            .setStringList(providersKey(sourceId), providerNames)
            .then((_) {}, onError: (Object _) {}),
      );
    }
    return _run(
      sourceId,
      TermuxMigrationRequest.start,
      (c) => c.start(sourceProfileId: sourceId, selected: items.toSet()),
      store: connection.store,
    );
  }

  /// Resumes the saved copy of [sourceId] with its saved selection. With
  /// nothing saved (the copy stopped before it began), starts [fallback]
  /// again instead.
  Future<void> resume(
    ConnectionController connection,
    String sourceId, {
    Set<TermuxMigrationItem> fallback = const {},
  }) async {
    final c = _controller;
    if (c == null || busy) return;
    Set<TermuxMigrationItem>? saved;
    try {
      saved = await c.savedSelection(sourceId);
    } catch (_) {
      saved = null;
    }
    if (saved == null && fallback.isNotEmpty) {
      return start(connection, sourceId, fallback);
    }
    if (saved != null) items = ordered(saved);
    return _run(
      sourceId,
      TermuxMigrationRequest.resume,
      (c) => c.resume(sourceId),
      store: connection.store,
    );
  }

  /// The saved selection of an unfinished (or finished) copy; null when
  /// none was saved or it cannot be read.
  Future<Set<TermuxMigrationItem>?> savedSelection(String sourceId) async {
    final c = _controller;
    if (c == null) return null;
    try {
      return await c.savedSelection(sourceId);
    } catch (_) {
      return null;
    }
  }

  /// Stops the running operation at once; [leaving] says the app left the
  /// foreground. Await [settled] before offering Resume or leaving.
  Future<void> cancel({bool leaving = false}) async {
    final c = _controller;
    if (c == null || !busy) return;
    if (leaving) stoppedByLeaving = true;
    try {
      await c.cancel();
    } catch (_) {
      // The controller publishes a fixed cancelled state either way.
    }
    _changed();
  }

  /// Completes when no operation runs.
  Future<void> settled() => _inFlight ?? Future.value();

  /// The job id of the finished, verified move from [profileId]; null
  /// when it has not finished.
  static String? completedJob(ProfileStore store, String profileId) {
    final job = store.prefs.get(doneKey(profileId));
    return job is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(job)
        ? job
        : null;
  }

  /// The AI providers the Termux server was signed in to, by name.
  static List<String> providers(ProfileStore store, String profileId) =>
      store.prefs.getStringList(providersKey(profileId)) ?? const [];

  Future<void> _remember(
    ProfileStore store,
    String profileId,
    String job,
  ) async {
    if (!store.profiles.any((p) => p.id == profileId)) return;
    try {
      await store.prefs.setString(doneKey(profileId), job);
    } catch (_) {
      // This phone then offers Resume, which verifies the same receipts.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android gives the copy no background lifetime (the backend's 15-minute
    // foreground budget): leaving the app stops it, and Resume picks up.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (copying) unawaited(cancel(leaving: true));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_changed);
      // Dispose only after the running operation settles (the contract).
      final running = _inFlight;
      if (running == null) {
        c.dispose();
      } else {
        unawaited(c.cancel().catchError((Object _) {}));
        unawaited(running.whenComplete(c.dispose));
      }
    }
    super.dispose();
  }
}
