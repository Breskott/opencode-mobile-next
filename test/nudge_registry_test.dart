import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/conversation_nudges.dart';
import 'package:opencode_mobile/state/nudges.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<NudgeRegistry> _registry({
  Map<String, Object> stored = const {},
  bool firstReplySeen = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (firstReplySeen) NudgeRegistry.firstReplySeenKey: true,
    ...stored,
  });
  return NudgeRegistry(await SharedPreferences.getInstance());
}

/// A timer the test fires by hand, so "a minute passed" needs no waiting.
class _ManualTimer implements Timer {
  _ManualTimer(this.duration, this._callback);
  final Duration duration;
  final void Function() _callback;
  bool cancelled = false;

  void fire() {
    if (!cancelled) _callback();
  }

  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

MessageWithParts _message(String role, [List<Part> parts = const []]) =>
    MessageWithParts(
      info: MessageInfo(
        id: '$role-${parts.length}',
        sessionID: 's',
        role: role,
      ),
      parts: parts,
    );

Part _tool(String name, String status) => Part(
  type: 'tool',
  toolName: name,
  toolState: ToolState(status: status),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('registry', () {
    test('a nudge fires once only', () async {
      final registry = await _registry();
      expect(registry.offer(NudgeId.compact, scope: 'a'), isTrue);
      expect(registry.activeFor('a')?.id, NudgeId.compact);
      await registry.dismiss(NudgeId.compact);
      expect(registry.active, isNull);
      expect(registry.offer(NudgeId.compact, scope: 'a'), isFalse);
      expect(registry.active, isNull);
    });

    test('what was shown survives a reload', () async {
      final shownAt = DateTime.utc(2026, 9, 19, 10);
      SharedPreferences.setMockInitialValues({
        NudgeRegistry.firstReplySeenKey: true,
      });
      final preferences = await SharedPreferences.getInstance();
      final first = NudgeRegistry(preferences, now: () => shownAt);
      expect(first.offer(NudgeId.reviewChanges, scope: 'a'), isTrue);
      await first.dismiss(NudgeId.reviewChanges);

      final reloaded = NudgeRegistry(preferences);
      final record = reloaded.record(NudgeId.reviewChanges);
      expect(record?.shownAt, shownAt);
      expect(record?.dismissed, isTrue);
      expect(reloaded.offer(NudgeId.reviewChanges, scope: 'a'), isFalse);
      // A reload never resurrects a card: only a trigger shows one.
      expect(reloaded.active, isNull);
    });

    test('a shown but never dismissed nudge still does not return', () async {
      SharedPreferences.setMockInitialValues({
        NudgeRegistry.firstReplySeenKey: true,
      });
      final preferences = await SharedPreferences.getInstance();
      final first = NudgeRegistry(preferences);
      expect(first.offer(NudgeId.leaveAndBeTold, scope: 'a'), isTrue);
      first.release(NudgeId.leaveAndBeTold);
      await Future<void>.delayed(Duration.zero);

      final reloaded = NudgeRegistry(preferences);
      expect(reloaded.record(NudgeId.leaveAndBeTold)?.dismissed, isFalse);
      expect(reloaded.offer(NudgeId.leaveAndBeTold, scope: 'a'), isFalse);
    });

    test('dismissed stays dismissed', () async {
      final registry = await _registry();
      registry.offer(NudgeId.approvals, scope: 'a', detail: 'edit');
      await registry.dismiss(NudgeId.approvals);
      expect(registry.record(NudgeId.approvals)?.dismissed, isTrue);
      expect(registry.offer(NudgeId.approvals, scope: 'a'), isFalse);
      expect(registry.offer(NudgeId.approvals, scope: 'b'), isFalse);
      expect(registry.activeFor('a'), isNull);
    });

    test('never two at once, and the refused one is not consumed', () async {
      final registry = await _registry();
      expect(registry.offer(NudgeId.compact, scope: 'a'), isTrue);
      expect(registry.offer(NudgeId.reviewChanges, scope: 'a'), isFalse);
      expect(registry.offer(NudgeId.pinConversations, scope: 'work'), isFalse);
      expect(registry.active?.id, NudgeId.compact);
      expect(registry.wasShown(NudgeId.reviewChanges), isFalse);

      await registry.dismiss(NudgeId.compact);
      // Its next real trigger may show it.
      expect(registry.offer(NudgeId.reviewChanges, scope: 'a'), isTrue);
    });

    test('nothing is offered before the first reply', () async {
      final registry = await _registry(firstReplySeen: false);
      expect(registry.offer(NudgeId.compact, scope: 'a'), isFalse);
      expect(registry.wasShown(NudgeId.compact), isFalse);

      await registry.markFirstReplySeen();
      expect(registry.offer(NudgeId.compact, scope: 'a'), isTrue);
    });

    test('reset lets every nudge fire again', () async {
      final registry = await _registry();
      registry.offer(NudgeId.compact, scope: 'a');
      await registry.dismiss(NudgeId.compact);
      registry.offer(NudgeId.reviewChanges, scope: 'a');

      var notified = 0;
      registry.addListener(() => notified += 1);
      await registry.reset();

      expect(notified, 1);
      expect(registry.active, isNull);
      expect(registry.preferences.getString(NudgeRegistry.shownKey), isNull);
      expect(registry.firstReplySeen, isTrue);
      expect(registry.offer(NudgeId.compact, scope: 'a'), isTrue);
    });

    test('a nudge only renders at the place it was offered', () async {
      final registry = await _registry();
      registry.offer(NudgeId.compact, scope: 'a');
      expect(registry.activeFor('b'), isNull);
      registry.releaseScope('b');
      expect(registry.active?.id, NudgeId.compact);
      registry.releaseScope('a');
      expect(registry.active, isNull);
    });

    test('unreadable stored state means nothing was shown', () async {
      final registry = await _registry(
        stored: {NudgeRegistry.shownKey: 'not json'},
      );
      expect(registry.offer(NudgeId.compact, scope: 'a'), isTrue);
    });

    test('the second project is counted without storing its path', () async {
      final registry = await _registry();
      await registry.noteProjectUsed(profileID: 'p', directory: '/work/app');
      await registry.noteProjectUsed(profileID: 'p', directory: '/work/app');
      expect(registry.secondProjectUsed, isFalse);
      await registry.noteProjectUsed(profileID: 'p', directory: '');
      expect(registry.secondProjectUsed, isFalse);
      await registry.noteProjectUsed(profileID: 'p', directory: '/work/site');
      expect(registry.secondProjectUsed, isTrue);
      await registry.noteProjectUsed(profileID: 'p', directory: '/work/third');

      final stored = registry.preferences.getStringList(
        NudgeRegistry.projectsKey,
      )!;
      expect(stored, hasLength(2));
      expect(stored.join(), isNot(contains('work')));
    });
  });

  group('conversation triggers', () {
    const idle = ConversationNudgeFacts(busy: false, hasAssistantReply: true);

    test(
      'the first reply is recorded, and its own moment stays quiet',
      () async {
        final registry = await _registry(firstReplySeen: false);
        final watcher = ConversationNudgeWatcher(
          registry: registry,
          conversation: 's',
        );
        watcher.observe(
          const ConversationNudgeFacts(busy: true, hasAssistantReply: false),
        );
        expect(registry.firstReplySeen, isFalse);
        // The first run finishes after editing files: no tip on that edge.
        watcher.observe(
          const ConversationNudgeFacts(
            busy: false,
            hasAssistantReply: true,
            runChangedFiles: true,
            reviewAvailable: true,
          ),
        );
        expect(registry.firstReplySeen, isTrue);
        expect(registry.active, isNull);
        expect(registry.wasShown(NudgeId.reviewChanges), isFalse);
      },
    );

    test('approvals: third request of one kind, once it is answered', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      ConversationNudgeFacts asking(Map<String, String> pending) =>
          ConversationNudgeFacts(
            busy: true,
            hasAssistantReply: true,
            pendingPermissions: pending,
            approvalsAvailable: true,
            suppressed: pending.isNotEmpty,
          );
      watcher.observe(asking({'r1': 'edit'}));
      // The same request seen again is not a second request.
      watcher.observe(asking({'r1': 'edit'}));
      watcher.observe(asking({}));
      watcher.observe(asking({'r2': 'edit', 'r3': 'bash'}));
      watcher.observe(asking({}));
      expect(registry.active, isNull);

      watcher.observe(asking({'r4': 'edit'}));
      expect(registry.active, isNull, reason: 'the request card comes first');
      watcher.observe(asking({}));
      expect(registry.activeFor('s')?.id, NudgeId.approvals);
      expect(registry.activeFor('s')?.detail, 'edit');
    });

    test('approvals: not where approvals are already automatic', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      for (final id in ['r1', 'r2', 'r3']) {
        watcher.observe(
          ConversationNudgeFacts(
            busy: true,
            hasAssistantReply: true,
            pendingPermissions: {id: 'edit'},
          ),
        );
      }
      watcher.observe(
        const ConversationNudgeFacts(busy: true, hasAssistantReply: true),
      );
      expect(registry.active, isNull);
      expect(registry.wasShown(NudgeId.approvals), isFalse);
    });

    test('review: a run that changed files finishes', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      const changed = ConversationNudgeFacts(
        busy: false,
        hasAssistantReply: true,
        runChangedFiles: true,
        reviewAvailable: true,
      );
      // Opening a finished conversation is not a run finishing.
      watcher.observe(changed);
      expect(registry.active, isNull);

      watcher.observe(
        const ConversationNudgeFacts(busy: true, hasAssistantReply: true),
      );
      watcher.observe(changed);
      expect(registry.activeFor('s')?.id, NudgeId.reviewChanges);
    });

