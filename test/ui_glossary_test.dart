import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One word per action (UX reorganization plan, section 6 "Glossary").
///
/// A person should meet one label for re-attempting something that failed
/// ("Try again") and one for ending running work ("Stop"). This scans the
/// English source strings for the banned synonyms on *action labels* so a new
/// "Retry" button cannot drift back in unnoticed.
///
/// Only short labels are checked: status sentences such as "Free some space
/// and retry." are prose, not a control, and stay free to use the verb.

/// Terms an action label may not equal or start with.
const _bannedTerms = <String>['Retry', 'Check again', 'Check status', 'Abort'];

/// Keys allowed to keep a banned term. Keep this list small; every entry needs
/// its reason.
const _allowedKeys = <String>{
  // "Retry last prompt" is a named conversation action in the session menu:
  // it sends the previous prompt again on purpose. It is not the recovery
  // button of an error state, which is what "Try again" names.
  'chatUiRetryLastPrompt',
};

/// At most this many words makes a value a label rather than a sentence.
const _maxLabelWords = 4;

final _sentencePunctuation = RegExp(r'[.!?:;,…]');

bool _isShortActionLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (_sentencePunctuation.hasMatch(trimmed)) return false;
  return trimmed.split(RegExp(r'\s+')).length <= _maxLabelWords;
}

/// The banned term [value] equals or starts with, or null. "Retrying" is a
/// status, not the action "Retry", so the term must end at a word boundary.
String? _bannedTermIn(String value) {
  final trimmed = value.trim();
  for (final term in _bannedTerms) {
    if (RegExp('^${RegExp.escape(term)}\\b').hasMatch(trimmed)) return term;
  }
  return null;
}

Map<String, String> _englishStrings() {
  final decoded =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

void main() {
  test('the label rule separates labels from sentences', () {
    expect(_isShortActionLabel('Retry'), isTrue);
    expect(_isShortActionLabel('Retry saving draft'), isTrue);
    expect(_isShortActionLabel('Retry {runtime}'), isTrue);
    expect(_isShortActionLabel('Free some space and retry.'), isFalse);
    expect(
      _isShortActionLabel('Retry disabling recovery on this phone'),
      isFalse,
    );
    expect(_bannedTermIn('Retry'), 'Retry');
    expect(_bannedTermIn('Retry projects'), 'Retry');
    expect(_bannedTermIn('Check status'), 'Check status');
    expect(_bannedTermIn('Retrying'), isNull);
    expect(_bannedTermIn('Try again'), isNull);
    expect(_bannedTermIn('Aborted'), isNull);
  });

  test('action labels use the glossary word, not a banned synonym', () {
    final offenders = <String>[];
    for (final entry in _englishStrings().entries) {
      if (_allowedKeys.contains(entry.key)) continue;
      if (!_isShortActionLabel(entry.value)) continue;
      final term = _bannedTermIn(entry.value);
      if (term == null) continue;
      offenders.add('${entry.key}: "${entry.value}" starts with "$term"');
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use "Try again" to re-attempt a failure, "Refresh" to re-read '
          'current data and "Stop" to end running work '
          '(docs/design/ux-reorganization-plan-2026-09-19.md, section 6).\n'
          '${offenders.join('\n')}',
    );
  });

  test('every allow-listed key still needs its exemption', () {
    final strings = _englishStrings();
    for (final key in _allowedKeys) {
      final value = strings[key];
      expect(value, isNotNull, reason: '$key is allow-listed but gone');
      expect(
        _isShortActionLabel(value!) && _bannedTermIn(value) != null,
        isTrue,
        reason: '$key no longer uses a banned term; drop it from the list',
      );
    }
  });
}
