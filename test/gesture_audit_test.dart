import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UX plan 5.8, item 2: no feature is reachable only by a gesture.
///
/// The ledger lists every gesture element; `gesture-audit.json` must answer,
/// for each one, which visible control offers the same action (or why the
/// element is not a feature behind a gesture at all). A gesture added to the
/// ledger without an answer fails here, so the question cannot be skipped.
const _ledgerPath = 'docs/design/ui-ledger/ledger.json';
const _auditPath = 'docs/design/ui-ledger/gesture-audit.json';

/// The ledger's pseudo-page for app launch and route bootstrapping. Nothing
/// on it is something a person does.
const _systemPage = 'system';

String _id(Object? page, Object? element) => '$page / $element';

Set<String> _ledgerGestures() {
  final ledger =
      jsonDecode(File(_ledgerPath).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final page in (ledger['pages'] as List).cast<Map<String, dynamic>>())
      if (page['id'] != _systemPage)
        for (final element
            in ((page['elements'] as List?) ?? const [])
                .cast<Map<String, dynamic>>())
          if (element['type'] == 'gesture') _id(page['id'], element['id']),
  };
}

List<Map<String, dynamic>> _auditRows() {
  final audit =
      jsonDecode(File(_auditPath).readAsStringSync()) as Map<String, dynamic>;
  expect(audit['generatedFrom'], 'ledger.json');
  return (audit['rows'] as List).cast<Map<String, dynamic>>();
}

void main() {
  test('every ledger gesture has an audit row', () {
    final gestures = _ledgerGestures();
    expect(gestures, isNotEmpty, reason: 'the ledger lists gesture elements');
    final audited = {
      for (final row in _auditRows()) _id(row['page'], row['element']),
    };
    expect(
      gestures.difference(audited),
      isEmpty,
      reason:
          'A gesture without an audit row may be a feature only behind a '
          'gesture. Read its callback, name the visible control that does '
          'the same (add one if there is none), and add the row to '
          '$_auditPath and gesture-audit.md.',
    );
  });

  test('every audit row names a ledger gesture, once', () {
    final gestures = _ledgerGestures();
    final seen = <String>{};
    final unknown = <String>[];
    final repeated = <String>[];
    for (final row in _auditRows()) {
      final id = _id(row['page'], row['element']);
      if (!gestures.contains(id)) unknown.add(id);
      if (!seen.add(id)) repeated.add(id);
    }
    expect(unknown, isEmpty, reason: 'rows for elements not in the ledger');
    expect(repeated, isEmpty, reason: 'rows audited twice');
  });

  test('every audit row has a visible equivalent and evidence', () {
    final incomplete = <String>[];
    final missingEvidence = <String>[];
    // `lib/...dart:123`: a place in the code, not a description of one.
    final evidencePattern = RegExp(r'^lib/[\w/.]+\.dart:(\d+)$');
    for (final row in _auditRows()) {
      final id = _id(row['page'], row['element']);
      for (final field in const [
        'gesture',
        'action',
        'visibleEquivalent',
        'evidence',
      ]) {
        final value = row[field];
        if (value is! String || value.trim().isEmpty) {
          incomplete.add('$id: $field');
        }
      }
      if (row['changed'] is! bool) incomplete.add('$id: changed');
      final evidence = row['evidence'];
      if (evidence is! String) continue;
      final match = evidencePattern.firstMatch(evidence);
      if (match == null) {
        missingEvidence.add('$id: "$evidence" is not lib/<file>.dart:<line>');
        continue;
      }
      final file = File(evidence.substring(0, evidence.lastIndexOf(':')));
      if (!file.existsSync()) {
        missingEvidence.add('$id: ${file.path} does not exist');
      } else if (int.parse(match.group(1)!) > file.readAsLinesSync().length) {
        missingEvidence.add('$id: $evidence is past the end of the file');
      }
    }
    expect(incomplete, isEmpty);
    expect(missingEvidence, isEmpty);
  });
}