    test('review: not without changes, not without a review', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      const busy = ConversationNudgeFacts(busy: true, hasAssistantReply: true);
      watcher.observe(busy);
      watcher.observe(idle);
      watcher.observe(busy);
      watcher.observe(
        const ConversationNudgeFacts(
          busy: false,
          hasAssistantReply: true,
          runChangedFiles: true,
        ),
      );
      expect(registry.wasShown(NudgeId.reviewChanges), isFalse);
    });

    test('leave: a minute of waiting with notifications ready', () async {
      final registry = await _registry();
      final timers = <_ManualTimer>[];
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
        createTimer: (duration, callback) {
          final timer = _ManualTimer(duration, callback);
          timers.add(timer);
          return timer;
        },
      );
      const waiting = ConversationNudgeFacts(
        busy: true,
        hasAssistantReply: true,
        finishedRunNotificationsReady: true,
      );
      watcher.observe(waiting);
      watcher.observe(waiting);
      expect(timers, hasLength(1));
      expect(timers.single.duration, const Duration(seconds: 60));
      expect(registry.active, isNull);

      timers.single.fire();
      expect(registry.activeFor('s')?.id, NudgeId.leaveAndBeTold);

      // The run ends: the sentence is no longer true, so the card leaves.
      watcher.observe(idle);
      expect(registry.active, isNull);
      expect(registry.record(NudgeId.leaveAndBeTold)?.dismissed, isFalse);
    });

    test('leave: never when a notification could not reach them', () async {
      final registry = await _registry();
      late _ManualTimer timer;
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
        createTimer: (duration, callback) =>
            timer = _ManualTimer(duration, callback),
      );
      watcher.observe(
        const ConversationNudgeFacts(busy: true, hasAssistantReply: true),
      );
      timer.fire();
      expect(registry.wasShown(NudgeId.leaveAndBeTold), isFalse);
    });

    test('leave: a run that ends early cancels the wait', () async {
      final registry = await _registry();
      late _ManualTimer timer;
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
        createTimer: (duration, callback) =>
            timer = _ManualTimer(duration, callback),
      );
      watcher.observe(
        const ConversationNudgeFacts(
          busy: true,
          hasAssistantReply: true,
          finishedRunNotificationsReady: true,
        ),
      );
      watcher.observe(idle);
      expect(timer.cancelled, isTrue);
      timer.fire();
      expect(registry.active, isNull);
    });

    test('compact: from 80 percent, where compacting exists', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      ConversationNudgeFacts at(double? usage, {bool available = true}) =>
          ConversationNudgeFacts(
            busy: false,
            hasAssistantReply: true,
            contextUsage: usage,
            compactAvailable: available,
          );
      watcher.observe(at(.79));
      watcher.observe(at(null));
      watcher.observe(at(.95, available: false));
      expect(registry.active, isNull);

      watcher.observe(at(.826));
      expect(registry.activeFor('s')?.id, NudgeId.compact);
      expect(registry.activeFor('s')?.detail, '83');

      // Compacted elsewhere: the tip has nothing left to say.
      watcher.observe(at(.2));
      expect(registry.active, isNull);
    });

    test('another card above the composer keeps every tip back', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      watcher.observe(
        const ConversationNudgeFacts(
          busy: false,
          hasAssistantReply: true,
          contextUsage: .9,
          compactAvailable: true,
          suppressed: true,
        ),
      );
      expect(registry.wasShown(NudgeId.compact), isFalse);
    });

    test('closing the conversation frees the slot', () async {
      final registry = await _registry();
      final watcher = ConversationNudgeWatcher(
        registry: registry,
        conversation: 's',
      );
      watcher.observe(
        const ConversationNudgeFacts(
          busy: false,
          hasAssistantReply: true,
          contextUsage: .9,
          compactAvailable: true,
        ),
      );
      expect(registry.active, isNotNull);
      watcher.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(registry.active, isNull);
      expect(registry.offer(NudgeId.pinConversations, scope: 'work'), isTrue);
    });

    test('a run changed files when a writing tool completed in it', () {
      expect(runChangedFiles([]), isFalse);
      expect(
        runChangedFiles([
          _message('user'),
          _message('assistant', [_tool('read', 'completed')]),
        ]),
        isFalse,
      );
      expect(
        runChangedFiles([
          _message('user'),
          _message('assistant', [_tool('edit', 'error')]),
        ]),
        isFalse,
      );
      expect(
        runChangedFiles([
          _message('user'),
          _message('assistant', [_tool('read', 'completed')]),
          _message('assistant', [_tool('write', 'completed')]),
        ]),
        isTrue,
      );
      // An edit in an earlier run is not this run's change.
      expect(
        runChangedFiles([
          _message('user'),
          _message('assistant', [_tool('edit', 'completed')]),
          _message('user'),
          _message('assistant', [_tool('read', 'completed')]),
        ]),
        isFalse,
      );
    });
  });
}
