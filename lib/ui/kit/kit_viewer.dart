// KitViewer — the one viewer for a file, a code block opened in full, or a
// document (docs/ux-system/kit-api/KitViewer.md; kit-v2.md §1.14, §8.2).
//
// The frame is always the same (name, muted path, one labelled action, an
// overflow, Close) and the body is one of the kit's renderers: text, code,
// Markdown, image, PDF, SVG, a delimited table, or "Can't show this file".
// Parsing, sanitising, file reading and PDF rendering stay with the caller.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'chat/kit_markdown.dart';
import 'kit_bidi.dart';
import 'kit_buttons.dart';
import 'kit_code_block.dart';
import 'kit_copy.dart';
import 'kit_divider.dart';
import 'kit_icon_button.dart';
import 'kit_image.dart';
import 'kit_layout.dart';
import 'kit_menu.dart';
import 'kit_motion.dart';
import 'kit_notice.dart';
import 'kit_page_route.dart';
import 'kit_progress.dart';
import 'kit_redact.dart';
import 'kit_search_field.dart';
import 'kit_state_view.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';
import 'motion/kit_reveal.dart';

/// Which renderer a [KitViewerContent] uses.
enum KitViewerKind { text, code, markdown, image, pdf, svg, delimited, binary }

/// One page of a PDF, already rendered by the caller's renderer
/// (lib/platform/local_pdf.dart); the kit only lays pages out.
@immutable
class KitPdfPage {
  const KitPdfPage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// An encoded bitmap (PNG) at the requested pixel width.
  final Uint8List bytes;

  /// In pixels.
  final int width, height;
}

/// What the viewer shows. Every constructor is data only: parsing,
/// sanitising and file reading stay with the caller.
@immutable
class KitViewerContent {
  /// Plain text: no line numbers, no syntax colour.
  const KitViewerContent.text(
    String text, {
    bool truncated = false,
    int? totalLines,
  }) : kind = KitViewerKind.text,
       _text = text,
       _language = null,
       _truncated = truncated,
       _totalLines = totalLines,
       _initialLine = null,
       _bytes = null,
       _semanticsLabel = null,
       _pageCount = 0,
       _renderPage = null,
       _cancelPage = null,
       _original = null,
       _rows = const [],
       _header = false,
       _mimeType = null,
       _byteLength = null;

  /// Source code: line numbers, syntax colour from [language]. [initialLine]
  /// (1-based) is scrolled to and marked.
  const KitViewerContent.code(
    String text, {
    String? language,
    bool truncated = false,
    int? totalLines,
    int? initialLine,
  }) : kind = KitViewerKind.code,
       _text = text,
       _language = language,
       _truncated = truncated,
       _totalLines = totalLines,
       _initialLine = initialLine,
       _bytes = null,
       _semanticsLabel = null,
       _pageCount = 0,
       _renderPage = null,
       _cancelPage = null,
       _original = null,
       _rows = const [],
       _header = false,
       _mimeType = null,
       _byteLength = null;

  /// A Markdown document, reflowed as prose (Show source swaps to its text).
  const KitViewerContent.markdown(String source, {bool truncated = false})
    : kind = KitViewerKind.markdown,
      _text = source,
      _language = null,
      _truncated = truncated,
      _totalLines = null,
      _initialLine = null,
      _bytes = null,
      _semanticsLabel = null,
      _pageCount = 0,
      _renderPage = null,
      _cancelPage = null,
      _original = null,
      _rows = const [],
      _header = false,
      _mimeType = null,
      _byteLength = null;

  /// An encoded image; [semanticsLabel] defaults to the viewer's name.
  const KitViewerContent.image(Uint8List bytes, {String? semanticsLabel})
    : kind = KitViewerKind.image,
      _text = null,
      _language = null,
      _truncated = false,
      _totalLines = null,
      _initialLine = null,
      _bytes = bytes,
      _semanticsLabel = semanticsLabel,
      _pageCount = 0,
      _renderPage = null,
      _cancelPage = null,
      _original = null,
      _rows = const [],
      _header = false,
      _mimeType = null,
      _byteLength = null;

  /// A PDF of [pageCount] pages. [renderPage] is called only for visible
  /// pages; [cancelPage] runs for a page scrolled away before it rendered.
  const KitViewerContent.pdf({
    required int pageCount,
    required Future<KitPdfPage> Function(int index, int widthPx) renderPage,
    void Function(int index)? cancelPage,
  }) : kind = KitViewerKind.pdf,
       _text = null,
       _language = null,
       _truncated = false,
       _totalLines = null,
       _initialLine = null,
       _bytes = null,
       _semanticsLabel = null,
       _pageCount = pageCount,
       _renderPage = renderPage,
       _cancelPage = cancelPage,
       _original = null,
       _rows = const [],
       _header = false,
       _mimeType = null,
       _byteLength = null;

  /// An SVG already sanitised by the caller (`StaticSvg`); [original] is the
  /// file's own text for Show source and Copy.
  const KitViewerContent.svg(
    String safeSource, {
    String? original,
    bool truncated = false,
  }) : kind = KitViewerKind.svg,
       _text = safeSource,
       _language = null,
       _truncated = truncated,
       _totalLines = null,
       _initialLine = null,
       _bytes = null,
       _semanticsLabel = null,
       _pageCount = 0,
       _renderPage = null,
       _cancelPage = null,
       _original = original,
       _rows = const [],
       _header = false,
       _mimeType = null,
       _byteLength = null;

