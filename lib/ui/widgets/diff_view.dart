import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../kit/kit_copy.dart';
import '../kit/kit_diff_view.dart';
import '../kit/kit_menu.dart';
import '../kit/kit_page_route.dart';
import 'reader_preferences.dart';

/// Retired by kit-KitDiffView: use KitDiffView (slice-P3.7a deletes this
/// file).
///
/// The full-screen diff reader shared by the Changes sheet and review
/// surfaces, now a forwarding wrapper: it converts [FileDiff] (lib/api) to
/// [KitDiffFile], passes the reader wrap preference in, and keeps its route
/// frame and the `diff-view` key. Copy is the file header's More menu,
/// verbatim (SEC-13), never a SnackBar.
class DiffView extends StatelessWidget {
  const DiffView({
    super.key,
    required this.diffs,
    this.title,
    this.allowCopy = true,
  });

  DiffView.single(FileDiff diff, {Key? key, bool allowCopy = true})
    : this(key: key, diffs: [diff], allowCopy: allowCopy);

  final List<FileDiff> diffs;
  final bool allowCopy;

  /// Optional route title; defaults to the localized "Review".
  /// File identity belongs to the file header.
  final String? title;

  /// Lines wrap below this width (the compact window, KitLayout).
  static const wrapBelow = 600.0;
  static const expandStep = KitDiffView.expandStep;

  static Future<void> open(BuildContext context, List<FileDiff> diffs) =>
      pushKitPage<void>(
        context,
        (_) => DiffView(diffs: diffs),
        fullscreenDialog: true,
      );

  static final _converted = Expando<KitDiffFile>();

  /// [diff] as the kit's file model (cached per [FileDiff] instance).
  static KitDiffFile kitFileOf(FileDiff diff) =>
      _converted[diff] ??= _convert(diff);

  static KitDiffFileStatus? _status(String? status) {
    final s = status?.toLowerCase();
    if (s == null || s.isEmpty) return null;
    if (s.startsWith('add') || s == 'new' || s == 'created') {
      return KitDiffFileStatus.added;
    }
    if (s.startsWith('delet') || s.startsWith('remov')) {
      return KitDiffFileStatus.deleted;
    }
    if (s.startsWith('renam')) return KitDiffFileStatus.renamed;
    return KitDiffFileStatus.modified;
  }

  static KitDiffFile _convert(FileDiff diff) {
    final patch = diff.patch;
    final parsed = patch != null && patch.isNotEmpty
        ? KitDiffFile.fromPatch(diff.file, patch, status: _status(diff.status))
        : KitDiffFile.fromTexts(
            diff.file,
            before: diff.before,
            after: diff.after,
            status: _status(diff.status),
          );
    return KitDiffFile(
      path: parsed.path,
      segments: parsed.segments,
      added: diff.additions ?? parsed.added,
      removed: diff.deletions ?? parsed.removed,
      status: parsed.status,
      oldPath: parsed.oldPath,
      binary: parsed.binary,
      fullText: diff.after,
      patch: diff.patch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final store = ReaderPreferencesScope.maybeOf(context);
    return Scaffold(
      key: const Key('diff-view'),
      appBar: AppBar(
        leading: const CloseButton(),
        centerTitle: true,
        title: Text(title ?? l10n.reviewTitle, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        top: false,
        child: KitDiffView(
          keyPrefix: 'diff',
          files: [for (final diff in diffs) kitFileOf(diff)],
          wrap: store?.value.wrapCode,
          onWrapChanged: store == null
              ? null
              : (wrap) => saveReaderPreferences(context, wrapCode: wrap),
          fileActions: allowCopy
              ? (file) => [
                  if (file.fullText case final text? when text.isNotEmpty)
                    KitMenuItem(
                      label: l10n.reviewCopyFile,
                      icon: AppIconography.copy,
                      onSelected: () =>
                          KitCopy.copy(context, text, redact: false),
                    )
                  else if (file.patch case final patch? when patch.isNotEmpty)
                    KitMenuItem(
                      label: l10n.reviewCopyPatch,
                      icon: AppIconography.copy,
                      onSelected: () =>
                          KitCopy.copy(context, patch, redact: false),
                    ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Retired by kit-KitDiffView: use KitDiffLineKind.
enum DiffRowKind { context, added, removed, meta }

/// Retired by kit-KitDiffView: use KitDiffLine.
///
/// One line of a diff with the numbers it has in each file.
class DiffRow {
  const DiffRow(this.text, this.kind, {this.oldNo, this.newNo});

  final String text;
  final DiffRowKind kind;
  final int? oldNo;
  final int? newNo;

  /// Number shown in the gutter: the new file's for kept and added lines,
  /// the old file's for removed ones.
  int? get gutterNo => kind == DiffRowKind.removed ? oldNo : newNo;
}

/// Retired by kit-KitDiffView: use KitDiffGap.
///
/// A run of unchanged lines that starts collapsed. [rows] is null when the
/// source (a unified patch) does not carry the skipped lines.
class DiffGap {
  const DiffGap({required this.count, this.rows});

  final int count;
  final List<DiffRow>? rows;
}
