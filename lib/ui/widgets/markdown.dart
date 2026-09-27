// Retired by kit-KitMarkdown (docs/ux-system/kit-api/KitMarkdown.md,
// Compatibility): the parser, table, headings, quotes, lists, inline parser
// and path chip live in lib/ui/kit/chat/kit_markdown.dart. What stays here
// forwards to the kit, so callers keep compiling until their unit moves
// them. No @Deprecated (KIT-43 wins over R12).
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import '../kit/chat/kit_markdown.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_code_block.dart';
import '../kit/kit_page_route.dart';
import '../kit/kit_screen.dart';
import '../kit/kit_shape.dart';
import '../kit/kit_surface.dart';
import '../kit/kit_text.dart';
import '../kit/kit_top_bar.dart';
import 'agent_blocks.dart';
import 'reader_preferences.dart';
import 'transcript_highlight.dart';

/// Restricts markdown to local presentation in isolated previews. Defaults to
/// normal product interaction when no scope is installed.
class MarkdownInteractionScope extends InheritedWidget {
  const MarkdownInteractionScope({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;
  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MarkdownInteractionScope>()
          ?.enabled ??
      true;
  @override
  bool updateShouldNotify(MarkdownInteractionScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Installed by screens that can resolve server file paths. Inline code
/// spans that look like paths stay plain until [validate] confirms the file
/// is actually readable on the connected server; only then do they render
/// as tappable links routed through [open].
class MarkdownFileLinks extends InheritedWidget {
  const MarkdownFileLinks({
    super.key,
    required this.validate,
    required this.open,
    required super.child,
  });

  /// Must be memoized by the provider: spans re-request on every rebuild.
  final Future<bool> Function(String path) validate;
  final void Function(String path) open;

  static MarkdownFileLinks? maybeOf(BuildContext context) =>
      MarkdownInteractionScope.enabledOf(context)
      ? context.dependOnInheritedWidgetOfExactType<MarkdownFileLinks>()
      : null;

  @override
  bool updateShouldNotify(MarkdownFileLinks oldWidget) =>
      validate != oldWidget.validate || open != oldWidget.open;
}

/// Retired by kit-KitMarkdown: use KitMarkdown.looksLikeFilePath.
bool looksLikeFilePath(String code) => KitMarkdown.looksLikeFilePath(code);

/// Retired by kit-KitMarkdown: use KitMarkdown.stripPathLineSuffix.
String stripPathLineSuffix(String code) =>
    KitMarkdown.stripPathLineSuffix(code);

/// Retired by kit-KitMarkdown: use KitMarkdown.proseForSpeech.
String markdownProseForSpeech(String source) =>
    KitMarkdown.proseForSpeech(source);

/// Retired by kit-KitMarkdown: use KitMarkdown.
///
/// Forwards to [KitMarkdown]: a non-null [baseStyle] means the secondary
/// role and tone, the agent blocks arrive through the block builder, the
/// find-in-conversation highlight through the highlighter, and the
/// interaction, file-link and reader-preference scopes are read here.
class MarkdownText extends StatefulWidget {
  final String data;
  final TextStyle? baseStyle;
  final String? codeBlockLanguage;

  /// Chat bubbles that own a long-press action menu render non-selectable
  /// prose so the gesture reaches the menu instead of text selection.
  final bool selectable;

  /// Receives the text of a tapped option from a ```choices block. Without a
  /// handler the option is copied to the clipboard instead.
  final ValueChanged<String>? onChoice;

  const MarkdownText(
    this.data, {
    super.key,
    this.baseStyle,
    this.codeBlockLanguage,
    this.selectable = true,
    this.onChoice,
  });

  /// Counts full block re-parses; reads [KitMarkdown.debugParseCount].
  @visibleForTesting
  static int get debugParseCount => KitMarkdown.debugParseCount;

  @visibleForTesting
  static set debugParseCount(int value) => KitMarkdown.debugParseCount = value;

  @override
  State<MarkdownText> createState() => _MarkdownTextState();
}

class _MarkdownTextState extends State<MarkdownText> {
  MarkdownFileLinks? _linksSource;
  KitMarkdownFileLinks? _links;

  /// One stable value per host scope, so the kit's own scope does not
  /// notify every block on each rebuild.
  KitMarkdownFileLinks? _fileLinks(MarkdownFileLinks? source) {
    if (source == null) return _links = _linksSource = null;
    if (_linksSource == null ||
        _linksSource!.validate != source.validate ||
        _linksSource!.open != source.open) {
      _linksSource = source;
      _links = KitMarkdownFileLinks(
        validate: source.validate,
        open: source.open,
      );
    }
    return _links;
  }

  /// Fences with a reserved info string render as agent blocks; see
  /// [AgentBlockKinds].
  Widget? _agentBlock(BuildContext context, String info, String body) {
    if (!AgentBlockKinds.matches(info)) return null;
    return switch (info.trim().toLowerCase()) {
      AgentBlockKinds.choices => AgentChoicesBlock(
        options: AgentChoicesBlock.parse(body),
      ),
      AgentBlockKinds.checklist => AgentChecklistBlock(
        items: AgentChecklistBlock.parse(body),
      ),
      _ => AgentCommandBlock(commands: AgentCommandBlock.parse(body)),
    };
  }

  void _saveWrap(bool wrap) => saveReaderPreferences(context, wrapCode: wrap);

  void _openCode(String code, String? language) {
    final store = ReaderPreferencesScope.maybeOf(context);
    pushKitPage<void>(
      context,
      (_) => _CodeReaderPage(
        code: code,
        language: language,
        initialWrap: store?.value.wrapCode,
        onWrapChanged: store == null ? null : _saveWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = MarkdownInteractionScope.enabledOf(context);
    final preferences = ReaderPreferencesScope.maybeOf(context);
    final secondary = widget.baseStyle != null;
    return AgentChoiceScope(
      onChoice: widget.onChoice,
      child: KitMarkdown(
        widget.data,
        role: secondary ? KitTextRole.secondary : KitTextRole.body,
        tone: secondary ? KitTextTone.secondary : null,
        selectable: widget.selectable,
        interactive: interactive,
        blockBuilder: _agentBlock,
        highlighter: TranscriptHighlight.decorate,
        fileLinks: _fileLinks(MarkdownFileLinks.maybeOf(context)),
        codeWrap: preferences?.value.wrapCode,
        onCodeWrapChanged: preferences == null ? null : _saveWrap,
        onOpenCode: _openCode,
        codeLanguage: widget.codeBlockLanguage,
      ),
    );
  }
}

/// The full-screen code reader a capped block opens: the snapshot taken at
/// the tap, filling the page.
class _CodeReaderPage extends StatefulWidget {
  const _CodeReaderPage({
    required this.code,
    required this.language,
    required this.initialWrap,
    required this.onWrapChanged,
  });

  final String code;
  final String? language;
  final bool? initialWrap;
  final ValueChanged<bool>? onWrapChanged;

  @override
  State<_CodeReaderPage> createState() => _CodeReaderPageState();
}

class _CodeReaderPageState extends State<_CodeReaderPage> {
  late bool? _wrap = widget.initialWrap;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final wrap = _wrap ?? KitCodeBlock.defaultWrap(context, KitCodeKind.code);
    return KitSurface(
      level: KitSurfaceLevel.ground,
      shape: KitShape.square,
      padding: KitSurfacePadding.none,
      child: SafeArea(
        child: KitScreen(
          header: [
            KitTopBar(
              title: l10n.markdownReaderTitle,
              actions: [
                KitAction(
                  label: wrap ? l10n.markdownScrollCode : l10n.markdownWrapCode,
                  icon: AppIconography.wrapText,
                  onPressed: () {
                    setState(() => _wrap = !wrap);
                    widget.onWrapChanged?.call(!wrap);
                  },
                ),
                KitAction.copy(
                  label: l10n.kitCodeCopyCode,
                  icon: AppIconography.copy,
                  text: () => widget.code,
                ),
              ],
            ),
          ],
          body: KitCodeBlock.fill(
            text: widget.code,
            language: widget.language,
            copyText: widget.code,
            wrap: wrap,
          ),
        ),
      ),
    );
  }
}

/// Retired by kit-KitMarkdown: use KitCodeBlock.
///
/// Selectable local code with independent display wrapping and exact
/// copying, forwarded to [KitCodeBlock].
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.originalSource,
    this.language,
    this.highlightEnabled = true,
    this.initialWrap = false,
    this.canExpand = true,
  });
  final String code;

  /// Original fence body, before line-ending/indent display normalization.
  /// Direct callers omit this: their [code] is already the exact source.
  final String? originalSource;
  final String? language;
  final bool highlightEnabled;
  final bool initialWrap;
  final bool canExpand;

  @override
  Widget build(BuildContext context) {
    final interactive = MarkdownInteractionScope.enabledOf(context);
    final preferences = ReaderPreferencesScope.maybeOf(context);
    // A fixed `wrap` would freeze the block's own toggle, so wrap is only
    // pinned by the reader preference or by a caller that starts wrapped.
    final wrap = preferences?.value.wrapCode ?? (initialWrap ? true : null);
    return IgnorePointer(
      ignoring: !interactive,
      child: KitCodeBlock(
        text: code,
        copyText: originalSource,
        language: language,
        highlight: highlightEnabled,
        wrap: wrap,
        onWrapChanged: preferences == null
            ? null
            : (value) => saveReaderPreferences(context, wrapCode: value),
        maxLines: canExpand ? 12 : null,
        copyable: interactive,
        showWrapToggle: interactive,
      ),
    );
  }
}