  /// A parsed CSV or TSV: [rows] of cells, the first a header row when
  /// [header]. [original] is the raw text for Show source and Copy.
  const KitViewerContent.delimited(
    List<List<String>> rows, {
    String? original,
    bool header = true,
    bool truncated = false,
  }) : kind = KitViewerKind.delimited,
       _text = null,
       _language = null,
       _truncated = truncated,
       _totalLines = null,
       _initialLine = null,
       _bytes = null,
       _semanticsLabel = null,
       _pageCount = 0,
       _renderPage = null,
       _cancelPage = null,
       _original = original,
       _rows = rows,
       _header = header,
       _mimeType = null,
       _byteLength = null;

  /// A file the viewer cannot show: its type and size, and the caller's
  /// action.
  const KitViewerContent.binary({String? mimeType, int? byteLength})
    : kind = KitViewerKind.binary,
      _text = null,
      _language = null,
      _truncated = false,
      _totalLines = null,
      _initialLine = null,
      _bytes = null,
      _semanticsLabel = null,
      _pageCount = 0,
      _renderPage = null,
      _cancelPage = null,
      _original = null,
      _rows = const [],
      _header = false,
      _mimeType = mimeType,
      _byteLength = byteLength;

  final KitViewerKind kind;
  final String? _text, _language, _semanticsLabel, _original, _mimeType;
  final bool _truncated, _header;
  final int? _totalLines, _initialLine, _byteLength;
  final Uint8List? _bytes;
  final int _pageCount;
  final Future<KitPdfPage> Function(int index, int widthPx)? _renderPage;
  final void Function(int index)? _cancelPage;
  final List<List<String>> _rows;

  /// The whole text for Copy and Find (text, code, markdown source, svg and
  /// delimited originals); null for image, pdf and binary.
  String? get copyText => switch (kind) {
    KitViewerKind.text || KitViewerKind.code || KitViewerKind.markdown => _text,
    KitViewerKind.svg => _original ?? _text,
    KitViewerKind.delimited => _original,
    KitViewerKind.image || KitViewerKind.pdf || KitViewerKind.binary => null,
  };
}

/// Where the content comes from.
@immutable
class KitViewerSource {
  /// Content already in hand.
  const KitViewerSource(KitViewerContent content)
    : _content = content,
      _load = null;

  /// Content loaded on open; the viewer shows loading and a failure with
  /// Try again (which runs [load] again).
  const KitViewerSource.load(Future<KitViewerContent> Function() load)
    : _content = null,
      _load = load;

  final KitViewerContent? _content;
  final Future<KitViewerContent> Function()? _load;

  @override
  bool operator ==(Object other) =>
      other is KitViewerSource &&
      identical(other._content, _content) &&
      other._load == _load;

  @override
  int get hashCode => Object.hash(identityHashCode(_content), _load);
}

/// Marks a [KitViewer] that is the whole of a route (sheet or page), so its
/// name names the route.
class _KitViewerRouteScope extends InheritedWidget {
  const _KitViewerRouteScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_KitViewerRouteScope>() != null;

  @override
  bool updateShouldNotify(_KitViewerRouteScope oldWidget) => false;
}

/// Opens the viewer (KIT-11). Returns when it closes.
///
/// `asPage: null` picks by window (§8.2): a full-height bottom sheet on a
/// compact window, the same sheet capped at [KitLayout.sheetMaxWidth] on a
/// medium one, and a pushed page (Close at the end) from expanded up.
Future<void> showKitViewer(
  BuildContext context, {
  required String name,
  required KitViewerSource source,
  String? path,
  KitAction? primary,
  List<KitMenuItem> more = const [],
  bool? asPage,
  bool interactive = true,
  VoidCallback? onOpenAll,
  bool? wrap,
  ValueChanged<bool>? onWrapChanged,
  bool? showSource,
  ValueChanged<bool>? onShowSourceChanged,
  Key? viewerKey,
}) {
  final page = asPage ?? KitLayout.windowOf(context).isWide;
  Widget viewer(BuildContext routeContext) => _KitViewerRouteScope(
    child: KitViewer(
      name: name,
      source: source,
      path: path,
      primary: primary,
      more: more,
      onClose: () => Navigator.of(routeContext).pop(),
      interactive: interactive,
      onOpenAll: onOpenAll,
      wrap: wrap,
      onWrapChanged: onWrapChanged,
      showSource: showSource,
      onShowSourceChanged: onShowSourceChanged,
      viewerKey: viewerKey,
    ),
  );
  if (page) {
    return Navigator.of(context).push<void>(
      KitPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => Scaffold(
          backgroundColor: KitTokens.of(routeContext).roles.ground,
          body: SafeArea(bottom: false, child: viewer(routeContext)),
        ),
      ),
    );
  }
  final tokens = KitTokens.of(context);
  final reduced = KitMotion.reduced(context);
  // The same bottom modal `showKitSheet` presents (kit_sheet.dart), holding
  // the viewer's own frame: the sheet frame's header has no slot for the
  // action and More, and its body is a scroll view, which cannot hold a
  // virtualised file (reported in docs/qa/revamp-kit-KitViewer-2026-09-27/README.md).
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: tokens.sheetSurface,
    barrierColor: tokens.scrim,
    elevation: tokens.sheetElevation,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.sheetRadius),
      ),
    ),
    constraints: const BoxConstraints(maxWidth: KitLayout.sheetMaxWidth),
    sheetAnimationStyle: reduced
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: KitMotion.standard,
            reverseDuration: KitMotion.standard,
            curve: KitMotion.enter,
            reverseCurve: KitMotion.exit,
          ),
    builder: (sheetContext) => _KitViewerSheet(child: viewer(sheetContext)),
  );
}

