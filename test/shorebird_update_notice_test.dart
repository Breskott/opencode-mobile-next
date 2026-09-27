import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/automation_policy.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_screen.dart';
import 'package:opencode_mobile/ui/kit/kit_status_line.dart';
import 'package:opencode_mobile/ui/kit/kit_status_slot.dart';
import 'package:opencode_mobile/ui/kit/kit_top_bar.dart';
import 'package:opencode_mobile/update/shorebird_update_notice.dart';

class _FakeUpdateService implements AppUpdateService {
  _FakeUpdateService(this.state, {this.check});

  final AppUpdateState state;
  final Completer<AppUpdateState>? check;
  final download = Completer<void>();
  int checkCalls = 0;
  int downloadCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<AppUpdateState> checkForUpdate() async {
    checkCalls += 1;
    if (check case final pending?) return pending.future;
    return state;
  }

  @override
  Future<void> downloadUpdate() {
    downloadCalls += 1;
    return download.future;
  }
}

const _ready = 'App update ready';
const _readyBody =
    'It takes effect when you fully close the app and open it again.';

/// The notice where main.dart mounts it (above the Navigator), with a page
/// on the kit's screen frame below, whose status slot draws the line.
Widget _app(
  AppUpdateService service, {
  Widget Function(Widget)? above,
  String? Function()? currentProfileId,
  bool Function(String)? allowsAutomaticUpdate,
  Future<void> Function({
    required String profileId,
    required String eventId,
    required DateTime at,
  })?
  onDownloaded,
}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      final notice = ShorebirdUpdateNotice(
        service: service,
        currentProfileId: currentProfileId ?? () => 'server-a',
        allowsAutomaticUpdate: allowsAutomaticUpdate ?? (_) => true,
        onDownloaded: onDownloaded,
        child: child ?? const SizedBox.shrink(),
      );
      return above == null ? notice : above(notice);
    },
    home: KitScreen(
      topBar: const KitTopBar(title: 'Work'),
      body: ListView(children: const [Text('OpenCode')]),
      bottom: KitActionBlock(
        primary: KitAction(label: 'New conversation', onPressed: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('disabled policy never schedules a check or download', (
    tester,
  ) async {
    final service = _FakeUpdateService(AppUpdateState.available);
    final policy = AutomationPolicy.disabled();
    var records = 0;
    await tester.pumpWidget(
      _app(
        service,
        allowsAutomaticUpdate: (_) =>
            policy.allows(AutomationBehavior.applyCodePush),
        onDownloaded:
            ({required profileId, required eventId, required at}) async {
              records++;
            },
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.checkCalls, 0);
    expect(service.downloadCalls, 0);
    expect(records, 0);
  });

  testWidgets('checks consent again before downloading', (tester) async {
    final check = Completer<AppUpdateState>();
    final service = _FakeUpdateService(AppUpdateState.available, check: check);
    var policy = AutomationPolicy();
    var records = 0;
    await tester.pumpWidget(
      _app(
        service,
        allowsAutomaticUpdate: (_) =>
            policy.allows(AutomationBehavior.applyCodePush),
        onDownloaded:
            ({required profileId, required eventId, required at}) async {
              records++;
            },
      ),
    );
    await tester.pump();
    expect(service.checkCalls, 1);
    policy = AutomationPolicy.disabled();
    check.complete(AppUpdateState.available);
    await tester.pumpAndSettle();
    expect(service.downloadCalls, 0);
    expect(records, 0);
  });

  testWidgets('records once after confirmation under download-start server', (
    tester,
  ) async {
    final service = _FakeUpdateService(AppUpdateState.available);
    var currentProfile = 'server-a';
    final records = <({String profileId, String eventId, DateTime at})>[];
    await tester.pumpWidget(
      _app(
        service,
        currentProfileId: () => currentProfile,
        onDownloaded:
            ({required profileId, required eventId, required at}) async {
              records.add((profileId: profileId, eventId: eventId, at: at));
            },
      ),
    );
    await tester.pump();
    expect(service.downloadCalls, 1);
    expect(records, isEmpty);
    currentProfile = 'server-b';
    final completedAfter = DateTime.now().toUtc();
    service.download.complete();
    await tester.pumpAndSettle();
    expect(records, hasLength(1));
    expect(records.single.profileId, 'server-a');
    expect(records.single.eventId, startsWith('shorebird-update:'));
    expect(records.single.at.isBefore(completedAfter), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(records, hasLength(1));
  });

  testWidgets('already downloaded patches do not create another act', (
    tester,
  ) async {
    final service = _FakeUpdateService(AppUpdateState.restartRequired);
    var records = 0;
    await tester.pumpWidget(
      _app(
        service,
        onDownloaded:
            ({required profileId, required eventId, required at}) async {
              records++;
            },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_ready), findsOneWidget);
    expect(service.downloadCalls, 0);
    expect(records, 0);
  });

  testWidgets('no current server means no unowned automatic download', (
    tester,
  ) async {
    final service = _FakeUpdateService(AppUpdateState.available);
    await tester.pumpWidget(_app(service, currentProfileId: () => null));
    await tester.pumpAndSettle();
    expect(service.checkCalls, 0);
    expect(service.downloadCalls, 0);
  });

  testWidgets('downloads silently, then says the update is ready once', (
    tester,
  ) async {
    final service = _FakeUpdateService(AppUpdateState.available);
    await tester.pumpWidget(_app(service));
    await tester.pump();
    await tester.pump();

    expect(service.checkCalls, 1);
    expect(service.downloadCalls, 1);
    // Silent while it downloads: no progress words, no snackbar, no line.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(KitStatusLine), findsNothing);
    expect(find.textContaining('Shorebird'), findsNothing);

    service.download.complete();
    await tester.pumpAndSettle();

    expect(find.text(_ready), findsOneWidget);
    expect(find.text(_readyBody), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // The pinned primary stays in view: the line sits under the top bar.
    expect(find.text('New conversation'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text(_readyBody)).dy,
      lessThan(tester.getTopLeft(find.text('New conversation')).dy),
    );
    // No tool name reaches the person.
    expect(find.textContaining('Shorebird'), findsNothing);
  });

  testWidgets('Dismiss hides the line for the rest of the run', (tester) async {
    final service = _FakeUpdateService(AppUpdateState.restartRequired);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text(_ready), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kit-status-dismiss')));
    await tester.pumpAndSettle();
    expect(find.text(_ready), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(_ready), findsNothing);
    expect(service.checkCalls, 1, reason: 'a ready update is not re-checked');
  });

  testWidgets('never claims readiness after a failed download', (tester) async {
    final service = _FakeUpdateService(AppUpdateState.available);
    var records = 0;
    await tester.pumpWidget(
      _app(
        service,
        onDownloaded:
            ({required profileId, required eventId, required at}) async {
              records++;
            },
      ),
    );
    await tester.pump();
    await tester.pump();

    service.download.completeError(Exception('patch hash mismatch'));
    await tester.pumpAndSettle();

    expect(find.text(_ready), findsNothing);
    expect(find.byType(KitStatusLine), findsNothing);
    expect(tester.takeException(), isNull);
    expect(records, 0);
  });

  testWidgets('a higher condition from an outer scope wins the one line', (
    tester,
  ) async {
    final outer = ValueNotifier<List<KitStatus>>([
      const KitStatus(
        kind: KitStatusKind.connection,
        icon: AppIconography.cloudOff,
        message: 'Reconnecting to Laptop…',
      ),
    ]);
    addTearDown(outer.dispose);
    final service = _FakeUpdateService(AppUpdateState.restartRequired);
    await tester.pumpWidget(
      _app(
        service,
        above: (notice) => KitStatusScope(conditions: outer, child: notice),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reconnecting to Laptop…'), findsOneWidget);
    expect(find.text(_ready), findsNothing);
    expect(find.byType(KitStatusLine), findsOneWidget);

    outer.value = const [];
    await tester.pumpAndSettle();
    expect(find.text('Reconnecting to Laptop…'), findsNothing);
    expect(find.text(_ready), findsOneWidget);
  });

  testWidgets('an unavailable updater never checks and shows nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const UnavailableAppUpdateService()));
    await tester.pumpAndSettle();
    expect(find.byType(KitStatusLine), findsNothing);
  });
}
