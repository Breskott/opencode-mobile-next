// KitLogPanel: the one log view — live or finished output from one process
// (server logs, setup output, dev services, shell output, the phone team's
// steps) (docs/ux-system/kit-api/KitLogPanel.md; kit-v2.md §1.11, §4.4,
// §8.2; G9, G12; KIT-31, KIT-32, LOOK-4, LOOK-5, LOOK-16, PERF-4, A11Y-3,
// MOT-5, MOT-7).
//
// Mono, left to right in every locale, folded under Details unless the page
// exists to show the log. It does not compose KitCodeBlock: no syntax
// colour, no terminal emulation.
import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import 'kit_bidi.dart';
import 'kit_buttons.dart';
import 'kit_details_fold.dart';
import 'kit_icon_button.dart';
import 'kit_jump_pill.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_notice.dart';
import 'kit_redact.dart';
import 'kit_since.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// What kind of line: drives the look (a neutral gutter glyph and `text1`),
/// never colour alone.
enum KitLogLevel { normal, warning, error }

/// One line of output.
@immutable
class KitLogLine {
  const KitLogLine(this.text, {this.level = KitLogLevel.normal, this.at});

  /// One line, no newline; redacted by the panel before it is drawn or
  /// copied.
  final String text;
  final KitLogLevel level;

  /// When it arrived (for "Last line 12 s ago").
  final DateTime? at;
}

/// How the source ended.
@immutable
class KitLogEnd {
  const KitLogEnd({this.exitCode, this.failed = false, this.reason});

  /// "Ended · exit 1".
  final int? exitCode;

  /// The header word is "Failed" instead of "Ended".
  final bool failed;

  /// One line in words, from the caller (agentErrorWords).
  final String? reason;
}

enum KitLogSize {
  /// About 12 lines tall ([KitTokens.logFoldedLines]): the panel inside a
  /// KitDetailsFold or a card.
  folded,

  /// Fills its host: a page whose job is the log, or a full-height sheet.
  /// The host gives it a bounded height.
  fill,
}

/// A bounded ring buffer of lines, for sources that hand over text chunks
/// (a process's stdout, SetupTerminal's `output`). Splits on newlines,
/// keeps a partial last line open until its newline arrives (shown as the
/// last line meanwhile), drops the oldest lines past [capacity] and counts
/// them in [dropped].
class KitLogBuffer extends ValueNotifier<List<KitLogLine>> {
  KitLogBuffer({this.capacity = KitLogPanel.defaultMaxLines})
    : assert(capacity > 0),
      super(const []);

  final int capacity;

  final List<KitLogLine> _lines = [];
  String _partial = '';
  KitLogLevel _partialLevel = KitLogLevel.normal;
  DateTime? _partialAt;
  int _dropped = 0;

  /// Lines dropped past [capacity] since the last [clear].
  int get dropped => _dropped;

  void add(KitLogLine line) {
    _closePartial();
    _lines.add(line);
    _publish();
  }

  void appendText(String chunk, {KitLogLevel level = KitLogLevel.normal}) {
    if (chunk.isEmpty) return;
    final parts = (_partial + chunk).split('\n');
    final now = clock.now();
    _partial = parts.removeLast();
    for (final part in parts) {
      _lines.add(KitLogLine(_strip(part), level: level, at: now));
    }
    _partialLevel = level;
    if (_partial.isNotEmpty) _partialAt = now;
    _publish();
  }

  /// A source that re-sends its whole output: replaces every line.
  void replaceText(String text) {
    _lines.clear();
    _partial = '';
    _dropped = 0;
    appendText(text);
    if (text.isEmpty) _publish();
  }

  void clear() {
    _lines.clear();
    _partial = '';
    _dropped = 0;
    _publish();
  }

  void _closePartial() {
    if (_partial.isEmpty) return;
    _lines.add(
      KitLogLine(_strip(_partial), level: _partialLevel, at: _partialAt),
    );
    _partial = '';
  }

  static String _strip(String s) =>
      s.endsWith('\r') ? s.substring(0, s.length - 1) : s;

  void _publish() {
    final keep = _partial.isEmpty ? capacity : capacity - 1;
    final int over = _lines.length - (keep < 0 ? 0 : keep);
    if (over > 0) {
      _lines.removeRange(0, over);
      _dropped += over;
    }
    value = List.unmodifiable([
      ..._lines,
      if (_partial.isNotEmpty)
        KitLogLine(_strip(_partial), level: _partialLevel, at: _partialAt),
    ]);
  }
}