/// The full-height sheet body: the handle, then the viewer.
class _KitViewerSheet extends StatelessWidget {
  const _KitViewerSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final height =
        MediaQuery.sizeOf(context).height * KitLayout.sheetFullHeight;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: l10n.kitSheetDismiss,
                onDismiss: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  height: tokens.handleHeight,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.handleColor,
                        borderRadius: BorderRadius.circular(
                          tokens.handleSize.height / 2,
                        ),
                      ),
                      child: SizedBox.fromSize(size: tokens.handleSize),
                    ),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same frame and body as [showKitViewer], as a widget: a two-pane
/// detail (Files on a PC), an About tab, and the goldens.
///
/// States: loading, error, empty, loaded, truncated, binary, page-failed,
/// finding.
class KitViewer extends StatefulWidget {
  const KitViewer({
    super.key,
    required this.name,
    required this.source,
    this.path,
    this.primary,
    this.more = const [],
    this.onClose,
    this.interactive = true,
    this.onOpenAll,
    this.wrap,
    this.onWrapChanged,
    this.showSource,
    this.onShowSourceChanged,
    this.showHeader = true,
    this.viewerKey,
  });

  /// "README.md": the title.
  final String name;
  final KitViewerSource source;

  /// The file's full path. The header shows only its parent folder
  /// ([folderOf]); the full value stays in semantics, and "Copy path"
  /// (the caller's [more] item) copies it whole.
  final String? path;

