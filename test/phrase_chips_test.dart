import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/phrase_chips.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime clock;
  late PhraseChipStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime.utc(2026, 10, 12, 9);
    store = PhraseChipStore(prefs, 'alpha', now: () => clock);
  });

  Future<void> send(String text, PhraseMoment moment, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await store.record(text, moment);
      clock = clock.add(const Duration(minutes: 1));
    }
  }

  List<String> chips(
    PhraseMoment moment, {
    List<String> starters = const [],
    Set<String> exclude = const {},
  }) => [
    for (final chip in store.chipsFor(
      moment,
      starters: starters,
      exclude: exclude,
    ))
      chip.text,
  ];

  group('normalization', () {
    test('case, spacing and trailing punctuation are one phrase', () {
      expect(PhraseChipStore.normalize('  Run  the TESTS. '), 'run the tests');
      expect(PhraseChipStore.normalize('Run the tests?!'), 'run the tests');
      expect(PhraseChipStore.normalize('ما المستجدات؟'), 'ما المستجدات');
    });

    test('the latest spelling is shown', () async {
      await send('run the tests', PhraseMoment.idle);
      await send('Run the tests!', PhraseMoment.idle);
      expect(chips(PhraseMoment.idle), ['Run the tests!']);
    });
  });

  group('what is recorded', () {
    test('rejects long, multi-line, command, shell and mention text', () {
      for (final text in [
        'x' * 41,
        'one\ntwo',
        '/compact',
        '!ls -la',
        'ask @reviewer',
        ' ',
        'a',
      ]) {
        expect(PhraseChipStore.isRecordable(text), isFalse, reason: text);
      }
      expect(
        PhraseChipStore.isRecordable(
          'abcdefghi abcdefghi abcdefghi abcdefghij',
        ),
        isTrue,
      );
    });

    test('rejects a message that carried files', () async {
      expect(
        await store.record(
          'Look at this',
          PhraseMoment.idle,
          hasAttachments: true,
        ),
        isFalse,
      );
      expect(store.learnedCount, 0);
    });

    test('never records or shows anything that looks like a secret', () async {
      for (final text in [
        'sk-ant-api03-abcdefghijklmnopqrstuvwxyz',
        'ghp_abcdefghijklmnopqrstuvwxyz0123',
        'AKIAABCDEFGHIJKLMNOPQRST',
        'use abcdefghijklmnopqrstuvwxyz now',
      ]) {
        expect(PhraseChipStore.looksSecret(text), isTrue, reason: text);
        await send(text, PhraseMoment.idle, 3);
      }
      expect(store.learnedCount, 0);
      expect(chips(PhraseMoment.idle), isEmpty);
      expect(prefs.getString(PhraseChipStore.keyFor('alpha')), isNull);
    });
  });

  group('becoming a chip', () {
    test('a phrase needs two sends', () async {
      await send('Run the tests', PhraseMoment.idle);
      expect(chips(PhraseMoment.idle), isEmpty);
      await send('run the tests.', PhraseMoment.idle);
      expect(chips(PhraseMoment.idle), ['run the tests.']);
    });

    test('chips are chosen for the moment', () async {
      await send('Commit it', PhraseMoment.finishedWithChanges, 2);
      await send("What's the update?", PhraseMoment.working, 2);
      expect(chips(PhraseMoment.finishedWithChanges), ['Commit it']);
      expect(chips(PhraseMoment.working), ["What's the update?"]);
      expect(chips(PhraseMoment.idle), isEmpty);
      expect(chips(PhraseMoment.stoppedPartway), isEmpty);
    });

    test('a phrase sent in two moments counts for both', () async {
      await send('Run the tests', PhraseMoment.idle);
      await send('Run the tests', PhraseMoment.finishedWithChanges);
      expect(chips(PhraseMoment.idle), ['Run the tests']);
      expect(chips(PhraseMoment.finishedWithChanges), ['Run the tests']);
    });
  });

  group('ranking', () {
    test('more sends rank first, at most four are shown', () async {
      await send('one', PhraseMoment.idle, 2);
      await send('two', PhraseMoment.idle, 3);
      await send('three', PhraseMoment.idle, 4);
      await send('four', PhraseMoment.idle, 5);
      await send('five', PhraseMoment.idle, 6);
      expect(chips(PhraseMoment.idle), ['five', 'four', 'three', 'two']);
    });

    test('recency decays a stale favourite below a fresh one', () async {
      await send('old favourite', PhraseMoment.idle, 4);
      clock = clock.add(const Duration(days: 60));
      await send('fresh one', PhraseMoment.idle, 2);
      expect(chips(PhraseMoment.idle), ['fresh one', 'old favourite']);
    });

    test('without decay time the bigger count wins', () async {
      await send('old favourite', PhraseMoment.idle, 4);
      clock = clock.add(const Duration(days: 1));
      await send('fresh one', PhraseMoment.idle, 2);
      expect(chips(PhraseMoment.idle), ['old favourite', 'fresh one']);
    });
  });

  group('starters', () {
    test('the moment\'s starter leads what was learned', () async {
      await send('Run the tests', PhraseMoment.stoppedPartway, 3);
      await send('Commit it', PhraseMoment.stoppedPartway, 2);
      expect(chips(PhraseMoment.stoppedPartway, starters: ['Continue']), [
        'Continue',
        'Run the tests',
        'Commit it',
      ]);
    });

    test('show alone when nothing is learned', () {
      expect(chips(PhraseMoment.stoppedPartway, starters: ['Continue']), [
        'Continue',
      ]);
      expect(store.chipsFor(PhraseMoment.idle, starters: ['Continue']), [
        const PhraseChip('Continue', starter: true),
      ]);
    });

    test('a learned phrase is not repeated as its starter', () async {
      await send('continue.', PhraseMoment.stoppedPartway, 2);
      final result = store.chipsFor(
        PhraseMoment.stoppedPartway,
        starters: ['Continue'],
      );
      expect(result, [const PhraseChip('continue.')]);
    });

    test('exclude drops a chip (the transcript shows Continue)', () async {
      await send('Continue', PhraseMoment.stoppedPartway, 2);
      expect(
        chips(
          PhraseMoment.stoppedPartway,
          starters: ['Continue'],
          exclude: {'Continue'},
        ),
        isEmpty,
      );
    });
  });

  group('hide', () {
    test('a hidden phrase and its starter are never suggested', () async {
      await send('Commit it', PhraseMoment.idle, 3);
      await store.hide('commit it!');
      expect(chips(PhraseMoment.idle), isEmpty);
      await store.hide('Continue');
      expect(
        chips(PhraseMoment.stoppedPartway, starters: ['Continue']),
        isEmpty,
      );
      expect(store.hiddenCount, 2);
      // And it is not learned again while hidden.
      expect(await store.record('Commit it', PhraseMoment.idle), isFalse);
    });

    test('Show hidden phrases brings them back', () async {
      await send('Commit it', PhraseMoment.idle, 3);
      await store.hide('Commit it');
      await store.showHidden();
      expect(store.hiddenCount, 0);
      expect(chips(PhraseMoment.idle), ['Commit it']);
    });
  });

  group('bounds', () {
    test('keeps the 50 most recent phrases', () async {
      for (var i = 0; i < PhraseChipStore.maxEntries + 5; i++) {
        await send('phrase $i', PhraseMoment.idle);
      }
      expect(store.learnedCount, PhraseChipStore.maxEntries);
      await send('phrase 0', PhraseMoment.idle);
      expect(store.learnedCount, PhraseChipStore.maxEntries);
      // Phrase 0 was evicted, so it is new again: one send, no chip.
      expect(chips(PhraseMoment.idle), isNot(contains('phrase 0')));
    });

    test('hidden phrases are bounded too', () async {
      for (var i = 0; i < PhraseChipStore.maxHidden + 10; i++) {
        await store.hide('hidden $i');
      }
      expect(store.hiddenCount, PhraseChipStore.maxHidden);
    });
  });

  group('persistence and deletion', () {
    test('survives a restart, and keeps profiles apart', () async {
      await send('Run the tests', PhraseMoment.idle, 2);
      final restarted = PhraseChipStore(prefs, 'alpha', now: () => clock);
      expect(
        [for (final c in restarted.chipsFor(PhraseMoment.idle)) c.text],
        ['Run the tests'],
      );
      final other = PhraseChipStore(prefs, 'beta', now: () => clock);
      expect(other.chipsFor(PhraseMoment.idle), isEmpty);
    });

    test('a corrupt blob reads as nothing learned', () async {
      await prefs.setString(PhraseChipStore.keyFor('alpha'), '{not json');
      expect(chips(PhraseMoment.idle), isEmpty);
      await send('Run the tests', PhraseMoment.idle, 2);
      expect(chips(PhraseMoment.idle), ['Run the tests']);
    });

    test(
      'the profile sweep removes it, and a late write cannot undo it',
      () async {
        final owner = PhraseChipStore.forProfile(prefs, 'alpha');
        await owner.record('Run the tests', PhraseMoment.idle);
        final profiles = ProfileStore(prefs: prefs);
        expect(
          profiles.profileScopedPreferenceKeys('alpha'),
          contains('oc.phraseChips.alpha'),
        );
        await profiles.removeScopedPreferences('alpha');
        expect(prefs.containsKey('oc.phraseChips.alpha'), isFalse);
        // The deleted server's chat is still open and sends again.
        await owner.record('Run the tests', PhraseMoment.idle);
        await owner.hide('Run the tests');
        expect(prefs.containsKey('oc.phraseChips.alpha'), isFalse);
      },
    );

    test('the switch is device-wide and defaults on', () async {
      expect(PhraseChipStore.enabled(prefs), isTrue);
      await PhraseChipStore.setEnabled(prefs, false);
      expect(PhraseChipStore.enabled(prefs), isFalse);
      // Not profile data: the sweep leaves it.
      expect(
        ProfileStore(prefs: prefs).profileScopedPreferenceKeys('alpha'),
        isNot(contains(PhraseChipStore.enabledKey)),
      );
    });
  });

  test('redo phrases are never offered while the agent works', () async {
    await send('Try again', PhraseMoment.working, 3);
    await send('Run the tests', PhraseMoment.working, 3);
    await send('Try again', PhraseMoment.stoppedPartway, 3);
    expect(chips(PhraseMoment.working), ['Run the tests']);
    expect(chips(PhraseMoment.stoppedPartway), ['Try again']);
  });
}