/// The one log view (K2 §1.11, KIT-31).
///
/// States: empty, live, quiet, ended, failed, failed-to-read, scrolled-up,
/// dropped.
///
/// Follows the newest line until the person scrolls up (then a
/// [KitJumpPill] counts the new lines), calls [onRefresh] only while it is
/// on screen, redacts every line once ([KitRedact.text]) and says in words
/// whether the source is live, quiet or ended. The body is an LTR mono
/// block in every locale; the header follows the locale.
class KitLogPanel extends StatefulWidget {
  const KitLogPanel({
    super.key,
    required this.lines,
    this.title,
    this.live = false,
    this.ended,
    this.onRefresh,
    this.pollEvery = KitMotion.logPoll,
    this.follow = true,
    this.maxLines = defaultMaxLines,
    this.emptyText,
    this.size = KitLogSize.folded,
    this.wrap,
    this.onWrapChanged,
    this.panelKey,
    this.copyAllKey,
    this.wrapKey,
  });

  /// A [KitLogBuffer] or the caller's own listenable.
  final ValueListenable<List<KitLogLine>> lines;

  /// Header words; null is l10n.kitLogTitle ("Output").
  final String? title;

  /// Null is l10n.kitLogEmpty ("No output yet").
  final String? emptyText;

  /// The source is still writing.
  final bool live;

  /// Sticks to the newest line until the person scrolls up. False never
  /// auto-scrolls.
  final bool follow;

  /// The source finished; polling stops.
  final KitLogEnd? ended;

  /// Called every [pollEvery], only while the panel is visible, never
  /// overlapping, until [ended] is set.
  final Future<void> Function()? onRefresh;
  final Duration pollEvery;

  /// Lines kept on screen; older ones are dropped and counted.
  final int maxLines;
  final KitLogSize size;

  /// Null wraps on compact and scrolls sideways from medium (the Wrap
  /// toggle then flips the panel's own choice). Non-null is controlled:
  /// the toggle calls [onWrapChanged].
  final bool? wrap;
  final ValueChanged<bool>? onWrapChanged;

  /// The panel; null is `ValueKey('kit-log-panel')`.
  final Key? panelKey;

  /// Copy all; null is `ValueKey('kit-log-copy-all')`.
  final Key? copyAllKey;

  /// Wrap; null is `ValueKey('kit-log-wrap')`.
  final Key? wrapKey;

  /// Lines kept on screen; older ones are dropped and counted (honest state).
  static const int defaultMaxLines = 2000;

  /// The folded panel inside the one details fold (K2 §4.4: folded under
  /// Details unless the page exists to show the log). The fold's label is
  /// l10n.kitLogShowOutput ("Show output"). A page that already has a
  /// KitDetailsFold passes a KitLogPanel as that fold's `child` instead
  /// (one fold per page, KIT-33).
  static Widget fold({
    Key? key,
    required ValueListenable<List<KitLogLine>> lines,
    bool live = false,
    KitLogEnd? ended,
    Future<void> Function()? onRefresh,
    String? label,
    Key? foldKey,
    Key? panelKey,
  }) => Builder(
    key: key,
    builder: (context) => KitDetailsFold(
      label: label ?? _l10n(context).kitLogShowOutput,
      foldKey: foldKey,
      child: KitLogPanel(
        lines: lines,
        live: live,
        ended: ended,
        onRefresh: onRefresh,
        panelKey: panelKey,
      ),
    ),
  );

  @override
  State<KitLogPanel> createState() => _KitLogPanelState();
}

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Each line's redacted text, computed once when the line first reaches a
/// panel (G12, SEC-2).
final Expando<String> _redacted = Expando<String>('KitLogPanel.redacted');

String _safe(KitLogLine line) => _redacted[line] ??= KitRedact.text(line.text);