  /// The header's subtitle for [path]: the parent folder with its trailing
  /// slash ("docs/"), keeping anything after the name ("src/ · Line 12").
  /// Null for a root file, so the name never shows twice
  /// ("README.md / README.md"). A [path] whose last segment is not [name]
  /// (a caption such as "MIT License") is shown as it is.
  static String? folderOf(String path, String name) {
    final slash = math.max(path.lastIndexOf('/'), path.lastIndexOf(r'\'));
    final last = path.substring(slash + 1);
    if (name.isEmpty || !last.startsWith(name)) {
      return path.isEmpty ? null : path;
    }
    final folder = path.substring(0, slash + 1);
    var rest = last.substring(name.length).trim();
    if (folder.isEmpty) {
      rest = rest.replaceFirst(RegExp(r'^[\s·:,-]+'), '');
      return rest.isEmpty ? null : rest;
    }
    return rest.isEmpty ? folder : '$folder $rest';
  }

  /// At most one labelled action: "Add to prompt".
  final KitAction? primary;

  /// The caller's overflow items after the kit's own: Copy path, Save,
  /// Share, Open in Files, Open in Review.
  final List<KitMenuItem> more;

  /// Null: no Close (an embedded pane or tab).
  final VoidCallback? onClose;

  /// Markdown links and path chips open (through `openExternalLink`,
  /// SEC-1); false: inert text.
  final bool interactive;

  /// "Open all" for a truncated source.
  final VoidCallback? onOpenAll;

  /// Null: wrap on compact, scroll sideways from medium.
  final bool? wrap;

  /// The reader preference (`ReaderPreferencesStore`).
  final ValueChanged<bool>? onWrapChanged;

  /// Markdown, SVG, delimited: start on the source.
  final bool? showSource;
  final ValueChanged<bool>? onShowSourceChanged;

  /// False inside a host that has its own top bar (an About tab).
  final bool showHeader;

  /// Default `kit-viewer`.
  final Key? viewerKey;

  /// Text sources show at most this many lines; beyond it the viewer says
  /// "Showing the first 2,000 of 5,210 lines · Open all" (K2 §1.14).
  static const int maxLines = 2000;

  @override
  State<KitViewer> createState() => _KitViewerState();
}

/// Text prepared once per content: capped at [KitViewer.maxLines], redacted
/// for Find, with the counts for the truncation notice.
class _Prepared {
  _Prepared(String text) {
    final lines = text.split('\n');
    if (text.endsWith('\n')) lines.removeLast();
    totalLines = lines.length;
    capped = totalLines > KitViewer.maxLines;
    shown = capped ? lines.take(KitViewer.maxLines).join('\n') : text;
    shownLines = math.min(totalLines, KitViewer.maxLines);
    redacted = KitRedact.text(shown);
    var longestLine = '';
    for (final line in shown.split('\n')) {
      if (line.length > longestLine.length) longestLine = line;
    }
    longest = longestLine;
  }

  late final String shown, redacted, longest;
  late final int totalLines, shownLines;
  late final bool capped;
}

class _KitViewerState extends State<KitViewer> {
  /// The most of the viewer's height the frame's top (header and the
  /// truncation notice) takes before it scrolls.
  static const double _topShare = 0.5;

  final ScrollController _codeHorizontal = ScrollController();
  KitViewerContent? _content;
  Object? _error;
  bool _loading = false;
  int _generation = 0;

  bool? _wrap;
  bool? _showSource;

  bool _findOpen = false;
  String _query = '';
  List<TextRange> _marks = const [];
  int _active = 0;
  final TextEditingController _findController = TextEditingController();
  late final FocusNode _findFocus = FocusNode(
    debugLabel: 'kit-viewer-find',
    onKeyEvent: _onFindKey,
  );
  final FocusNode _frameFocus = FocusNode(debugLabel: 'kit-viewer');

  final Map<String, _Prepared> _prepared = {};

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(KitViewer old) {
    super.didUpdateWidget(old);
    if (widget.source != old.source) _resolve();
    if (widget.wrap != old.wrap) _wrap = null;
    if (widget.showSource != old.showSource) _showSource = null;
  }

  @override
  void dispose() {
    _generation++;
    _findController.dispose();
    _codeHorizontal.dispose();
    _findFocus.dispose();
    _frameFocus.dispose();
    super.dispose();
  }

  // --- Loading ---------------------------------------------------------------

  void _resolve() {
    final generation = ++_generation;
    _prepared.clear();
    _findOpen = false;
    _query = '';
    _marks = const [];
    _active = 0;
    final source = widget.source;
    final content = source._content;
    if (content != null) {
      _content = content;
      _error = null;
      _loading = false;
      return;
    }
    _content = null;
    _error = null;
    _loading = true;
    Future.sync(source._load!).then(
      (loaded) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _content = loaded;
          _loading = false;
        });
      },
      onError: (Object error, StackTrace _) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _error = error;
          _loading = false;
        });
      },
    );
  }

  void _retry() => setState(_resolve);

  // --- What the body shows ----------------------------------------------------

  _Prepared _prepare(String text) =>
      _prepared.putIfAbsent(text, () => _Prepared(text));

  bool get _sourceView {
    final content = _content;
    if (content == null) return false;
    final on = _showSource ?? widget.showSource ?? false;
    return switch (content.kind) {
      KitViewerKind.markdown => on,
      KitViewerKind.svg ||
      KitViewerKind.delimited => on && content._original != null,
      _ => false,
    };
  }

  bool get _sourceApplies {
    final content = _content;
    if (content == null) return false;
    return switch (content.kind) {
      KitViewerKind.markdown => true,
      KitViewerKind.svg || KitViewerKind.delimited => content._original != null,
      _ => false,
    };
  }

  /// The text the body draws in a code block, or null when the body is not
  /// a code block (prose, image, PDF, picture, table, binary).
  String? get _codeText {
    final content = _content;
    if (content == null) return null;
    return switch (content.kind) {
      KitViewerKind.text || KitViewerKind.code => content._text,
      KitViewerKind.markdown => _sourceView ? content._text : null,
      KitViewerKind.svg => _sourceView ? content._original : null,
      KitViewerKind.delimited => _sourceView ? content._original : null,
      _ => null,
    };
  }

  bool get _isEmpty {
    final content = _content;
    if (content == null) return false;
    return switch (content.kind) {
      KitViewerKind.text ||
      KitViewerKind.code ||
      KitViewerKind.markdown ||
      KitViewerKind.svg => (content._text ?? '').trim().isEmpty,
      KitViewerKind.delimited => content._rows.isEmpty,
      _ => false,
    };
  }

  bool _effectiveWrap(BuildContext context) =>
      _wrap ??
      widget.wrap ??
      KitCodeBlock.defaultWrap(context, KitCodeKind.code);

  void _toggleWrap() {
    final next = !_effectiveWrap(context);
    setState(() => _wrap = next);
    widget.onWrapChanged?.call(next);
  }

  void _toggleSource() {
    final next = !_sourceView;
    if (_findOpen) _closeFind(refocus: false);
    setState(() => _showSource = next);
    widget.onShowSourceChanged?.call(next);
  }

  // --- Find -------------------------------------------------------------------

  bool get _findable => _codeText != null && !_isEmpty;

  void _openFind() {
    if (!_findable) return;
    if (_findOpen) {
      _findFocus.requestFocus();
      return;
    }
    setState(() => _findOpen = true);
  }

  void _closeFind({bool refocus = true}) {
    if (!_findOpen) return;
    _findController.clear();
    setState(() {
      _findOpen = false;
      _query = '';
      _marks = const [];
      _active = 0;
    });
    if (refocus) _frameFocus.requestFocus();
  }

  void _onQuery(String query) {
    final text = _codeText;
    final marks = <TextRange>[];
    if (query.isNotEmpty && text != null) {
      final haystack = _prepare(text).redacted;
      final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
      for (final match in pattern.allMatches(haystack)) {
        if (match.end == match.start) continue;
        marks.add(TextRange(start: match.start, end: match.end));
      }
    }
    setState(() {
      _query = query;
      _marks = marks;
      _active = 0;
    });
    if (query.isNotEmpty) _announceCount();
  }

  void _announceCount() {
    final view = View.maybeOf(context);
    if (view == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        _countText(AppLocalizations.of(context)),
        Directionality.of(context),
      ),
    );
  }

  String _countText(AppLocalizations l10n) => _marks.isEmpty
      ? l10n.kitViewerFindNone
      : l10n.kitViewerFindCount(_active + 1, _marks.length);

  void _step(int delta) {
    if (_marks.isEmpty) return;
    setState(() {
      _active = (_active + delta) % _marks.length;
      if (_active < 0) _active += _marks.length;
    });
  }

  KeyEventResult _onFindKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _closeFind();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _step(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // --- Keyboard and menu ------------------------------------------------------

  KeyEventResult _onFrameKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_findOpen) {
        _closeFind();
        return KeyEventResult.handled;
      }
      final close = widget.onClose;
      if (close != null) {
        close();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.keyF &&
        (keyboard.isControlPressed || keyboard.isMetaPressed) &&
        _findable) {
      _openFind();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<KitMenuItem> _menuItems(AppLocalizations l10n) {
    const kit = #kitViewer;
    final content = _content;
    final copyText = content?.copyText;
    final fine = KitLayout.finePointer(context);
    return [
      if (_findable)
        KitMenuItem(
          key: const ValueKey('kit-viewer-menu-find'),
          label: l10n.kitViewerFind,
          icon: AppIconography.search,
          group: kit,
          shortcut: fine ? 'Ctrl+F' : null,
          onSelected: _openFind,
        ),
      if (copyText != null)
        KitMenuItem(
          key: const ValueKey('kit-viewer-menu-copy'),
          label: l10n.kitViewerCopyContents,
          icon: AppIconography.copy,
          group: kit,
          enabled: !_isEmpty,
          disabledReason: _isEmpty ? l10n.kitViewerEmpty : null,
          // SEC-13 (coordinator 2026-09-27): the person's own content is
          // copied verbatim; only the screen text is redacted.
          onSelected: () {
            if (mounted) {
              unawaited(KitCopy.copy(context, copyText, redact: false));
            }
          },
        ),
      if (_codeText != null && !_isEmpty)
        KitMenuItem(
          key: const ValueKey('kit-viewer-menu-wrap'),
          label: l10n.kitWrapLines,
          icon: AppIconography.wrapText,
          group: kit,
          checked: _effectiveWrap(context),
          onSelected: _toggleWrap,
        ),
      if (_sourceApplies)
        KitMenuItem(
          key: const ValueKey('kit-viewer-menu-source'),
          label: l10n.kitViewerShowSource,
          icon: AppIconography.code,
          group: kit,
          checked: _sourceView,
          onSelected: _toggleSource,
        ),
      ...widget.more,
    ];
  }

  Future<void> _openMenu(BuildContext anchor, {Offset? position}) =>
      showKitMenu(
        anchor,
        items: _menuItems(AppLocalizations.of(context)),
        position: position,
        semanticsLabel: widget.name,
      );

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final notice = _truncationNotice(l10n);
    final body = Builder(
      builder: (bodyContext) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        // The pointer twin of More, which is the labelled control.
        excludeFromSemantics: true,
        onSecondaryTapUp: (details) =>
            unawaited(_openMenu(bodyContext, position: details.globalPosition)),
        child: _body(bodyContext, tokens, l10n),
      ),
    );
    final top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          _header(context, tokens, l10n),
          const KitDivider(),
        ],
        if (notice != null)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.gutter,
              tokens.space2,
              tokens.gutter,
              tokens.space2,
            ),
            child: notice,
          ),
      ],
    );
    // The name is never cut: at large text on a small window the frame's
    // top scrolls within at most [_topShare] of the height, and the body
    // keeps the rest.
    final column = LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * _topShare,
            ),
            child: SingleChildScrollView(child: top),
          ),
          // Find stays outside the scrolling top: it is short, and its count
          // must stay in view while the person types.
          KitReveal(child: _findOpen ? _findBar(tokens, l10n) : null),
          Expanded(child: body),
        ],
      ),
    );
    return KeyedSubtree(
      key: widget.viewerKey ?? const ValueKey('kit-viewer'),
      child: Focus(
        focusNode: _frameFocus,
        autofocus: widget.onClose != null,
        includeSemantics: false,
        onKeyEvent: _onFrameKey,
        child: column,
      ),
    );
  }

  Widget _header(
    BuildContext context,
    KitTokens tokens,
    AppLocalizations l10n,
  ) {
    final compact = KitLayout.windowOf(context) == KitWindow.compact;
    final path = widget.path;
    final folder = path == null ? null : KitViewer.folderOf(path, widget.name);
    final routeNamed = _KitViewerRouteScope.of(context);
    // Binary content offers the caller's action in its own state instead.
    final primary = _content?.kind == KitViewerKind.binary
        ? null
        : widget.primary;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          namesRoute: routeNamed,
          child: KitText(widget.name, role: KitTextRole.headline),
        ),
        // The parent folder only: the name is already the title, so a root
        // file shows no second line. The full path stays in semantics.
        if (folder != null) ...[
          SizedBox(height: tokens.space1 / 2),
          Semantics(
            label: path,
            child: ExcludeSemantics(
              child: KitText.mono(
                folder,
                cut: KitMonoCut.middle,
                tone: KitTextTone.secondary,
              ),
            ),
          ),
        ],
      ],
    );
    final top = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        widget.onClose == null ? tokens.space3 : tokens.space1,
        tokens.space2,
        primary == null ? tokens.space2 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                top: tokens.space2,
                end: tokens.space2,
              ),
              child: title,
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: Builder(
              builder: (anchor) => KitIconButton(
                key: const ValueKey('kit-viewer-more'),
                icon: AppIconography.more,
                tooltip: l10n.kitMore,
                onPressed: () => unawaited(_openMenu(anchor)),
              ),
            ),
          ),
          if (widget.onClose case final close?)
            FocusTraversalOrder(
              order: const NumericFocusOrder(3),
              child: KitIconButton(
                key: const ValueKey('kit-viewer-close'),
                icon: AppIconography.close,
                tooltip: l10n.kitSheetClose,
                onPressed: close,
              ),
            ),
        ],
      ),
    );
    if (primary == null) return top;
    // The one labelled action has its own full-width row under the name,
    // starting where the name starts: never squeezed beside More and Close,
    // never wrapped to two centred lines.
    final reason = primary.enabled ? null : primary.disabledReason;
    final button = KeyedSubtree(
      key: const ValueKey('kit-viewer-primary'),
      child: KitButton.fromAction(
        primary,
        role: compact ? KitButtonRole.tertiary : KitButtonRole.secondary,
        expand: false,
      ),
    );
    final primaryRow = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space2,
        tokens.gutter,
        tokens.space2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: compact
                ? Transform.translate(
                    // The tertiary button's words line up with the name.
                    offset: Offset(
                      Directionality.of(context) == TextDirection.rtl
                          ? KitButton.tertiaryInset
                          : -KitButton.tertiaryInset,
                      0,
                    ),
                    child: button,
                  )
                : button,
          ),
          if (reason != null) KitText(reason, role: KitTextRole.secondary),
        ],
      ),
    );
    // Tab still reaches the primary first, then More and Close (LAY-10).
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [top, primaryRow],
      ),
    );
  }

  Widget _findBar(KitTokens tokens, AppLocalizations l10n) {
    final hasMarks = _marks.isNotEmpty;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space2,
        tokens.space2,
        tokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: KitSearchField(
                  label: l10n.kitViewerFind,
                  controller: _findController,
                  focusNode: _findFocus,
                  autofocus: true,
                  fieldKey: const ValueKey('kit-viewer-find'),
                  onChanged: _onQuery,
                  onSubmitted: (_) {
                    _step(1);
                    _findFocus.requestFocus();
                  },
                ),
              ),
              SizedBox(width: tokens.space1),
              // Up and down: never mirrored.
              KitIconButton(
                key: const ValueKey('kit-viewer-find-previous'),
                icon: AppIconography.chevronUp,
                tooltip: l10n.kitViewerFindPrevious,
                shortcut: 'Shift+Enter',
                onPressed: hasMarks ? () => _step(-1) : null,
              ),
              KitIconButton(
                key: const ValueKey('kit-viewer-find-next'),
                icon: AppIconography.chevronDown,
                tooltip: l10n.kitViewerFindNext,
                shortcut: 'Enter',
                onPressed: hasMarks ? () => _step(1) : null,
              ),
              KitIconButton(
                key: const ValueKey('kit-viewer-find-close'),
                icon: AppIconography.close,
                tooltip: l10n.kitViewerFindClose,
                shortcut: 'Esc',
                onPressed: _closeFind,
              ),
            ],
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(top: tokens.space2),
              child: KitText(
                _countText(l10n),
                key: const ValueKey('kit-viewer-find-count'),
                role: KitTextRole.secondary,
                tabular: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget? _truncationNotice(AppLocalizations l10n) {
    final content = _content;
    if (content == null || _isEmpty) return null;
    String? message;
    final code = _codeText;
    if (code != null &&
        (content.kind == KitViewerKind.text ||
            content.kind == KitViewerKind.code ||
            _sourceView)) {
      final prepared = _prepare(code);
      if (content._truncated || prepared.capped) {
        final known = content._totalLines;
        final total = prepared.capped
            ? math.max(prepared.totalLines, known ?? 0)
            : known;
        message = total != null && total > prepared.shownLines
            ? l10n.kitViewerTruncated(prepared.shownLines, total)
            : l10n.kitViewerPartial;
      }
    } else if (content._truncated) {
      message = l10n.kitViewerPartial;
    }
    if (message == null) return null;
    final openAll = widget.onOpenAll;
    return KitNotice(
      message: message,
      liveRegion: false,
      actions: [
        if (openAll != null)
          KitAction(
            key: const ValueKey('kit-viewer-open-all'),
            label: l10n.kitViewerOpenAll,
            onPressed: openAll,
          ),
      ],
    );
  }

  Widget _body(BuildContext context, KitTokens tokens, AppLocalizations l10n) {
    if (_loading) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
        child: const KitSkeletonRows(count: 6),
      );
    }
    final error = _error;
    if (error != null) {
      return _centred(
        tokens,
        KitStateView(
          icon: AppIconography.error,
          tone: AppStatusTone.failure,
          title: l10n.kitViewerLoadFailed(widget.name),
          size: KitStateSize.inline,
          details: KitRedact.text('$error'),
          primary: KitAction(
            key: const ValueKey('kit-viewer-retry'),
            label: l10n.kitTryAgain,
            onPressed: _retry,
          ),
        ),
      );
    }
    final content = _content;
    if (content == null) return const SizedBox.shrink();
    if (_isEmpty) {
      return Padding(
        padding: EdgeInsets.all(tokens.gutter),
        child: KitText(
          l10n.kitViewerEmpty,
          key: const ValueKey('kit-viewer-empty'),
          tone: KitTextTone.tertiary,
        ),
      );
    }
    final code = _codeText;
    if (code != null) {
      final lineNumbers = content.kind != KitViewerKind.text;
      return _codeBody(
        context,
        tokens,
        _prepare(code),
        language: switch (content.kind) {
          KitViewerKind.code => content._language,
          KitViewerKind.markdown => 'markdown',
          KitViewerKind.svg => 'xml',
          _ => null,
        },
        lineNumbers: lineNumbers,
        highlight: content.kind != KitViewerKind.text,
        initialLine: content._initialLine,
      );
    }
    return switch (content.kind) {
      KitViewerKind.markdown => _Prose(
        source: content._text ?? '',
        interactive: widget.interactive,
        wrap: widget.wrap,
        onWrapChanged: widget.onWrapChanged,
      ),
      KitViewerKind.image => KitZoom(
        label: widget.name,
        resetKey: content,
        child: Center(
          child: KitImage(
            source: KitImageSource.memory(content._bytes!),
            semanticsLabel: content._semanticsLabel ?? widget.name,
            imageKey: const ValueKey('kit-viewer-image'),
          ),
        ),
      ),
      KitViewerKind.pdf => _KitPdfBody(content: content, name: widget.name),
      KitViewerKind.svg => KitZoom(
        label: widget.name,
        resetKey: content,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.space4),
            child: SvgPicture.string(
              content._text!,
              fit: BoxFit.contain,
              semanticsLabel: widget.name,
              errorBuilder: (context, error, stack) =>
                  KitText(l10n.kitViewerCantShow, tone: KitTextTone.tertiary),
            ),
          ),
        ),
      ),
      KitViewerKind.delimited => _KitTable(
        key: const ValueKey('kit-viewer-table'),
        rows: content._rows,
        header: content._header,
      ),
      KitViewerKind.binary => _centred(
        tokens,
        KitStateView(
          icon: AppIconography.file,
          title: l10n.kitViewerCantShow,
          body: l10n.kitViewerCantShowBody(
            content._mimeType ?? l10n.kitViewerUnknownType,
            _sizeInWords(context, content._byteLength) ??
                l10n.kitViewerUnknownSize,
          ),
          size: KitStateSize.inline,
          primary: widget.primary,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  // The inline KitStateView brings its own gutter at the sides; adding
  // another would put it at twice the gutter, off the name's line.
  Widget _centred(KitTokens tokens, Widget child) => Center(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: tokens.gutter),
      child: child,
    ),
  );

  Widget _codeBody(
    BuildContext context,
    KitTokens tokens,
    _Prepared prepared, {
    required String? language,
    required bool lineNumbers,
    required bool highlight,
    int? initialLine,
  }) {
    final wrap = _effectiveWrap(context);
    final block = KitCodeBlock.fill(
      text: prepared.shown,
      language: language,
      wrap: wrap,
      lineNumbers: lineNumbers,
      highlight: highlight,
      marks: _findOpen ? _marks : const [],
      activeMark: _findOpen && _marks.isNotEmpty ? _active : null,
      initialLine: initialLine,
    );
    // The body starts on the same gutter as the header's name.
    final inset = EdgeInsetsDirectional.symmetric(
      horizontal: tokens.gutter,
      vertical: tokens.space2,
    );
    Widget body;
    if (wrap) {
      body = Padding(padding: inset, child: block);
    } else {
      // One horizontal scroller for the whole file: the block is laid out
      // as wide as its longest line (it needs a bounded width).
      final style = KitText.styleOf(context, KitTextRole.mono);
      final scaler = MediaQuery.textScalerOf(context);
      final digits = lineNumbers ? '${prepared.shownLines}'.length : 0;
      final painter = TextPainter(
        text: TextSpan(
          text: '${''.padLeft(digits, '9')} ${prepared.longest}',
          style: style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final natural =
          (painter.width + tokens.space2 + tokens.gutter * 2 + tokens.space4)
              .ceilToDouble();
      painter.dispose();
      body = LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, natural);
          return Scrollbar(
            controller: _codeHorizontal,
            thumbVisibility: KitLayout.finePointer(context),
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _codeHorizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: Padding(padding: inset, child: block),
              ),
            ),
          );
        },
      );
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: tokens.detailsSurface, child: body),
    );
  }
}

