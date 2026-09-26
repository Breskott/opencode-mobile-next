import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/domain/run_result.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/work_row_status_controller.dart';

final now = DateTime.utc(2026, 9, 27, 12);
final en = lookupAppLocalizations(const Locale('en'));

RunResult result({String? finish, bool completed = false}) =>
    RunResult.fromMessages('chat', [
      MessageWithParts(
        info: MessageInfo(
          id: 'user',
          sessionID: 'chat',
          role: 'user',
          time: MsgTime(
            created: now
                .subtract(const Duration(minutes: 7))
                .millisecondsSinceEpoch,
          ),
        ),
        parts: [],
      ),
      MessageWithParts(
        info: MessageInfo(
          id: 'assistant',
          sessionID: 'chat',
          role: 'assistant',
          finish: finish,
          time: MsgTime(
            created: now
                .subtract(const Duration(minutes: 6))
                .millisecondsSinceEpoch,
            completed: completed
                ? now
                      .subtract(const Duration(minutes: 4))
                      .millisecondsSinceEpoch
                : null,
          ),
        ),
        parts: [],
      ),
    ])!;

WorkRowStatus view(WorkRowFacts facts) =>
    WorkRowStatus(facts: facts, observedAt: now, isFresh: true);

void main() {
  test(
    'chat completion requires evidence; needs-you outranks busy and done',
    () {
      final done = result(finish: 'stop', completed: true);
      expect(
        view(WorkRowFacts.chat(busy: false, needsYou: false)).word(en),
        'Status unavailable',
      );
      expect(
        view(
          WorkRowFacts.chat(busy: false, needsYou: false, result: result()),
        ).word(en),
        'Status unavailable',
      );
      expect(
        view(
          WorkRowFacts.chat(busy: false, needsYou: false, result: done),
        ).line(en, now: now),
        'Done 4 min ago',
      );
      final waiting = view(
        WorkRowFacts.chat(busy: true, needsYou: true, result: done),
      );
      expect(waiting.word(en), 'Needs you');
      expect(waiting.line(en, now: now), waiting.word(en));
      expect(waiting.showLiveMark, false);
      final nextTurn = view(
        WorkRowFacts.chat(busy: true, needsYou: false, result: done),
      );
      expect(nextTurn.line(en, now: now), 'Working');
      expect(
        view(
          WorkRowFacts.chat(
            busy: false,
            needsYou: false,
            result: result(finish: 'length', completed: true),
          ),
        ).word(en),
        'Failed',
      );
    },
  );

  test(
    'chat and team share words and measured progress without raw content',
    () {
      final chat = WorkRowFacts.chat(
        busy: true,
        needsYou: false,
        todos: [
          for (var i = 0; i < 5; i++)
            Todo(
              content: 'private task',
              status: i < 2 ? 'completed' : 'pending',
            ),
        ],
      );
      final team = WorkRowFacts.team(
        item: const WorkItem(
          id: 'task',
          title: 'private title',
          state: WorkState.working,
        ),
        steps: chat.steps,
        startedAt: now.subtract(const Duration(minutes: 3)),
      );
      expect(view(chat).word(en), view(team).word(en));
      expect(view(team).line(en, now: now), 'Working · 2 of 5 done · 3 min');
      expect(view(team).showLiveMark, true);
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(view(team).line(ar, now: now), startsWith(view(team).word(ar)));
      expect(view(team).word(ar), isNot(view(team).word(en)));
    },
  );

  test(
    'disconnect freezes rows; reconnect waits for per-row fresh evidence',
    () {
      final controller = WorkRowStatusController();
      addTearDown(controller.dispose);
      var changes = 0;
      controller.addListener(() => changes++);
      controller.setConnected(true);
      final generation = controller.generation;
      final facts = WorkRowFacts(
        phase: WorkRowPhase.working,
        startedAt: now.subtract(const Duration(minutes: 3)),
      );
      controller.observe(
        'chat:1',
        facts,
        observedAt: now,
        generation: generation,
      );
      controller.observe(
        'team:1',
        facts,
        observedAt: now,
        generation: generation,
      );
      controller.setConnected(false);
      final stale = controller.statusFor('chat:1')!;
      expect(stale.showLiveMark, false);
      expect(stale.line(en, now: now), contains('as of'));
      expect(
        stale.line(en, now: now.add(const Duration(days: 1))),
        stale.line(en, now: now),
      );
      expect(
        controller.observe(
          'chat:1',
          facts,
          observedAt: now,
          generation: generation,
        ),
        false,
      );
      controller.setConnected(true);
      expect(controller.statusFor('chat:1')!.showLiveMark, false);
      expect(
        controller.observe(
          'chat:1',
          facts,
          observedAt: now,
          generation: generation,
        ),
        false,
      );
      expect(
        controller.observe(
          'chat:1',
          facts,
          observedAt: now,
          generation: controller.generation,
        ),
        true,
      );
      expect(controller.statusFor('chat:1')!.showLiveMark, true);
      expect(controller.statusFor('team:1')!.showLiveMark, false);
      expect(changes, 6);
    },
  );

  test('scope deletion and stale replies cannot resurrect rows', () {
    final controller = WorkRowStatusController();
    addTearDown(controller.dispose);
    controller.setConnected(true);
    final generation = controller.generation;
    const facts = WorkRowFacts(phase: WorkRowPhase.done);
    controller.observe(
      'chat:1',
      facts,
      observedAt: now,
      generation: generation,
    );
    expect(
      controller.observe(
        'chat:1',
        const WorkRowFacts(phase: WorkRowPhase.working),
        observedAt: now.subtract(const Duration(seconds: 1)),
        generation: generation,
      ),
      false,
    );
    expect(controller.statusFor('chat:1')!.word(en), 'Done');
    controller.remove('chat:1');
    expect(controller.statusFor('chat:1'), null);
    controller.observe(
      'chat:1',
      facts,
      observedAt: now,
      generation: generation,
    );
    controller.clear();
    controller.setConnected(true);
    expect(controller.statusFor('chat:1'), null);
    expect(
      controller.observe(
        'chat:1',
        facts,
        observedAt: now,
        generation: generation,
      ),
      false,
    );
  });

  test('unknown counts and times stay absent and clock skew is bounded', () {
    for (final state in WorkState.values) {
      final facts = WorkRowFacts.team(
        item: WorkItem(
          id: 'task',
          title: '',
          state: state,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(facts.startedAt, null);
      expect(facts.finishedAt, null);
      expect(view(facts).word(en), isNotEmpty);
    }
    final skewed = view(
      WorkRowFacts(
        phase: WorkRowPhase.working,
        startedAt: now.add(const Duration(minutes: 2)),
        steps: const WorkRowSteps(completed: 9, total: 2),
      ),
    );
    expect(skewed.line(en, now: now), 'Working · less than a minute');
    final done = WorkRowStatus(
      facts: WorkRowFacts(
        phase: WorkRowPhase.done,
        finishedAt: now.subtract(const Duration(minutes: 4)),
      ),
      observedAt: now,
      isFresh: false,
    );
    expect(
      done.line(en, now: now.add(const Duration(days: 1))),
      done.line(en, now: now),
    );
  });
}
