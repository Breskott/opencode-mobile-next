import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../theme_roles.dart';
import 'kit_bidi.dart';
import 'kit_buttons.dart';
import 'kit_choice_list.dart';
import 'kit_copy.dart';
import 'kit_icon_button.dart';
import 'kit_layout.dart';
import 'kit_menu.dart';
import 'kit_motion.dart';
import 'kit_page_route.dart';
import 'kit_progress.dart';
import 'kit_redact.dart';
import 'kit_screen.dart';
import 'kit_state_view.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';
import 'kit_top_bar.dart';
import 'motion/kit_reveal.dart';

/// What one line of a [KitDiffFile] is (docs/ux-system/kit-api/KitDiffView.md).
enum KitDiffLineKind { context, added, removed, hunk }

/// One line of a diff with the numbers it has in each file. A [hunk] line
/// carries the `@@` header as [text] and reads as a line range.
@immutable
class KitDiffLine {
  const KitDiffLine(this.text, this.kind, {this.oldNo, this.newNo});

  final String text;
  final KitDiffLineKind kind;
  final int? oldNo, newNo;
}

/// Unchanged lines that start folded. [lines] is null when the source (a
/// unified patch) does not carry them: the bar then only states the count.
@immutable
class KitDiffGap {
  const KitDiffGap({required this.count, this.lines});

  final int count;
  final List<KitDiffLine>? lines;
}

enum KitDiffFileStatus { modified, added, deleted, renamed }

/// One file's change, normalised into lines and gaps. Built by the caller
/// from its own model (the kit never sees lib/api types).
@immutable
class KitDiffFile {
  const KitDiffFile({
    required this.path,
    required this.segments,
    required this.added,
    required this.removed,
    this.status = KitDiffFileStatus.modified,
    this.oldPath,
    this.binary = false,
    this.fullText,
    this.patch,
  });

  /// Parses a unified patch; `@@` headers become hunk lines read as line
  /// ranges ("Lines 12–18"), and 3 context lines stay around each change.
  factory KitDiffFile.fromPatch(
    String path,
    String patch, {
    KitDiffFileStatus? status,
    String? oldPath,
  }) {
    if (patch.contains('GIT binary patch') ||
        RegExp(r'^Binary files .* differ$', multiLine: true).hasMatch(patch)) {
      return KitDiffFile(
        path: path,
        segments: const [],
        added: 0,
        removed: 0,
        status: status ?? KitDiffFileStatus.modified,
        oldPath: oldPath,
        binary: true,
        patch: patch,
      );
    }
    final segments = <Object>[];
    var oldNo = 0;
    var newNo = 0;
    var inHunk = false;
    var added = 0;
    var removed = 0;
    for (final line in patch.split('\n')) {
      if (line.startsWith('@@')) {
        final match = _hunkHeader.firstMatch(line);
        if (match != null) {
          final nextOld = int.parse(match.group(1)!);
          final nextNew = int.parse(match.group(3)!);
          final skipped = inHunk ? nextNew - newNo : nextNew - 1;
          if (skipped > 0) segments.add(KitDiffGap(count: skipped));
          oldNo = nextOld;
          newNo = nextNew;
          segments.add(
            KitDiffLine(
              line,
              KitDiffLineKind.hunk,
              oldNo: nextOld,
              newNo: nextNew,
            ),
          );
        }
        inHunk = true;
        continue;
      }
      // `--- a/x` / `+++ b/x` and `diff --git` preambles repeat what the
      // file header already says.
      if (!inHunk) continue;
      if (line.startsWith('+')) {
        added++;
        segments.add(
          KitDiffLine(line.substring(1), KitDiffLineKind.added, newNo: newNo++),
        );
      } else if (line.startsWith('-')) {
        removed++;
        segments.add(
          KitDiffLine(
            line.substring(1),
            KitDiffLineKind.removed,
            oldNo: oldNo++,
          ),
        );
      } else if (line.startsWith('\\')) {
        // "\ No newline at end of file": a note about the line above, not
        // a line of either file.
        continue;
      } else {
        if (line.isEmpty) continue;
        final text = line.startsWith(' ') ? line.substring(1) : line;
        segments.add(
          KitDiffLine(
            text,
            KitDiffLineKind.context,
            oldNo: oldNo++,
            newNo: newNo++,
          ),
        );
      }
    }
    return KitDiffFile(
      path: path,
      segments: _collapseContext(segments),
      added: added,
      removed: removed,
      status: status ?? KitDiffFileStatus.modified,
      oldPath: oldPath,
      patch: patch,
    );
  }

  /// Diffs a before/after pair (either may be null: added or deleted).
  factory KitDiffFile.fromTexts(
    String path, {
    String? before,
    String? after,
    KitDiffFileStatus? status,
  }) {
    final resolved =
        status ??
        (before == null && after != null
            ? KitDiffFileStatus.added
            : after == null && before != null
            ? KitDiffFileStatus.deleted
            : KitDiffFileStatus.modified);
    final a = before == null || before.isEmpty
        ? const <String>[]
        : _splitLines(before);
    final b = after == null || after.isEmpty
        ? const <String>[]
        : _splitLines(after);
    final lines = _lineDiff(a, b);
    var added = 0;
    var removed = 0;
    for (final line in lines) {
      if (line.kind == KitDiffLineKind.added) added++;
      if (line.kind == KitDiffLineKind.removed) removed++;
    }
    return KitDiffFile(
      path: path,
      segments: _collapseContext(lines),
      added: added,
      removed: removed,
      status: resolved,
      fullText: after,
    );
  }

  final String path;

  /// [KitDiffLine] and [KitDiffGap] entries in file order.
  final List<Object> segments;
  final int added, removed;
  final KitDiffFileStatus status;
  final String? oldPath, fullText, patch;
  final bool binary;

  /// The number of changes (runs of added/removed lines) in this file.
  int get changeCount => _FileIndex.of(this).changes.length;

  static final _hunkHeader = RegExp(
    r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
  );
}

/// Context lines kept visible on each side of a change before the rest of a
/// run folds into a gap.
const int _visibleContext = 3;

/// Above this many cells the line diff falls back to one changed block
/// (the common prefix and suffix stay context): a quadratic table on the UI
/// thread is worse than a coarser diff.
const int _lcsCellLimit = 1000000;

List<String> _splitLines(String text) {
  final trimmed = text.endsWith('\n')
      ? text.substring(0, text.length - 1)
      : text;
  return trimmed.split('\n');
}