/// A byte count in words: "2.4 MB". Null when unknown.
String? _sizeInWords(BuildContext context, int? bytes) {
  if (bytes == null || bytes < 0) return null;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final format = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toString(),
  )..maximumFractionDigits = unit == 0 || value >= 10 ? 0 : 1;
  return '${format.format(value)} ${units[unit]}';
}

/// Markdown as prose on the reading rails, centred at
/// [KitLayout.readingWidth] on a wide window.
class _Prose extends StatefulWidget {
  const _Prose({
    required this.source,
    required this.interactive,
    this.wrap,
    this.onWrapChanged,
  });

  final String source;
  final bool interactive;
  final bool? wrap;
  final ValueChanged<bool>? onWrapChanged;

  @override
  State<_Prose> createState() => _ProseState();
}

class _ProseState extends State<_Prose> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Scrollbar(
      controller: _controller,
      thumbVisibility: KitLayout.finePointer(context),
      child: SingleChildScrollView(
        controller: _controller,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.gutter,
          vertical: tokens.space4,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KitLayout.readingWidth),
            child: KitMarkdown(
              widget.source,
              interactive: widget.interactive,
              codeWrap: widget.wrap,
              onCodeWrapChanged: widget.onWrapChanged,
            ),
          ),
        ),
      ),
    );
  }
}

