import 'package:flutter/foundation.dart';

/// One technical value a person may need but never reads first: an
/// address, a path, a branch, an id (docs/ux-system/kit-v2.md §1.8, §4.10).
/// Kit parts show it last, folded under Details, in mono, isolated left to
/// right so a path inside Arabic text never reorders.
///
/// Never a secret: credentials never reach a technical value.
@immutable
class KitTechnicalValue {
  const KitTechnicalValue(
    this.label,
    this.value, {
    this.copyable = true,
    this.key,
  });

  /// What it is, in the person's words: "Address", "Branch".
  final String label;

  /// The value itself, shown exactly and selectable.
  final String value;
  final bool copyable;
  final Key? key;
}