/// A line diff of [a] against [b]: common prefix and suffix, then a longest
/// common subsequence of the middle (a single removed-then-added block when
/// the middle is too large to compare line by line).
List<KitDiffLine> _lineDiff(List<String> a, List<String> b) {
  var p = 0;
  while (p < a.length && p < b.length && a[p] == b[p]) {
    p++;
  }
  var s = 0;
  while (s < a.length - p &&
      s < b.length - p &&
      a[a.length - 1 - s] == b[b.length - 1 - s]) {
    s++;
  }
  final out = <KitDiffLine>[
    for (var i = 0; i < p; i++)
      KitDiffLine(a[i], KitDiffLineKind.context, oldNo: i + 1, newNo: i + 1),
  ];
  final n = a.length - p - s;
  final m = b.length - p - s;
  if (n > 0 && m > 0 && (n + 1) * (m + 1) <= _lcsCellLimit) {
    // table[i][j]: LCS length of a[p+i..] and b[p+j..].
    final width = m + 1;
    final table = Int32List((n + 1) * width);
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        table[i * width + j] = a[p + i] == b[p + j]
            ? table[(i + 1) * width + j + 1] + 1
            : math.max(table[(i + 1) * width + j], table[i * width + j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    final removed = <KitDiffLine>[];
    final added = <KitDiffLine>[];
    void flush() {
      out
        ..addAll(removed)
        ..addAll(added);
      removed.clear();
      added.clear();
    }

    while (i < n || j < m) {
      if (i < n && j < m && a[p + i] == b[p + j]) {
        flush();
        out.add(
          KitDiffLine(
            a[p + i],
            KitDiffLineKind.context,
            oldNo: p + i + 1,
            newNo: p + j + 1,
          ),
        );
        i++;
        j++;
      } else if (j < m &&
          (i >= n || table[i * width + j + 1] >= table[(i + 1) * width + j])) {
        added.add(
          KitDiffLine(b[p + j], KitDiffLineKind.added, newNo: p + j + 1),
        );
        j++;
      } else {
        removed.add(
          KitDiffLine(a[p + i], KitDiffLineKind.removed, oldNo: p + i + 1),
        );
        i++;
      }
    }
    flush();
  } else {
    for (var i = p; i < a.length - s; i++) {
      out.add(KitDiffLine(a[i], KitDiffLineKind.removed, oldNo: i + 1));
    }
    for (var j = p; j < b.length - s; j++) {
      out.add(KitDiffLine(b[j], KitDiffLineKind.added, newNo: j + 1));
    }
  }
  for (var k = 0; k < s; k++) {
    final ai = a.length - s + k;
    final bi = b.length - s + k;
    out.add(
      KitDiffLine(a[ai], KitDiffLineKind.context, oldNo: ai + 1, newNo: bi + 1),
    );
  }
  return out;
}

/// Folds long runs of context into gaps, keeping [_visibleContext] lines
/// next to each change so the reader still sees where they are.
List<Object> _collapseContext(List<Object> segments) {
  final out = <Object>[];
  var run = <KitDiffLine>[];
  void flush({required bool atStart, required bool atEnd}) {
    if (run.isEmpty) return;
    final keepTop = atStart ? 0 : _visibleContext;
    final keepBottom = atEnd ? 0 : _visibleContext;
    if (run.length <= keepTop + keepBottom + 1) {
      out.addAll(run);
    } else {
      out.addAll(run.take(keepTop));
      out.add(
        KitDiffGap(
          count: run.length - keepTop - keepBottom,
          lines: List.unmodifiable(
            run.sublist(keepTop, run.length - keepBottom),
          ),
        ),
      );
      out.addAll(run.skip(run.length - keepBottom));
    }
    run = <KitDiffLine>[];
  }

  var seenChange = false;
  for (final segment in segments) {
    if (segment is KitDiffLine && segment.kind == KitDiffLineKind.context) {
      run.add(segment);
      continue;
    }
    // A patch gap or hunk header ends a run like a change does, but only a
    // change keeps context around itself.
    final isChange =
        segment is KitDiffLine &&
        (segment.kind == KitDiffLineKind.added ||
            segment.kind == KitDiffLineKind.removed);
    flush(atStart: !seenChange, atEnd: !isChange);
    if (isChange) seenChange = true;
    out.add(segment);
  }
  flush(atStart: !seenChange, atEnd: true);
  return List.unmodifiable(out);
}

/// Derived facts about one file, computed once per [KitDiffFile] instance.
class _FileIndex {
  _FileIndex(KitDiffFile file) {
    var inRun = false;
    for (var i = 0; i < file.segments.length; i++) {
      final segment = file.segments[i];
      if (segment is KitDiffLine) {
        if (segment.kind != KitDiffLineKind.hunk) total++;
        for (final n in [segment.oldNo, segment.newNo]) {
          if (n != null && n > maxNumber) maxNumber = n;
        }
        if (segment.text.length > longest.length) longest = segment.text;
        final change =
            segment.kind == KitDiffLineKind.added ||
            segment.kind == KitDiffLineKind.removed;
        if (change && !inRun) changes.add(i);
        inRun = change;
        allLines.add(segment);
      } else if (segment is KitDiffGap) {
        inRun = false;
        total += segment.count;
        for (final line in segment.lines ?? const <KitDiffLine>[]) {
          for (final n in [line.oldNo, line.newNo]) {
            if (n != null && n > maxNumber) maxNumber = n;
          }
          if (line.text.length > longest.length) longest = line.text;
          allLines.add(line);
        }
      }
    }
  }

  /// Segment index where each change starts.
  final List<int> changes = [];
  final List<KitDiffLine> allLines = [];
  int total = 0;
  int maxNumber = 1;
  String longest = '';

  static final _cache = Expando<_FileIndex>();
  static _FileIndex of(KitDiffFile file) => _cache[file] ??= _FileIndex(file);
}

enum KitDiffMode {
  unified,

  /// Side by side. Used only where the diff's own box is expanded or wider
  /// (KitLayout.windowFor(width) >= KitWindow.expanded); narrower, it
  /// renders unified.
  split,
}

enum KitDiffSide { old, current }

/// Selected lines, in one file and one side.
@immutable
class KitDiffSelection {
  const KitDiffSelection({
    required this.file,
    required this.side,
    required this.startLine,
    required this.endLine,
    required this.text,
  });

  final KitDiffFile file;
  final KitDiffSide side;

  /// That side's line numbers.
  final int startLine, endLine;

  /// The selected lines, redacted.
  final String text;
}

/// The one diff renderer (K2 §1.15): unified on a phone, side by side from
/// an expanded box, one file header, one "Change 1 of N" navigator across
/// files, and (when a handler is passed) line selection for Comment, Add to
/// prompt and Copy lines. The diff itself is always left to right.
///
/// States: loading, empty, error, loaded, binary, renamed, too-big,
/// selecting.
class KitDiffView extends StatefulWidget {
  const KitDiffView({
    super.key,
    required this.files,
    this.mode,
    this.initialFile,
    this.initialChange,
    this.readOnly = true,
    this.onComment,
    this.onAddToPrompt,
    this.fileActions,
    this.maxLines,
    this.onOpenAll,
    this.loading = false,
    this.error,
    this.onRetry,
    this.wrap,
    this.onWrapChanged,
    this.keyPrefix = 'kit-diff',
  }) : assert(readOnly || onComment != null || onAddToPrompt != null),
       assert(error == null || onRetry != null);

  final List<KitDiffFile> files;

  /// Null: unified below expanded, split from expanded.
  final KitDiffMode? mode;

  /// [initialFile] indexes [files]; [initialChange] is 0-based across all
  /// files; [maxLines] caps a preview (null: no cap, virtualised).
  final int? initialFile, initialChange, maxLines;

  /// [readOnly] true: no selection, no Comment / Add to prompt.
  final bool readOnly, loading;
  final ValueChanged<KitDiffSelection>? onComment, onAddToPrompt;

  /// The file header's "More" menu (Copy file, Copy patch, Ask about this
  /// file, …). Copies in it are the host's, verbatim (SEC-13).
  final List<KitMenuItem> Function(KitDiffFile file)? fileActions;
  final VoidCallback? onOpenAll, onRetry;

  /// A failure in words; the part shows it with Try again.
  final String? error;

  /// Null: wrap on compact, scroll sideways from medium.
  final bool? wrap;
  final ValueChanged<bool>? onWrapChanged;

  /// Internal keys are `<prefix>-…` (the DiffView wrapper passes 'diff').
  final String keyPrefix;

  /// Unchanged lines revealed per tap on a gap bar.
  static const int expandStep = 20;

  @override
  State<KitDiffView> createState() => _KitDiffViewState();
}

/// Opens a read-only diff as a page (KitPageRoute, Close at the end),
/// titled by what it shows ("Changes in this reply"), never a sheet on a
/// sheet. Returns when it closes.
Future<void> showKitDiff(
  BuildContext context, {
  required String title,
  required List<KitDiffFile> files,
  int? initialFile,
  bool? wrap,
  ValueChanged<bool>? onWrapChanged,
}) => pushKitPage<void>(
  context,
  (context) => _KitDiffPage(
    title: title,
    files: files,
    initialFile: initialFile,
    wrap: wrap,
    onWrapChanged: onWrapChanged,
  ),
  fullscreenDialog: true,
);

class _KitDiffPage extends StatelessWidget {
  const _KitDiffPage({
    required this.title,
    required this.files,
    this.initialFile,
    this.wrap,
    this.onWrapChanged,
  });

  final String title;
  final List<KitDiffFile> files;
  final int? initialFile;
  final bool? wrap;
  final ValueChanged<bool>? onWrapChanged;

  @override
  Widget build(BuildContext context) {
    final roles = KitTokens.of(context).roles;
    return Scaffold(
      backgroundColor: roles.ground,
      body: SafeArea(
        bottom: false,
        child: KitScreen(
          header: [KitTopBar(title: title, exit: KitTopBarExit.close)],
          body: KitDiffView(
            files: files,
            initialFile: initialFile,
            wrap: wrap,
            onWrapChanged: onWrapChanged,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Render items

sealed class _Item {
  const _Item(this.seg);

  /// The first segment this item shows.
  final int seg;
}

/// A unified line.
class _LineItem extends _Item {
  const _LineItem(super.seg, this.line);
  final KitDiffLine line;
}

/// A split row: the old side's line and the current side's.
class _PairItem extends _Item {
  const _PairItem(super.seg, this.old, this.current);
  final KitDiffLine? old, current;
}

class _HunkItem extends _Item {
  const _HunkItem(super.seg, this.line);
  final KitDiffLine line;
}

class _GapItem extends _Item {
  const _GapItem(super.seg, this.gap);
  final KitDiffGap gap;
}

List<_Item> _itemsFor(KitDiffFile file, {required bool split}) {
  final out = <_Item>[];
  final segments = file.segments;
  var i = 0;
  while (i < segments.length) {
    final segment = segments[i];
    if (segment is KitDiffGap) {
      out.add(_GapItem(i, segment));
      i++;
      continue;
    }
    if (segment is! KitDiffLine) {
      i++;
      continue;
    }
    if (segment.kind == KitDiffLineKind.hunk) {
      out.add(_HunkItem(i, segment));
      i++;
      continue;
    }
    if (!split) {
      out.add(_LineItem(i, segment));
      i++;
      continue;
    }
    if (segment.kind == KitDiffLineKind.context) {
      out.add(_PairItem(i, segment, segment));
      i++;
      continue;
    }
    // A change: its removed lines face its added lines, row by row.
    final removed = <(int, KitDiffLine)>[];
    final added = <(int, KitDiffLine)>[];
    while (i < segments.length) {
      final s = segments[i];
      if (s is KitDiffLine && s.kind == KitDiffLineKind.removed) {
        if (added.isNotEmpty) break;
        removed.add((i, s));
      } else if (s is KitDiffLine && s.kind == KitDiffLineKind.added) {
        added.add((i, s));
      } else {
        break;
      }
      i++;
    }
    final rows = math.max(removed.length, added.length);
    for (var r = 0; r < rows; r++) {
      final left = r < removed.length ? removed[r] : null;
      final right = r < added.length ? added[r] : null;
      out.add(_PairItem((left ?? right)!.$1, left?.$2, right?.$2));
    }
  }
  return out;
}

/// The line geometry shared by every row of one build.
class _Geometry {
  const _Geometry({
    required this.number,
    required this.glyph,
    required this.lineHeight,
    required this.wrap,
    required this.split,
    required this.selectable,
    required this.textWidth,
  });

  /// One line-number cell.
  final double number;

  /// The `+` / `−` column.
  final double glyph;
  final double lineHeight;
  final bool wrap, split, selectable;

  /// The text column's width when lines scroll sideways (null: wrapping).
  final double? textWidth;

  /// Where the text column starts: the number cells and the glyph.
  double get indent => (split ? number : number + number) + glyph;
}

class _KitDiffViewState extends State<KitDiffView> {
  late int _file;
  late int _change;
  bool? _wrap;
  final ScrollController _lines = ScrollController();
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'KitDiffView lines');

  /// Lines revealed from the top / bottom of each gap, keyed by segment
  /// index in the current file.
  final Map<int, int> _shownTop = {};
  final Map<int, int> _shownBottom = {};

  // Selection: one side, an anchor and an extent (that side's numbers).
  KitDiffSide? _side;
  int? _anchor;
  int? _extent;

  /// Built line-number cells, for drag selection.
  final Map<(KitDiffSide, int), BuildContext> _cells = {};

  /// The item the navigator last moved to: keyed, so it can be revealed
  /// precisely once it is built.
  int? _targetItem;
  final GlobalKey _targetKey = GlobalKey();

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  /// (file, segment) of every change, in order across files.
  List<(int, int)> get _changes => [
    for (var f = 0; f < widget.files.length; f++)
      for (final seg in _FileIndex.of(widget.files[f]).changes) (f, seg),
  ];

  @override
  void initState() {
    super.initState();
    _file = (widget.initialFile ?? 0).clamp(
      0,
      math.max(0, widget.files.length - 1),
    );
    final changes = _changes;
    if (widget.initialChange != null && changes.isNotEmpty) {
      _change = widget.initialChange!.clamp(0, changes.length - 1);
      _file = changes[_change].$1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealChange(animate: false);
      });
    } else {
      final first = changes.indexWhere((c) => c.$1 == _file);
      _change = math.max(0, first);
    }
  }

  @override
  void didUpdateWidget(KitDiffView old) {
    super.didUpdateWidget(old);
    if (widget.files.length != old.files.length) {
      _file = _file.clamp(0, math.max(0, widget.files.length - 1));
      _change = _change.clamp(0, math.max(0, _changes.length - 1));
    }
    if (widget.readOnly && !old.readOnly) _clearSelection();
  }

  @override
  void dispose() {
    _lines.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Wrap

  bool _effectiveWrap(KitWindow window) =>
      widget.wrap ?? _wrap ?? window == KitWindow.compact;

  void _toggleWrap(KitWindow window) {
    final next = !_effectiveWrap(window);
    setState(() => _wrap = next);
    widget.onWrapChanged?.call(next);
  }

  // -------------------------------------------------------------------------
  // Files and changes

  void _openFile(int index) {
    if (index == _file) return;
    setState(() {
      _file = index;
      _shownTop.clear();
      _shownBottom.clear();
      _targetItem = null;
      _clearSelectionState();
      final first = _changes.indexWhere((c) => c.$1 == index);
      if (first >= 0) _change = first;
    });
    if (_lines.hasClients) _lines.jumpTo(0);
  }

  void _goToChange(int index) {
    final changes = _changes;
    if (index < 0 || index >= changes.length) return;
    final (file, _) = changes[index];
    setState(() {
      if (file != _file) {
        _file = file;
        _shownTop.clear();
        _shownBottom.clear();
        _clearSelectionState();
      }
      _change = index;
    });
    _bodyFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealChange(animate: !KitMotion.reduced(context));
    });
  }

  /// Scrolls to the current change: first to an estimate from the known
  /// row heights (the row may not be built yet), then precisely once built.
  void _revealChange({required bool animate}) {
    final changes = _changes;
    if (changes.isEmpty || !_lines.hasClients) return;
    final (_, seg) = changes[_change];
    final items = _currentItems(split: _lastSplit);
    final index = items.indexWhere((item) => item.seg == seg);
    if (index < 0) return;
    setState(() => _targetItem = index);
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _estimateExtent(items[i]);
    }
    final position = _lines.position;
    final target = (offset - 2 * _lastLineHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    void settle() {
      if (!mounted) return;
      final ctx = _targetKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: .2, duration: Duration.zero);
      }
    }

    if (animate) {
      _lines
          .animateTo(
            target,
            duration: KitMotion.standard,
            curve: KitMotion.emphasized,
          )
          .then((_) => settle());
    } else {
      _lines.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) => settle());
    }
  }

  bool _lastSplit = false;
  double _lastLineHeight = 19;
  double _lastBarHeight = 48;

  double _estimateExtent(_Item item) => switch (item) {
    _LineItem() || _PairItem() => math.max(
      _lastLineHeight,
      widget.readOnly ? 0 : _lastBarHeight,
    ),
    _HunkItem() => _lastLineHeight + 8,
    _GapItem(:final gap, :final seg) =>
      _lastBarHeight * (gap.lines == null ? 1 : 2) +
          ((_shownTop[seg] ?? 0) + (_shownBottom[seg] ?? 0)) * _lastLineHeight,
  };

  List<_Item> _currentItems({required bool split}) =>
      _itemsFor(widget.files[_file], split: split);

  // -------------------------------------------------------------------------
  // Selection

  bool get _selecting => !widget.readOnly && _side != null;

  void _clearSelectionState() {
    _side = null;
    _anchor = null;
    _extent = null;
  }

  void _clearSelection() => setState(_clearSelectionState);

  void _select(KitDiffSide side, int line, {bool extend = false}) {
    if (widget.readOnly) return;
    // The keyboard follows the selection: Shift+Up/Down, Enter, Esc, Ctrl+C.
    _bodyFocus.requestFocus();
    setState(() {
      if (extend && _side == side && _anchor != null) {
        _extent = line;
      } else {
        _side = side;
        _anchor = line;
        _extent = line;
      }
    });
  }

  bool _isSelected(KitDiffSide side, int? line) {
    if (!_selecting || _side != side || line == null) return false;
    final lo = math.min(_anchor!, _extent!);
    final hi = math.max(_anchor!, _extent!);
    return line >= lo && line <= hi;
  }

  void _dragTo(KitDiffSide side, Offset global) {
    if (_side != side) return;
    int? best;
    for (final MapEntry(key: (cellSide, n), value: ctx) in _cells.entries) {
      if (cellSide != side || !ctx.mounted) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (global.dy >= top && global.dy < top + box.size.height) {
        best = n;
        break;
      }
    }
    if (best != null && best != _extent) setState(() => _extent = best);
  }

  /// The selected lines of the current file, verbatim.
  String _selectedText() => _selectedLines().join('\n');

  List<String> _selectedLines() {
    final side = _side;
    if (side == null || _anchor == null || _extent == null) return const [];
    final lo = math.min(_anchor!, _extent!);
    final hi = math.max(_anchor!, _extent!);
    final lines = <String>[];
    for (final line in _FileIndex.of(widget.files[_file]).allLines) {
      if (line.kind == KitDiffLineKind.hunk) continue;
      final n = side == KitDiffSide.old ? line.oldNo : line.newNo;
      if (n == null || n < lo || n > hi) continue;
      if (side == KitDiffSide.old && line.kind == KitDiffLineKind.added) {
        continue;
      }
      if (side == KitDiffSide.current && line.kind == KitDiffLineKind.removed) {
        continue;
      }
      lines.add(line.text);
    }
    return lines;
  }

  KitDiffSelection? get _selection {
    if (!_selecting) return null;
    return KitDiffSelection(
      file: widget.files[_file],
      side: _side!,
      startLine: math.min(_anchor!, _extent!),
      endLine: math.max(_anchor!, _extent!),
      text: KitRedact.text(_selectedText()),
    );
  }

  int get _selectedCount => _selectedLines().length;

  void _comment() {
    final selection = _selection;
    if (selection == null || widget.onComment == null) return;
    widget.onComment!(selection);
  }

  void _addToPrompt() {
    final selection = _selection;
    if (selection == null || widget.onAddToPrompt == null) return;
    widget.onAddToPrompt!(selection);
  }

  /// SEC-13: a diff is the person's own content; it copies verbatim.
  Future<void> _copyLines() async {
    if (!_selecting) return;
    await KitCopy.copy(context, _selectedText(), redact: false);
  }

  Future<void> _lineMenu(
    KitDiffSide side,
    int line,
    Offset position,
    BuildContext anchor,
  ) async {
    if (widget.readOnly) return;
    if (!_isSelected(side, line)) _select(side, line);
    final l10n = _l10n;
    await showKitMenu(
      anchor,
      position: position,
      items: [
        if (widget.onComment != null)
          KitMenuItem(label: l10n.kitDiffComment, onSelected: _comment),
        if (widget.onAddToPrompt != null)
          KitMenuItem(label: l10n.kitDiffAddToPrompt, onSelected: _addToPrompt),
        KitMenuItem(
          label: l10n.kitDiffCopyLines,
          icon: AppIconography.copy,
          onSelected: _copyLines,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Keyboard (LAY-10)

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final shift = keyboard.isShiftPressed;
    final control = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (control && key == LogicalKeyboardKey.keyC && _selecting) {
      _copyLines();
      return KeyEventResult.handled;
    }
    if (control || keyboard.isAltPressed) return KeyEventResult.ignored;
    if ((key == LogicalKeyboardKey.keyN && !shift) ||
        (key == LogicalKeyboardKey.f7 && !shift)) {
      _goToChange(_change + 1);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.keyP && !shift) ||
        (key == LogicalKeyboardKey.f7 && shift)) {
      _goToChange(_change - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _selecting) {
      _clearSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter &&
        _selecting &&
        widget.onComment != null) {
      _comment();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final down = key == LogicalKeyboardKey.arrowDown;
      if (shift && _selecting) {
        setState(() => _extent = math.max(1, _extent! + (down ? 1 : -1)));
        return KeyEventResult.handled;
      }
      if (_lines.hasClients) {
        final position = _lines.position;
        _lines.jumpTo(
          (position.pixels + (down ? _lastLineHeight : -_lastLineHeight)).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = _l10n;
    if (widget.loading) return _loading(tokens);
    if (widget.error != null) {
      return KitStateView.error(
        title: l10n.kitDiffLoadFailed,
        body: widget.error,
        size: KitStateSize.inline,
        retry: KitAction(label: l10n.kitTryAgain, onPressed: widget.onRetry),
      );
    }
    if (widget.files.isEmpty) {
      return KitStateView(
        icon: AppIconography.checks,
        title: l10n.kitDiffNoChanges,
        size: KitStateSize.inline,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final window = KitLayout.windowFor(width);
        final bounded = constraints.maxHeight.isFinite;
        final showList = window == KitWindow.large && widget.files.length > 1;
        final diffWidth = showList
            ? width - KitLayout.paneListWidth - tokens.space3
            : width;
        final split =
            (widget.mode ?? KitDiffMode.split) == KitDiffMode.split &&
            KitLayout.windowFor(diffWidth).isWide;
        final wrap = _effectiveWrap(window);
        final column = _diffColumn(
          context,
          tokens,
          l10n,
          width: diffWidth,
          window: window,
          split: split,
          wrap: wrap,
          bounded: bounded,
          picker: !showList,
          fileList: showList ? _fileList(tokens, bounded: bounded) : null,
        );
        return column;
      },
    );
  }

  Widget _loading(KitTokens tokens) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        height: tokens.rowHeight,
        decoration: BoxDecoration(
          color: tokens.roles.surface1,
          border: Border(
            bottom: BorderSide(
              color: tokens.roles.hairline,
              width: KitTokens.hairlineWidth(context),
            ),
          ),
        ),
      ),
      const KitSkeletonRows(count: 6),
    ],
  );

  String _statusLine(KitDiffFile file, AppLocalizations l10n) =>
      switch (file.status) {
        KitDiffFileStatus.renamed when file.oldPath != null =>
          l10n.kitDiffRenamed(KitBidi.ltr(file.oldPath!)),
        KitDiffFileStatus.added => l10n.kitDiffAddedFile,
        KitDiffFileStatus.deleted => l10n.kitDiffDeletedFile,
        _ => '',
      };

  String _baseName(String path) => path.split('/').last;

  String _directory(String path) {
    final parts = path.split('/');
    return parts.length > 1
        ? '${parts.sublist(0, parts.length - 1).join('/')}/'
        : '';
  }

  Widget _fileList(KitTokens tokens, {required bool bounded}) {
    final roles = tokens.roles;
    final l10n = _l10n;
    final list = KitChoiceList<int>.single(
      semanticsLabel: l10n.kitDiffFiles(widget.files.length),
      choices: [
        for (var i = 0; i < widget.files.length; i++)
          KitChoice(
            key: ValueKey('${widget.keyPrefix}-file-row-$i'),
            value: i,
            title: KitBidi.ltr(widget.files[i].path),
            supporting: [
              '+${widget.files[i].added} −${widget.files[i].removed}',
              _statusLine(widget.files[i], l10n),
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
      ],
      selected: _file,
      onSelected: _openFile,
    );
    return DecoratedBox(
      key: ValueKey('${widget.keyPrefix}-file-list'),
      decoration: BoxDecoration(
        color: roles.surface1,
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: bounded
          ? SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: tokens.space2),
              child: list,
            )
          : Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.space2),
              child: list,
            ),
    );
  }

  Widget _diffColumn(
    BuildContext context,
    KitTokens tokens,
    AppLocalizations l10n, {
    required double width,
    required KitWindow window,
    required bool split,
    required bool wrap,
    required bool bounded,
    required bool picker,
    Widget? fileList,
  }) {
    final file = widget.files[_file];
    final header = _header(context, tokens, l10n, file, window, wrap, picker);
    Widget body;
    Widget? footer;
    if (file.binary) {
      final message = KitText(
        l10n.kitDiffBinary,
        role: KitTextRole.secondary,
        tone: KitTextTone.secondary,
      );
      // The message names the whole body, so a screen reader moves from
      // the header (or the file list) into it in order (A11Y-4).
      body = Semantics(
        container: true,
        label: l10n.kitDiffBinary,
        excludeSemantics: true,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: EdgeInsets.all(tokens.gutter),
            child: message,
          ),
        ),
      );
    } else {
      final (lines, capped) = _linesView(
        context,
        tokens,
        file: file,
        width: width,
        split: split,
        wrap: wrap,
        bounded: bounded,
      );
      body = lines;
      if (capped != null) {
        footer = _tooBig(tokens, l10n, capped.$1, capped.$2);
      }
    }
    final selection = _selecting ? _selectionBar(tokens, l10n) : null;
    final linesColumn = Column(
      mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bounded) Expanded(child: body) else body,
        ?footer,
        ?selection,
      ],
    );
    // A large box: the header spans the top, the file list sits at the
    // start of the lines (read after the header, top to bottom, A11Y-4).
    final Widget main = fileList == null
        ? linesColumn
        : Row(
            crossAxisAlignment: bounded
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              SizedBox(width: KitLayout.paneListWidth, child: fileList),
              SizedBox(width: tokens.space3),
              Expanded(child: linesColumn),
            ],
          );
    return Column(
      mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (bounded) Expanded(child: main) else main,
      ],
    );
  }

  Widget _header(
    BuildContext context,
    KitTokens tokens,
    AppLocalizations l10n,
    KitDiffFile file,
    KitWindow window,
    bool wrap,
    bool picker,
  ) {
    final roles = tokens.roles;
    final status = _statusLine(file, l10n);
    final multi = widget.files.length > 1;
    final counts = Semantics(
      label: l10n.kitDiffCounts(file.added, file.removed),
      excludeSemantics: true,
      child: _Counts(added: file.added, removed: file.removed),
    );

    final Widget title;
    if (multi && picker) {
      title = KitPickerRow<int>(
        rowKey: ValueKey('${widget.keyPrefix}-file-picker'),
        title: l10n.kitDiffFiles(widget.files.length),
        valueLabel: _baseName(file.path),
        supporting: [
          '+${file.added} −${file.removed}',
          status,
        ].where((s) => s.isNotEmpty).join(' · '),
        choices: [
          for (var i = 0; i < widget.files.length; i++)
            KitChoice(
              value: i,
              title: KitBidi.ltr(widget.files[i].path),
              supporting: [
                '+${widget.files[i].added} −${widget.files[i].removed}',
                _statusLine(widget.files[i], l10n),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
        ],
        selected: _file,
        onSelected: _openFile,
      );
    } else {
      final directory = _directory(file.path);
      final supporting = [
        if (directory.isNotEmpty) KitBidi.ltr(directory),
        status,
      ].where((s) => s.isNotEmpty).join(' · ');
      title = Padding(
        padding: EdgeInsetsDirectional.only(
          start: tokens.gutter,
          top: tokens.space2,
          end: tokens.gutter,
        ),
        child: Semantics(
          container: true,
          label: [
            file.path,
            l10n.kitDiffCounts(file.added, file.removed),
            if (status.isNotEmpty) status,
          ].join(', '),
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      KitBidi.ltr(_baseName(file.path)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.rowTitle.copyWith(color: roles.text1),
                    ),
                    if (supporting.isNotEmpty)
                      KitText(
                        supporting,
                        role: KitTextRole.secondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space3),
              counts,
            ],
          ),
        ),
      );
    }

    final changes = _changes;
    final more = widget.fileActions?.call(file) ?? const <KitMenuItem>[];
    final tools = Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.space1),
      child: Row(
        children: [
          if (changes.isNotEmpty) ...[
            KitIconButton(
              key: ValueKey('${widget.keyPrefix}-nav-previous'),
              icon: AppIconography.chevronUp,
              tooltip: l10n.kitDiffPreviousChange,
              shortcut: 'P',
              onPressed: _change > 0 ? () => _goToChange(_change - 1) : null,
            ),
            KitIconButton(
              key: ValueKey('${widget.keyPrefix}-nav-next'),
              icon: AppIconography.chevronDown,
              tooltip: l10n.kitDiffNextChange,
              shortcut: 'N',
              onPressed: _change < changes.length - 1
                  ? () => _goToChange(_change + 1)
                  : null,
            ),
            SizedBox(width: tokens.space1),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: KitText(
                  key: ValueKey('${widget.keyPrefix}-nav-label'),
                  l10n.kitDiffChangeOf(_change + 1, changes.length),
                  role: KitTextRole.caption,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (!file.binary)
            KitIconButton(
              icon: AppIconography.wrapText,
              tooltip: l10n.kitWrapLines,
              selected: wrap,
              onPressed: () => _toggleWrap(window),
            ),
          if (more.isNotEmpty)
            Builder(
              builder: (anchor) => KitIconButton(
                icon: AppIconography.more,
                tooltip: l10n.kitMore,
                onPressed: () =>
                    showKitMenu(anchor, items: more, semanticsLabel: file.path),
              ),
            ),
        ],
      ),
    );

    return Container(
      key: ValueKey('${widget.keyPrefix}-file-header-${file.path}'),
      decoration: BoxDecoration(
        color: roles.surface1,
        border: Border(
          bottom: BorderSide(
            color: roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, tools],
      ),
    );
  }

  Widget _tooBig(
    KitTokens tokens,
    AppLocalizations l10n,
    int shown,
    int total,
  ) => Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      tokens.gutter,
      tokens.space2,
      tokens.gutter,
      tokens.space2,
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.space3,
      runSpacing: tokens.space1,
      children: [
        KitText(l10n.kitDiffTooBig(shown, total), role: KitTextRole.secondary),
        if (widget.onOpenAll != null)
          KitButton.tertiary(
            key: ValueKey('${widget.keyPrefix}-open-all'),
            label: l10n.kitDiffOpenAll,
            onPressed: widget.onOpenAll,
          ),
      ],
    ),
  );

  Widget _selectionBar(KitTokens tokens, AppLocalizations l10n) {
    final roles = tokens.roles;
    final count = Semantics(
      liveRegion: true,
      child: KitText(
        l10n.kitDiffSelected(_selectedCount),
        role: KitTextRole.label,
      ),
    );
    final clear = KitIconButton(
      icon: AppIconography.close,
      tooltip: l10n.kitDiffClearSelection,
      shortcut: 'Esc',
      onPressed: _clearSelection,
    );
    final actions = KitActionBlock(
      primary: widget.onComment == null
          ? null
          : KitAction(label: l10n.kitDiffComment, onPressed: _comment),
      tertiary: [
        if (widget.onAddToPrompt != null)
          KitAction(label: l10n.kitDiffAddToPrompt, onPressed: _addToPrompt),
        KitAction(
          label: l10n.kitDiffCopyLines,
          icon: AppIconography.copy,
          onPressed: _copyLines,
        ),
      ],
    );
    // Compact: the count and Clear, then the stacked actions. Wider: one
    // line read start to end, count, actions, Clear (A11Y-4).
    final compact = KitLayout.windowOf(context) == KitWindow.compact;
    final Widget content = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: count),
                  clear,
                ],
              ),
              SizedBox(height: tokens.space1),
              Padding(
                padding: EdgeInsetsDirectional.only(end: tokens.space3),
                child: actions,
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: count),
              SizedBox(width: tokens.space3),
              Flexible(flex: 3, child: actions),
              SizedBox(width: tokens.space2),
              clear,
            ],
          );
    return Container(
      key: ValueKey('${widget.keyPrefix}-selection-bar'),
      decoration: BoxDecoration(
        color: roles.surface1,
        border: Border(
          top: BorderSide(
            color: roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space1,
        tokens.space1,
        tokens.space2,
      ),
      child: content,
    );
  }

  /// The lines of [file], and (shown, total) when [KitDiffView.maxLines]
  /// cut them short.
  (Widget, (int, int)?) _linesView(
    BuildContext context,
    KitTokens tokens, {
    required KitDiffFile file,
    required double width,
    required bool split,
    required bool wrap,
    required bool bounded,
  }) {
    final index = _FileIndex.of(file);
    final mono = KitText.styleOf(context, KitTextRole.mono);
    final scaler = MediaQuery.textScalerOf(context);
    final digits = index.maxNumber.toString().length;
    final digitPainter = TextPainter(
      text: TextSpan(text: '0' * digits, style: mono),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final lineHeight = digitPainter.height;
    final numberWidth = (digitPainter.width + tokens.space2 * 1.5)
        .ceilToDouble();
    digitPainter.dispose();
    final glyphWidth = (scaler.scale(mono.fontSize ?? 13) + tokens.space1)
        .ceilToDouble();
    _lastSplit = split;
    _lastLineHeight = lineHeight;
    _lastBarHeight = tokens.minTarget;

    final gutter = (split ? numberWidth : numberWidth * 2) + glyphWidth;
    double? textWidth;
    var contentWidth = width;
    if (!wrap) {
      final painter = TextPainter(
        text: TextSpan(text: index.longest, style: mono),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final longest = painter.width.ceilToDouble() + tokens.space4;
      painter.dispose();
      final divider = KitTokens.hairlineWidth(context);
      if (split) {
        final half = math.max((width - divider) / 2, gutter + longest);
        textWidth = half - gutter;
        contentWidth = half * 2 + divider;
      } else {
        textWidth = math.max(width - gutter, longest);
        contentWidth = gutter + textWidth;
      }
    }
    final geometry = _Geometry(
      number: numberWidth,
      glyph: glyphWidth,
      lineHeight: lineHeight,
      wrap: wrap,
      split: split,
      selectable: !widget.readOnly,
      textWidth: textWidth,
    );

    var items = _currentItems(split: split);
    (int, int)? capped;
    final maxLines = widget.maxLines;
    if (maxLines != null) {
      var rows = 0;
      var cut = items.length;
      for (var i = 0; i < items.length; i++) {
        if (items[i] is _LineItem || items[i] is _PairItem) rows++;
        if (rows > maxLines) {
          cut = i;
          break;
        }
      }
      if (cut < items.length) {
        items = items.sublist(0, cut);
        capped = (maxLines, index.total);
      }
    }

    Widget itemAt(BuildContext context, int i) {
      final item = items[i];
      final child = _itemView(context, tokens, item, geometry);
      if (i == _targetItem) {
        return KeyedSubtree(key: _targetKey, child: child);
      }
      return child;
    }

    Widget list = ListView.builder(
      controller: bounded ? _lines : null,
      shrinkWrap: !bounded,
      physics: bounded ? null : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: tokens.space4),
      itemCount: items.length,
      itemBuilder: itemAt,
    );
    list = SelectionArea(child: list);
    if (!wrap) {
      list = SingleChildScrollView(
        key: ValueKey('${widget.keyPrefix}-horizontal'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: contentWidth, child: list),
      );
    }
    final view = Focus(
      focusNode: _bodyFocus,
      onKeyEvent: _onKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(color: tokens.detailsSurface, child: list),
      ),
    );
    return (view, capped);
  }

  Widget _itemView(
    BuildContext context,
    KitTokens tokens,
    _Item item,
    _Geometry g,
  ) => switch (item) {
    _LineItem(:final line) => _unifiedRow(context, tokens, line, g),
    _PairItem(:final old, :final current) => _splitRow(
      context,
      tokens,
      old,
      current,
      g,
    ),
    _HunkItem(:final line) => _hunkRow(tokens, line, g),
    _GapItem(:final seg, :final gap) => _gapView(context, tokens, seg, gap, g),
  };

  Widget _hunkRow(KitTokens tokens, KitDiffLine line, _Geometry g) {
    final match = KitDiffFile._hunkHeader.firstMatch(line.text);
    var label = line.text;
    if (match != null) {
      final newStart = int.parse(match.group(3)!);
      final newCount = int.parse(match.group(4) ?? '1');
      final oldStart = int.parse(match.group(1)!);
      final oldCount = int.parse(match.group(2) ?? '1');
      final (start, count) = newCount > 0
          ? (newStart, newCount)
          : (oldStart, oldCount);
      label = _l10n.kitDiffLines(start, start + math.max<int>(count, 1) - 1);
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: g.indent,
        top: tokens.space1,
        bottom: tokens.space1,
      ),
      child: KitText(
        label,
        role: KitTextRole.mono,
        tone: KitTextTone.secondary,
      ),
    );
  }

  Color? _tint(ThemeRoles roles, KitDiffLineKind kind) => switch (kind) {
    KitDiffLineKind.added => roles.codeAddedSurface,
    KitDiffLineKind.removed => roles.codeRemovedSurface,
    _ => null,
  };

  String _glyph(KitDiffLineKind kind) => switch (kind) {
    KitDiffLineKind.added => '+',
    KitDiffLineKind.removed => '−',
    _ => '',
  };

  /// "Line 12 added: …", "Line 9 removed: …", "Line 14: …": every line is
  /// read with its number, and a blank line still has a name.
  String _lineLabel(KitDiffLine line, [KitDiffSide? side]) {
    final l10n = _l10n;
    final name = switch (line.kind) {
      KitDiffLineKind.added => l10n.kitDiffLineAdded(line.newNo ?? 0),
      KitDiffLineKind.removed => l10n.kitDiffLineRemoved(line.oldNo ?? 0),
      _ => l10n.kitDiffLine(
        (side == KitDiffSide.old ? line.oldNo : line.newNo) ?? line.oldNo ?? 0,
      ),
    };
    return line.text.trim().isEmpty ? name : '$name: ${line.text}';
  }

  /// The side a line belongs to when its row is selected as a whole.
  KitDiffSide _sideOf(KitDiffLine line) => line.kind == KitDiffLineKind.removed
      ? KitDiffSide.old
      : KitDiffSide.current;

  int? _numberOn(KitDiffLine line, KitDiffSide side) =>
      side == KitDiffSide.old ? line.oldNo : line.newNo;

  Widget _numberCell(KitTokens tokens, KitDiffSide side, int? n, _Geometry g) {
    final roles = tokens.roles;
    final selected = _isSelected(side, n);
    // With selection on, a number is a 48 dp-tall target (A11Y-2).
    final text = Container(
      width: g.number,
      constraints: BoxConstraints(
        minHeight: g.selectable ? tokens.minTarget : 0,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(end: tokens.space1),
        child: Text(
          n?.toString() ?? '',
          textAlign: TextAlign.end,
          style: KitText.styleOf(
            context,
            KitTextRole.mono,
          ).copyWith(color: selected ? roles.accent : roles.text3),
        ),
      ),
    );
    if (!g.selectable || n == null) return text;
    final side0 = side;
    return _NumberCell(
      key: ValueKey('${widget.keyPrefix}-line-$_file-${side.name}-$n'),
      register: (ctx) => _cells[(side0, n)] = ctx,
      unregister: (ctx) {
        if (identical(_cells[(side0, n)], ctx)) _cells.remove((side0, n));
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            _select(side, n, extend: HardwareKeyboard.instance.isShiftPressed),
        onVerticalDragStart: (_) => _select(side, n),
        onVerticalDragUpdate: (details) =>
            _dragTo(side, details.globalPosition),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: selected ? roles.accent : Colors.transparent,
                width: KitTokens.focusRingWidth(context),
              ),
            ),
          ),
          child: text,
        ),
      ),
    );
  }

  Widget _glyphCell(KitTokens tokens, KitDiffLine? line, _Geometry g) {
    final roles = tokens.roles;
    final kind = line?.kind;
    return SizedBox(
      width: g.glyph,
      child: Text(
        kind == null ? '' : _glyph(kind),
        textAlign: TextAlign.center,
        style: KitText.styleOf(context, KitTextRole.mono).copyWith(
          color: switch (kind) {
            KitDiffLineKind.added => roles.success,
            KitDiffLineKind.removed => roles.codeRemoved,
            _ => roles.text3,
          },
        ),
      ),
    );
  }

  Widget _textCell(KitTokens tokens, KitDiffLine? line, _Geometry g) {
    final text = Text(
      line?.text ?? '',
      softWrap: g.wrap,
      overflow: TextOverflow.clip,
      style: KitText.styleOf(
        context,
        KitTextRole.mono,
      ).copyWith(color: tokens.roles.text1),
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(end: tokens.space2),
      child: text,
    );
  }

  Widget _rowFrame({
    required Widget child,
    required String label,
    required Color? tint,
    required bool selected,
    required KitDiffSide side,
    required int? number,
    required _Geometry g,
    required KitTokens tokens,
  }) {
    final roles = tokens.roles;
    final color = selected
        ? Color.alphaBlend(
            roles.accent.withValues(alpha: tokens.markTintAlpha),
            tint ?? tokens.detailsSurface,
          )
        : tint;
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: g.selectable ? tokens.minTarget : 0,
      ),
      child: child,
    );
    // Always a ColoredBox: a row that gains a tint when selected keeps its
    // element tree, so a drag that started on its number is not dropped.
    row = ColoredBox(color: color ?? Colors.transparent, child: row);
    final selectable = g.selectable && number != null;
    row = Semantics(
      container: true,
      label: label,
      selected: g.selectable ? selected : null,
      onTap: selectable ? () => _select(side, number) : null,
      excludeSemantics: true,
      child: row,
    );
    if (!selectable) return row;
    final line = row;
    return Builder(
      builder: (anchor) => GestureDetector(
        // The row's own node carries the select action (above); the
        // right-click menu is a pointer twin of the selection bar.
        excludeFromSemantics: true,
        onSecondaryTapUp: (details) =>
            _lineMenu(side, number, details.globalPosition, anchor),
        child: line,
      ),
    );
  }

  Widget _unifiedRow(
    BuildContext context,
    KitTokens tokens,
    KitDiffLine line,
    _Geometry g,
  ) {
    final side = _sideOf(line);
    final number = _numberOn(line, side);
    final cells = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _numberCell(tokens, KitDiffSide.old, line.oldNo, g),
        _numberCell(tokens, KitDiffSide.current, line.newNo, g),
        _glyphCell(tokens, line, g),
        if (g.textWidth != null)
          SizedBox(width: g.textWidth, child: _textCell(tokens, line, g))
        else
          Expanded(child: _textCell(tokens, line, g)),
      ],
    );
    return _rowFrame(
      child: cells,
      label: _lineLabel(line),
      tint: _tint(tokens.roles, line.kind),
      selected:
          _isSelected(KitDiffSide.old, line.oldNo) ||
          _isSelected(KitDiffSide.current, line.newNo),
      side: side,
      number: number,
      g: g,
      tokens: tokens,
    );
  }

  Widget _half(
    KitTokens tokens,
    KitDiffLine? line,
    KitDiffSide side,
    _Geometry g,
  ) {
    final number = line == null ? null : _numberOn(line, side);
    final cells = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _numberCell(tokens, side, number, g),
        _glyphCell(tokens, line, g),
        Expanded(child: _textCell(tokens, line, g)),
      ],
    );
    if (line == null) return cells;
    return _rowFrame(
      child: cells,
      label: _lineLabel(line, side),
      tint: _tint(tokens.roles, line.kind),
      selected: _isSelected(side, number),
      side: side,
      number: number,
      g: g,
      tokens: tokens,
    );
  }

  Widget _splitRow(
    BuildContext context,
    KitTokens tokens,
    KitDiffLine? old,
    KitDiffLine? current,
    _Geometry g,
  ) {
    final divider = KitTokens.hairlineWidth(context);
    final halfWidth = g.textWidth == null
        ? null
        : g.number + g.glyph + g.textWidth!;
    Widget side(Widget child) => halfWidth == null
        ? Expanded(child: child)
        : SizedBox(width: halfWidth, child: child);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          side(_half(tokens, old, KitDiffSide.old, g)),
          ColoredBox(
            color: tokens.roles.hairline,
            child: SizedBox(width: divider),
          ),
          side(_half(tokens, current, KitDiffSide.current, g)),
        ],
      ),
    );
  }

  Widget _gapView(
    BuildContext context,
    KitTokens tokens,
    int seg,
    KitDiffGap gap,
    _Geometry g,
  ) {
    final l10n = _l10n;
    final lines = gap.lines;
    final top = (_shownTop[seg] ?? 0).clamp(0, gap.count);
    final bottom = (_shownBottom[seg] ?? 0).clamp(0, gap.count - top);
    final remaining = gap.count - top - bottom;
    final expandable = lines != null;
    final step = remaining.clamp(1, KitDiffView.expandStep);
    final indent = g.indent;

    Widget rowsOf(Iterable<KitDiffLine> ls) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in ls)
          g.split
              ? _splitRow(context, tokens, line, line, g)
              : _unifiedRow(context, tokens, line, g),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expandable && top + bottom > 0)
          _GapBar(
            key: ValueKey('${widget.keyPrefix}-collapse-$seg'),
            label: l10n.kitDiffHideUnchanged,
            icon: AppIconography.unfoldLess,
            indent: indent,
            onTap: () => setState(() {
              _shownTop.remove(seg);
              _shownBottom.remove(seg);
            }),
          ),
        KitReveal(
          child: expandable && top > 0 ? rowsOf(lines.take(top)) : null,
        ),
        if (remaining > 0 && expandable && seg > 0)
          _GapBar(
            key: ValueKey('${widget.keyPrefix}-expand-down-$seg'),
            label: l10n.kitDiffShowUnchanged(step),
            icon: AppIconography.chevronDown,
            indent: indent,
            onTap: () =>
                setState(() => _shownTop[seg] = top + KitDiffView.expandStep),
          ),
        if (remaining > 0)
          _GapBar(
            key: ValueKey('${widget.keyPrefix}-gap-$seg'),
            label: expandable
                ? l10n.kitDiffShowUnchanged(step)
                : l10n.kitDiffUnchangedCount(remaining),
            icon: expandable ? AppIconography.chevronUp : null,
            indent: indent,
            onTap: expandable
                ? () => setState(
                    () => _shownBottom[seg] = bottom + KitDiffView.expandStep,
                  )
                : null,
          ),
        KitReveal(
          child: expandable && bottom > 0
              ? rowsOf(lines.skip(gap.count - bottom))
              : null,
        ),
      ],
    );
  }
}