class _KitLogPanelState extends State<KitLogPanel> with WidgetsBindingObserver {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'KitLogPanel body');

  bool _following = true;
  int _unseen = 0;
  int _seenTotal = 0;
  bool? _ownWrap;
  DateTime _lastLineAt = clock.now();

  Timer? _poll;
  bool _polling = false;
  bool _readFailed = false;
  bool _tickerEnabled = true;
  bool _routeCurrent = true;
  bool _jumping = false;

  /// With wrap off every row has one extent, so the newest end is known
  /// exactly before the list lays out new rows: rows × extent. Null while
  /// wrapped (the list only estimates its extent then).
  double? _fixedContent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.lines.addListener(_onLines);
    _vertical.addListener(_onScroll);
    _seenTotal = _total(widget.lines.value);
    _lastLineAt = _latestAt(widget.lines.value) ?? clock.now();
    _scheduleJumpToEnd();
    _schedulePoll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
  }

  @override
  void didUpdateWidget(KitLogPanel old) {
    super.didUpdateWidget(old);
    if (old.lines != widget.lines) {
      old.lines.removeListener(_onLines);
      widget.lines.addListener(_onLines);
      _seenTotal = _total(widget.lines.value);
      _unseen = 0;
    }
    if (old.ended != widget.ended ||
        old.onRefresh != widget.onRefresh ||
        old.pollEvery != widget.pollEvery) {
      _poll?.cancel();
      _schedulePoll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.lines.removeListener(_onLines);
    _poll?.cancel();
    _vertical.dispose();
    _horizontal.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ---- lines and following ------------------------------------------------

  int _dropped(List<KitLogLine> lines) {
    final source = widget.lines;
    final buffered = source is KitLogBuffer ? source.dropped : 0;
    return buffered + math.max(0, lines.length - widget.maxLines);
  }

  int _total(List<KitLogLine> lines) => lines.length + _dropped(lines);

  static DateTime? _latestAt(List<KitLogLine> lines) =>
      lines.isEmpty ? null : lines.last.at;

  void _onLines() {
    if (!mounted) return;
    final lines = widget.lines.value;
    final total = _total(lines);
    final added = math.max(0, total - _seenTotal);
    _seenTotal = total;
    setState(() {
      if (added > 0) {
        _lastLineAt = _latestAt(lines) ?? clock.now();
        if (!_following || !widget.follow) _unseen += added;
      }
    });
    if (_following && widget.follow) _scheduleJumpToEnd();
  }

  /// Jumps to the newest line after the next layout. With wrapped lines the
  /// list only estimates its extent until the end is laid out, so it jumps
  /// again (a few frames at most) until it really sits at the end.
  void _scheduleJumpToEnd([int attempts = 3]) {
    if (!widget.follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_vertical.hasClients || !_following) return;
      final position = _vertical.position;
      if (position.pixels >= position.maxScrollExtent) return;
      _jumping = true;
      _vertical.jumpTo(position.maxScrollExtent);
      _jumping = false;
      if (attempts > 1) {
        _scheduleJumpToEnd(attempts - 1);
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  void _onScroll() {
    if (_jumping || !_vertical.hasClients) return;
    final position = _vertical.position;
    final atEnd =
        position.pixels >= position.maxScrollExtent - _lineExtent(context);
    if (atEnd == _following) return;
    setState(() {
      _following = atEnd;
      if (atEnd) _unseen = 0;
    });
  }

  Future<void> _jumpToLatest() async {
    setState(() {
      _following = true;
      _unseen = 0;
    });
    if (!_vertical.hasClients) return;
    final position = _vertical.position;
    final fixed = _fixedContent;
    final end = fixed == null
        ? position.maxScrollExtent
        : math.max(
            position.maxScrollExtent,
            fixed - position.viewportDimension,
          );
    _jumping = true;
    try {
      if (KitMotion.reduced(context)) {
        _vertical.jumpTo(end);
      } else {
        await _vertical.animateTo(
          end,
          duration: KitMotion.standard,
          curve: KitMotion.enter,
        );
        if (mounted && _vertical.hasClients) {
          _vertical.jumpTo(_vertical.position.maxScrollExtent);
        }
      }
    } finally {
      _jumping = false;
      if (mounted) _scheduleJumpToEnd();
    }
  }

  // ---- polling (PERF-4) ---------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll?.cancel();
      _schedulePoll();
    }
  }

  void _schedulePoll() {
    if (widget.onRefresh == null || widget.ended != null || _readFailed) {
      return;
    }
    _poll = Timer(widget.pollEvery, _tick);
  }

  bool get _visible {
    if (!mounted || !_tickerEnabled || !_routeCurrent) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final scrollable = Scrollable.maybeOf(context);
    final Rect viewport;
    final host = scrollable?.context.findRenderObject();
    if (host is RenderBox && host.attached && host.hasSize) {
      viewport = host.localToGlobal(Offset.zero) & host.size;
    } else {
      final view = View.of(context);
      viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    }
    final overlap = rect.intersect(viewport);
    return overlap.width > 0 && overlap.height > 0;
  }

  Future<void> _tick() async {
    if (!mounted) return;
    // A lifecycle pause stops the loop; resume restarts it.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (!_visible) {
      _schedulePoll();
      return;
    }
    await _refresh();
    if (mounted) _schedulePoll();
  }

  Future<bool> _refresh() async {
    final refresh = widget.onRefresh;
    if (refresh == null || _polling) return false;
    _polling = true;
    try {
      await refresh();
      if (mounted && _readFailed) setState(() => _readFailed = false);
      return true;
    } catch (_) {
      if (mounted) setState(() => _readFailed = true);
      return false;
    } finally {
      _polling = false;
    }
  }

  Future<void> _tryAgain() async {
    _poll?.cancel();
    final ok = await _refresh();
    if (ok && mounted) _schedulePoll();
  }

  // ---- layout -------------------------------------------------------------

  TextStyle _mono(BuildContext context, KitTextTone tone) =>
      KitText.styleOf(context, KitTextRole.mono, tone: tone);

  double _glyph(BuildContext context) {
    final tokens = KitTokens.of(context);
    return tokens.iconSize(context, tokens.smallIconSize);
  }

  /// One fixed line extent per text scale: the mono line height or the
  /// gutter glyph, whichever is larger.
  double _lineExtent(BuildContext context) {
    final base = KitText.styleFor(KitTextRole.mono);
    final line =
        MediaQuery.textScalerOf(context).scale(base.fontSize!) * base.height!;
    return math.max(line, _glyph(context)).ceilToDouble();
  }

  bool _wrapOn(BuildContext context) =>
      widget.wrap ??
      _ownWrap ??
      KitLayout.windowOf(context) == KitWindow.compact;

  void _toggleWrap(bool current) {
    final next = !current;
    if (widget.wrap == null) setState(() => _ownWrap = next);
    widget.onWrapChanged?.call(next);
  }

  String _copyText(List<KitLogLine> shown, int dropped) => [
    if (dropped > 0) _l10n(context).kitLogDropped(dropped),
    for (final line in shown) _safe(line),
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final all = widget.lines.value;
    final shown = all.length > widget.maxLines
        ? all.sublist(all.length - widget.maxLines)
        : all;
    final dropped = _dropped(all);
    final wrap = _wrapOn(context);
    final extent = _lineExtent(context);
    final folded = widget.size == KitLogSize.folded;
    _fixedContent = wrap
        ? null
        : (shown.length + (dropped > 0 ? 1 : 0)) * extent;

    final header = _Header(
      title: widget.title ?? _l10n(context).kitLogTitle,
      live: widget.live,
      ended: widget.ended,
      readFailed: _readFailed,
      lastLineAt: _lastLineAt,
      hasLines: shown.isNotEmpty,
      wrap: wrap,
      wrapKey: widget.wrapKey ?? const ValueKey('kit-log-wrap'),
      copyAllKey: widget.copyAllKey ?? const ValueKey('kit-log-copy-all'),
      onWrap: () => _toggleWrap(wrap),
      copyText: () => _copyText(shown, dropped),
    );

    Widget body = _body(context, shown, dropped, wrap, extent);
    body = KitJumpPillLayer(
      clearBottomInset: false,
      pill: KitJumpPill(
        label: _l10n(context).kitLogNewLines(_unseen),
        visible: widget.follow && !_following && _unseen > 0,
        pillKey: const ValueKey('kit-log-jump'),
        onPressed: _jumpToLatest,
      ),
      child: body,
    );
    if (folded) {
      final window = MediaQuery.sizeOf(context).height;
      final height = math.min(
        KitTokens.logFoldedLines * extent + tokens.space2 * 2,
        window / 2,
      );
      body = SizedBox(height: height.floorToDouble(), child: body);
    } else {
      body = Expanded(child: body);
    }

    final column = Column(
      mainAxisSize: folded ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (_readFailed)
          Padding(
            key: const ValueKey('kit-log-read-failed'),
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.space3,
              tokens.space2,
              tokens.space3,
              0,
            ),
            child: KitNotice.error(
              message: _l10n(context).kitLogReadFailed,
              retry: KitAction(
                label: _l10n(context).kitTryAgain,
                onPressed: _tryAgain,
              ),
            ),
          ),
        body,
      ],
    );

    return DecoratedBox(
      key: widget.panelKey ?? const ValueKey('kit-log-panel'),
      decoration: BoxDecoration(
        color: tokens.detailsSurface,
        borderRadius: folded
            ? BorderRadius.circular(tokens.detailsRadius)
            : BorderRadius.zero,
      ),
      child: ClipRRect(
        borderRadius: folded
            ? BorderRadius.circular(tokens.detailsRadius)
            : BorderRadius.zero,
        child: column,
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<KitLogLine> shown,
    int dropped,
    bool wrap,
    double extent,
  ) {
    final tokens = KitTokens.of(context);
    if (shown.isEmpty && dropped == 0) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: KitText(
            widget.emptyText ?? _l10n(context).kitLogEmpty,
            role: KitTextRole.secondary,
            tone: KitTextTone.tertiary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    final extra = dropped > 0 ? 1 : 0;
    final glyph = _glyph(context);
    final gutter = glyph + tokens.space2;
    // Vertical padding sits outside the scroll viewport, so the viewport is
    // a whole number of lines tall and no line is left cut to a sliver at
    // either edge when the view rests at the newest line.
    final padding = EdgeInsets.symmetric(horizontal: tokens.space3);

    Widget row(BuildContext context, int index) {
      if (index < extra) {
        return _DroppedRow(
          text: _l10n(context).kitLogDropped(dropped),
          wrap: wrap,
          gutter: gutter,
        );
      }
      final i = index - extra;
      return _LineRow(
        key: ValueKey('kit-log-line-$i'),
        line: shown[i],
        wrap: wrap,
        glyph: glyph,
        gutter: gutter,
        extent: extent,
        style: _mono(
          context,
          shown[i].level == KitLogLevel.normal
              ? KitTextTone.secondary
              : KitTextTone.primary,
        ),
      );
    }

    final wide = KitLayout.windowOf(context).isWide;

    Widget list(double? width) => ListView.builder(
      controller: _vertical,
      padding: padding,
      itemExtent: wrap ? null : extent,
      itemCount: shown.length + extra,
      itemBuilder: row,
    );

    Widget content;
    if (wrap) {
      content = list(null);
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final charWidth = _charWidth(context);
          var longest = 0;
          for (final line in shown) {
            longest = math.max(longest, _safe(line).length);
          }
          final needed =
              (longest + 1) * charWidth + gutter + padding.horizontal;
          final width = math.max(constraints.maxWidth, needed.ceilToDouble());
          return SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: list(width),
            ),
          );
        },
      );
    }
    // Desktop scrollbars come from the app's scroll behaviour
    // (AppScrollBehavior), always visible on a desktop build (KIT-6).
    if (wide) content = SelectionArea(child: content);

    return Focus(
      focusNode: _bodyFocus,
      onKeyEvent: _onKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.space2),
          child: content,
        ),
      ),
    );
  }

  double _charWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: _mono(context, KitTextTone.secondary)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_vertical.hasClients) return KeyEventResult.ignored;
    final position = _vertical.position;
    final extent = _lineExtent(context);
    double? to;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      to = position.pixels + extent;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      to = position.pixels - extent;
    } else if (key == LogicalKeyboardKey.pageDown) {
      to = position.pixels + position.viewportDimension;
    } else if (key == LogicalKeyboardKey.pageUp) {
      to = position.pixels - position.viewportDimension;
    } else if (key == LogicalKeyboardKey.home) {
      to = position.minScrollExtent;
    } else if (key == LogicalKeyboardKey.end) {
      unawaited(_jumpToLatest());
      return KeyEventResult.handled;
    }
    if (to == null) return KeyEventResult.ignored;
    _vertical.jumpTo(
      to.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return KeyEventResult.handled;
  }
}