// --- PDF ----------------------------------------------------------------------

class _KitPdfBody extends StatefulWidget {
  const _KitPdfBody({required this.content, required this.name});

  final KitViewerContent content;
  final String name;

  @override
  State<_KitPdfBody> createState() => _KitPdfBodyState();
}

class _KitPdfBodyState extends State<_KitPdfBody> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final content = widget.content;
    final wide = KitLayout.windowOf(context).isWide;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = math
            .min(
              constraints.maxWidth - tokens.space3 * 2,
              KitLayout.readingWidth,
            )
            .floorToDouble();
        return KitZoom(
          label: widget.name,
          resetKey: content,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: KitLayout.finePointer(context),
            child: ListView.builder(
              controller: _controller,
              // PERF-4: a page renders only while it is on screen.
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              padding: EdgeInsets.symmetric(vertical: tokens.space3),
              itemCount: content._pageCount,
              itemBuilder: (context, index) => Center(
                child: _KitPdfPageView(
                  key: ValueKey('kit-viewer-page-$index'),
                  index: index,
                  count: content._pageCount,
                  width: pageWidth,
                  rounded: wide,
                  render: content._renderPage!,
                  cancel: content._cancelPage,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KitPdfPageView extends StatefulWidget {
  const _KitPdfPageView({
    super.key,
    required this.index,
    required this.count,
    required this.width,
    required this.rounded,
    required this.render,
    this.cancel,
  });

  final int index, count;
  final double width;
  final bool rounded;
  final Future<KitPdfPage> Function(int index, int widthPx) render;
  final void Function(int index)? cancel;

  @override
  State<_KitPdfPageView> createState() => _KitPdfPageViewState();
}

class _KitPdfPageViewState extends State<_KitPdfPageView> {
  KitPdfPage? _page;
  Object? _error;
  bool _pending = false;
  bool _requested = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) _request();
  }

  @override
  void dispose() {
    _generation++;
    if (_pending) widget.cancel?.call(widget.index);
    super.dispose();
  }

  void _request() {
    _requested = true;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final widthPx = math.max(1, (widget.width * dpr).round());
    final generation = ++_generation;
    _pending = true;
    _error = null;
    Future.sync(() => widget.render(widget.index, widthPx)).then(
      (page) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _page = page;
          _pending = false;
        });
      },
      onError: (Object error, StackTrace _) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _error = error;
          _pending = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final label = l10n.kitViewerPage(widget.index + 1, widget.count);
    final page = _page;
    final width = widget.width;
    final height = page != null && page.width > 0
        ? (width * page.height / page.width).roundToDouble()
        : (width * math.sqrt2).roundToDouble();
    final shape = widget.rounded ? KitShape.panel : KitShape.square;
    final Widget child;
    if (_error != null) {
      child = SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SingleChildScrollView(
            child: KitStateView(
              icon: AppIconography.error,
              tone: AppStatusTone.failure,
              title: l10n.kitViewerPageFailed(widget.index + 1),
              size: KitStateSize.inline,
              primary: KitAction(
                key: ValueKey('kit-viewer-page-${widget.index}-retry'),
                label: l10n.kitTryAgain,
                onPressed: () => setState(_request),
              ),
            ),
          ),
        ),
      );
    } else if (page != null) {
      child = KitImage(
        source: KitImageSource.memory(page.bytes),
        semanticsLabel: label,
        width: width,
        height: height,
        shape: shape,
      );
    } else {
      child = Semantics(
        label: label,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: tokens.detailsSurface,
            shape: tokens.shapeOf(shape),
          ),
          child: SizedBox(width: width, height: height),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.space3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          SizedBox(height: tokens.space1),
          ExcludeSemantics(
            child: KitText(label, role: KitTextRole.caption, tabular: true),
          ),
        ],
      ),
    );
  }
}