/// A line-number cell that registers its context while built, so a drag
/// over the gutter can find the line under the pointer.
class _NumberCell extends StatefulWidget {
  const _NumberCell({
    super.key,
    required this.register,
    required this.unregister,
    required this.child,
  });

  final void Function(BuildContext context) register;
  final void Function(BuildContext context) unregister;
  final Widget child;

  @override
  State<_NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<_NumberCell> {
  @override
  void initState() {
    super.initState();
    widget.register(context);
  }

  @override
  void didUpdateWidget(_NumberCell old) {
    super.didUpdateWidget(old);
    widget.register(context);
  }

  @override
  void dispose() {
    widget.unregister(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// `+n −n` in the success and removed code roles.
class _Counts extends StatelessWidget {
  const _Counts({required this.added, required this.removed});

  final int added, removed;

  @override
  Widget build(BuildContext context) {
    final roles = KitTokens.of(context).roles;
    final mono = KitText.styleOf(context, KitTextRole.mono);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '+$added',
            style: mono.copyWith(color: roles.success),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: '−$removed',
            style: mono.copyWith(color: roles.codeRemoved),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
  }
}

/// A full-width bar standing in for folded unchanged lines, or offering to
/// reveal or hide them. 48 dp tall; a bar with no [onTap] only states.
class _GapBar extends StatelessWidget {
  const _GapBar({
    super.key,
    required this.label,
    required this.icon,
    required this.indent,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final double indent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final start = math.max(0.0, indent - tokens.smallIconSize - tokens.space2);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.minTarget),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: start, end: tokens.space2),
        child: Row(
          children: [
            SizedBox(
              width: tokens.smallIconSize + tokens.space2,
              child: icon == null
                  ? null
                  : Icon(icon, size: tokens.smallIconSize, color: roles.text2),
            ),
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.space2),
                child: KitText(label, role: KitTextRole.secondary),
              ),
            ),
          ],
        ),
      ),
    );
    final bar = ColoredBox(
      color: roles.surface2,
      child: onTap == null
          ? Semantics(
              container: true,
              label: label,
              excludeSemantics: true,
              child: content,
            )
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
    return Semantics(button: onTap != null, child: bar);
  }
}