/// Title, state words (the panel's one polite live region), Wrap and Copy
/// all.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.live,
    required this.ended,
    required this.readFailed,
    required this.lastLineAt,
    required this.hasLines,
    required this.wrap,
    required this.wrapKey,
    required this.copyAllKey,
    required this.onWrap,
    required this.copyText,
  });

  final String title;
  final bool live;
  final KitLogEnd? ended;
  final bool readFailed;
  final DateTime lastLineAt;
  final bool hasLines;
  final bool wrap;
  final Key wrapKey;
  final Key copyAllKey;
  final VoidCallback onWrap;
  final String Function() copyText;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = _l10n(context);
    final end = ended;

    Widget words;
    if (readFailed) {
      words = const SizedBox.shrink();
    } else if (end != null) {
      final code = end.exitCode == null ? null : KitBidi.ltr('${end.exitCode}');
      final state = end.failed
          ? (code == null ? l10n.kitLogFailed : l10n.kitLogFailedExit(code))
          : (code == null ? l10n.kitLogEnded : l10n.kitLogEndedExit(code));
      words = _StateWords(text: state, reason: end.reason, failed: end.failed);
    } else if (live) {
      words = KitSince(
        since: lastLineAt,
        ticks: KitSinceTicks.minutes,
        builder: (context, status) {
          if (!status.isSlow) {
            return _StateWords(text: l10n.kitLogLive, dot: true);
          }
          final elapsed = status.elapsed;
          final text = elapsed.inMinutes < 1
              ? l10n.kitLogQuietSeconds(elapsed.inSeconds)
              : l10n.kitLogQuiet(KitSince.ageLabel(context, elapsed));
          return _StateWords(text: text);
        },
      );
    } else {
      words = const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: tokens.roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: tokens.space3),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.space2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: tokens.space2,
                  runSpacing: tokens.space1,
                  children: [
                    KitText(title, role: KitTextRole.label),
                    words,
                  ],
                ),
              ),
            ),
            KitIconButton(
              key: wrapKey,
              icon: AppIconography.wrapText,
              tooltip: l10n.kitWrapLines,
              selected: wrap,
              size: 20,
              onPressed: onWrap,
            ),
            if (hasLines)
              KitIconButton.copy(
                key: copyAllKey,
                text: copyText,
                tooltip: l10n.kitCopyAll,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _StateWords extends StatelessWidget {
  const _StateWords({
    required this.text,
    this.reason,
    this.dot = false,
    this.failed = false,
  });

  final String text;
  final String? reason;
  final bool dot;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final glyph = tokens.iconSize(context, tokens.smallIconSize);
    final label = reason == null ? text : '$text. $reason';
    return Semantics(
      liveRegion: true,
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot) ...[
                  SizedBox.square(
                    key: const ValueKey('kit-log-live-dot'),
                    dimension: tokens.space2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.roles.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.space1),
                ],
                if (failed) ...[
                  Icon(
                    AppIconography.error,
                    size: glyph,
                    color: tokens.roles.text3,
                  ),
                  SizedBox(width: tokens.space1),
                ],
                Flexible(
                  child: KitText(
                    text,
                    role: KitTextRole.caption,
                    tone: KitTextTone.primary,
                  ),
                ),
              ],
            ),
            if (reason != null) KitText(reason!, role: KitTextRole.caption),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.line,
    required this.wrap,
    required this.glyph,
    required this.gutter,
    required this.extent,
    required this.style,
  });

  final KitLogLine line;
  final bool wrap;
  final double glyph;
  final double gutter;
  final double extent;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = _l10n(context);
    final text = _safe(line);
    final icon = switch (line.level) {
      KitLogLevel.normal => null,
      KitLogLevel.warning => AppIconography.warning,
      KitLogLevel.error => AppIconography.error,
    };
    final label = switch (line.level) {
      KitLogLevel.normal => text,
      KitLogLevel.warning => l10n.kitLogWarningLine(text),
      KitLogLevel.error => l10n.kitLogErrorLine(text),
    };
    // The semantics node hugs the words (not the row), so a screen reader's
    // focus box and the contrast check both see the text itself.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: extent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: gutter,
            child: icon == null
                ? null
                : Align(
                    alignment: Alignment.topLeft,
                    child: ExcludeSemantics(
                      child: Icon(icon, size: glyph, color: tokens.roles.text3),
                    ),
                  ),
          ),
          Flexible(
            child: Semantics(
              label: label,
              child: ExcludeSemantics(
                child: Text(
                  text,
                  style: style,
                  softWrap: wrap,
                  maxLines: wrap ? null : 1,
                  overflow: wrap ? null : TextOverflow.clip,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DroppedRow extends StatelessWidget {
  const _DroppedRow({
    required this.text,
    required this.wrap,
    required this.gutter,
  });

  final String text;
  final bool wrap;
  final double gutter;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('kit-log-dropped'),
    padding: EdgeInsetsDirectional.only(start: gutter),
    child: Text(
      text,
      style: KitText.styleOf(
        context,
        KitTextRole.mono,
        tone: KitTextTone.tertiary,
      ),
      maxLines: wrap ? null : 1,
      softWrap: wrap,
      overflow: wrap ? null : TextOverflow.clip,
    ),
  );
}