// --- Delimited table ------------------------------------------------------------

class _KitTable extends StatefulWidget {
  const _KitTable({super.key, required this.rows, required this.header});

  final List<List<String>> rows;
  final bool header;

  @override
  State<_KitTable> createState() => _KitTableState();
}

class _KitTableState extends State<_KitTable> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  /// How many rows are measured to size the columns.
  static const _measuredRows = 100;

  /// Cells longer than this many characters do not widen their column.
  static const _measuredChars = 40;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  List<double> _columnWidths(BuildContext context, KitTokens tokens) {
    final columns = widget.rows.fold<int>(
      0,
      (count, row) => math.max(count, row.length),
    );
    final longest = List<String>.filled(columns, '');
    for (final row in widget.rows.take(_measuredRows)) {
      for (var c = 0; c < row.length; c++) {
        final cell = row[c].length > _measuredChars
            ? row[c].substring(0, _measuredChars)
            : row[c];
        if (cell.length > longest[c].length) longest[c] = cell;
      }
    }
    final style = KitText.styleOf(context, KitTextRole.secondary);
    final scaler = MediaQuery.textScalerOf(context);
    final min = tokens.minTarget * 2;
    const max = KitLayout.readingWidth / 3;
    return [
      for (final text in longest)
        () {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return (width.clamp(min, max) + tokens.space3 * 2).ceilToDouble();
        }(),
    ];
  }

  Widget _row(
    BuildContext context,
    KitTokens tokens,
    List<String> cells,
    List<double> widths, {
    required bool header,
  }) {
    final hairline = KitTokens.hairlineWidth(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.roles.hairline, width: hairline),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.rowHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var c = 0; c < widths.length; c++)
              SizedBox(
                width: widths[c],
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: tokens.space3,
                    vertical: tokens.space2,
                  ),
                  child: Semantics(
                    label: c < cells.length ? cells[c] : '',
                    header: header,
                    child: ExcludeSemantics(
                      child: KitText(
                        KitBidi.auto(c < cells.length ? cells[c] : ''),
                        role: header
                            ? KitTextRole.label
                            : KitTextRole.secondary,
                        tone: KitTextTone.primary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final widths = _columnWidths(context, tokens);
    final natural = widths.fold<double>(0, (sum, w) => sum + w);
    final header = widget.header && widget.rows.isNotEmpty
        ? widget.rows.first
        : null;
    final body = header == null ? widget.rows : widget.rows.sublist(1);
    final fine = KitLayout.finePointer(context);
    // The file's column order, left to right, whatever the locale; each
    // cell is isolated (KitBidi.auto) so its own words shape correctly.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, natural);
          return Scrollbar(
            controller: _horizontal,
            thumbVisibility: fine,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null)
                      KeyedSubtree(
                        key: const ValueKey('kit-viewer-table-header'),
                        child: _row(
                          context,
                          tokens,
                          header,
                          widths,
                          header: true,
                        ),
                      ),
                    Expanded(
                      child: Scrollbar(
                        controller: _vertical,
                        thumbVisibility: fine,
                        child: ListView.builder(
                          controller: _vertical,
                          itemCount: body.length,
                          itemBuilder: (context, index) => KeyedSubtree(
                            key: ValueKey('kit-viewer-table-row-$index'),
                            child: _row(
                              context,
                              tokens,
                              body[index],
                              widths,
                              header: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
