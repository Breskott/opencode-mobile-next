// Retired by slice-P3.7a: the read-only diff page is [DiffPage] in
// screens/review_workspace.dart. This file only keeps the chat library
// compiling until the chat lane swaps its one import (chat_screen.dart
// `_showDiff`: `DiffView(` -> `DiffPage(`); then it is deleted.
import '../screens/review_workspace.dart' show DiffPage;

export '../screens/review_workspace.dart' show DiffPage;

/// The old name of [DiffPage], for chat_screen.dart only.
typedef DiffView = DiffPage;
