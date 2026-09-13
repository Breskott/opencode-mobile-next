import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/delimited_text.dart';
import '../../l10n/app_localizations.dart';
import 'delimited_file_preview.dart';
import 'svg_file_preview.dart';
import 'pdf_file_preview.dart';
import 'markdown.dart';
import 'reader_preferences.dart';
import 'product_states.dart';
import '../app_theme.dart';

/// Normalized file content that can be rendered by [FilePreviewBody].
class FilePreviewData {
  FilePreviewData({
    required this.name,
    String? mimeType,
    this.bytes,
    String? text,
    this.originalText,
    this.truncated = false,
    this.error,
  }) : mimeType = _normalizedMime(mimeType) ?? _mimeFromName(name),
       text =
           text ??
           _decodeText(
             bytes,
             _normalizedMime(mimeType) ?? _mimeFromName(name),
             name,
           );

  factory FilePreviewData.fromDataUrl({
    required String name,
    required String? mimeType,
    required String? url,
  }) {
    final normalizedMime = _normalizedMime(mimeType);
    if (url == null || url.trim().isEmpty) {
      return FilePreviewData(
        name: name,
        mimeType: normalizedMime,
        error: 'The attachment content is not included in this message.',
      );
    }
    if (!url.startsWith('data:')) {
      return FilePreviewData(
        name: name,
        mimeType: normalizedMime,
        error: 'Remote attachment previews are not available.',
      );
    }

    try {
      final data = UriData.parse(url);
      final resolvedMime = normalizedMime ?? _normalizedMime(data.mimeType);
      final bytes = Uint8List.fromList(data.contentAsBytes());
      return FilePreviewData(name: name, mimeType: resolvedMime, bytes: bytes);
    } on FormatException {
      return FilePreviewData(
        name: name,
        mimeType: normalizedMime,
        error: 'The attachment data could not be decoded.',
      );
    }
  }

  final String name;
  final String? mimeType;
  final Uint8List? bytes;
  final String? text;

  /// Full source when the caller supplies only a bounded display excerpt.
  final String? originalText;
  final bool truncated;
  final String? error;

  String? get copyText => originalText ?? text;
  String? get separator => DelimitedText.separator(name, mimeType);

  static String? _decodeText(Uint8List? bytes, String? mime, String name) {
    if (bytes == null ||
        (!_isTextMime(mime) && DelimitedText.separator(name, mime) == null)) {
      return null;
    }
    try {
      final value = utf8.decode(bytes);
      if (value.contains('\u0000')) return null;
      return value;
    } on FormatException {
      return null;
    }
  }

  bool get isRasterImage => switch (mimeType) {
    'image/png' ||
    'image/jpeg' ||
    'image/gif' ||
    'image/webp' ||
    'image/bmp' => true,
    _ => false,
  };

  int? get byteLength => bytes?.length;

  Uint8List? get exportBytes {
    if (bytes != null) return bytes;
    if (copyText != null) return Uint8List.fromList(utf8.encode(copyText!));
    return null;
  }

  static String? _normalizedMime(String? value) {
    final normalized = value?.split(';').first.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? _mimeFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return switch (name.substring(dot + 1).toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'tsv' => 'text/tab-separated-values',
      'xml' => 'application/xml',
      'md' ||
      'txt' ||
      'log' ||
      'dart' ||
      'js' ||
      'ts' ||
      'tsx' ||
      'jsx' ||
      'py' ||
      'go' ||
      'rs' ||
      'yaml' ||
      'yml' => 'text/plain',
      _ => null,
    };
  }

  static bool _isTextMime(String? mime) =>
      mime?.startsWith('text/') == true ||
      mime == 'application/json' ||
      mime == 'application/javascript' ||
      mime == 'application/xml' ||
      mime == 'image/svg+xml';
}

Future<void> showFilePreviewSheet(
  BuildContext context,
  FilePreviewData data, {
  Future<void> Function()? onAttach,
  Future<void> Function()? onDownload,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  // Feedback and Retry must sit above this modal, not on the obscured page.
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .86,
    child: ScaffoldMessenger(
      child: Scaffold(
        backgroundColor:
            Theme.of(context).bottomSheetTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        body: _FilePreviewSheet(
          data: data,
          onAttach: onAttach,
          onDownload: onDownload,
        ),
      ),
    ),
  ),
);

class _FilePreviewSheet extends StatefulWidget {
  const _FilePreviewSheet({required this.data, this.onAttach, this.onDownload});

  final FilePreviewData data;
  final Future<void> Function()? onAttach;
  final Future<void> Function()? onDownload;

  @override
  State<_FilePreviewSheet> createState() => _FilePreviewSheetState();
}

class _FilePreviewSheetState extends State<_FilePreviewSheet> {
  bool _attaching = false;
  bool _downloading = false;

  Future<void> _copy(String original) async {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    try {
      await Clipboard.setData(ClipboardData(text: original));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fileCopied)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fileCopyFailed),
          action: SnackBarAction(
            label: l10n.markdownCopyRetry,
            onPressed: () => _copy(original),
          ),
        ),
      );
    }
  }

  Future<void> _attach() async {
    final action = widget.onAttach;
    if (action == null || _attaching) return;
    setState(() => _attaching = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showProductError(context, error);
      setState(() => _attaching = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    final bytes = widget.data.exportBytes;
    if (bytes == null) return;
    setState(() => _downloading = true);
    try {
      final action = widget.onDownload;
      if (action != null) {
        await action();
      } else {
        final savedPath = await FilePicker.saveFile(
          dialogTitle: readerL10n(context).readerUiSaveNamed(widget.data.name),
          fileName: widget.data.name,
          bytes: bytes,
        );
        if (mounted && savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                readerL10n(context).readerUiSaved(widget.data.name),
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) showProductError(context, error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    return SizedBox(
      key: const Key('file-preview-sheet'),
      height: MediaQuery.sizeOf(context).height * .86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Icon(
                  data.isRasterImage
                      ? AppIconography.image
                      : AppIconography.fileText,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _metadata(context, data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.copyText != null)
                  IconButton(
                    tooltip: readerL10n(context).readerUiCopyContents,
                    onPressed: () => _copy(data.copyText!),
                    icon: const Icon(AppIcons.copy, size: 19),
                  ),
                if (widget.onAttach != null)
                  IconButton(
                    key: const Key('file-preview-attach'),
                    tooltip: readerL10n(context).readerUiAttachPrompt,
                    onPressed: _attaching ? null : _attach,
                    icon: _attaching
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIconography.attach, size: 20),
                  ),
                if (data.exportBytes != null)
                  IconButton(
                    key: const Key('file-preview-download'),
                    tooltip: readerL10n(context).readerUiSaveDevice,
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIconography.download, size: 20),
                  ),
                IconButton(
                  tooltip: readerL10n(context).readerUiClosePreview,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIconography.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: FilePreviewBody(data: data)),
        ],
      ),
    );
  }
}

/// Renders supported file content without sending it to another application.
class FilePreviewBody extends StatelessWidget {
  const FilePreviewBody({super.key, required this.data, this.initialLine});

  final FilePreviewData data;
  final int? initialLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.error != null) {
      return _PreviewNotice(
        icon: AppIconography.hidden,
        title: readerL10n(context).readerUiPreviewUnavailable,
        message: switch (data.error!) {
          'The attachment content is not included in this message.' =>
            readerL10n(context).readerUiAttachmentMissing,
          'Remote attachment previews are not available.' => readerL10n(
            context,
          ).readerUiRemoteAttachment,
          'The attachment data could not be decoded.' => readerL10n(
            context,
          ).readerUiAttachmentInvalid,
          final message => message,
        },
      );
    }
    if (data.isRasterImage && data.bytes?.isNotEmpty == true) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerLowest,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: .75,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(48),
                child: Center(
                  child: Image.memory(
                    data.bytes!,
                    key: const Key('file-preview-image'),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _PreviewNotice(
                      icon: AppIconography.imageBroken,
                      title: readerL10n(context).readerUiImageFailed,
                      message: readerL10n(context).readerUiImageUnsupported,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    readerL10n(context).readerUiPinchZoom,
                    style: TextStyle(fontSize: AppTheme.captionFontSize),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (data.text != null) {
      if (initialLine != null) {
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        final lineCount = '\n'.allMatches(data.text!).length + 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.truncated)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.filePreviewPartialSource),
              ),
            if (initialLine! < 1 || initialLine! > lineCount)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.fileLineOutsidePreview(initialLine!)),
              ),
            Expanded(
              child: _FocusedSourcePreview(
                text: data.text!,
                initialLine: initialLine!,
              ),
            ),
          ],
        );
      }
      if (data.separator != null) {
        return DelimitedFilePreview(
          text: data.text!,
          original: data.copyText!,
          separator: data.separator!,
          truncated: data.truncated,
        );
      }
      if (data.mimeType == 'image/svg+xml') {
        return SvgFilePreview(
          source: data.text!,
          original: data.copyText!,
          truncated: data.truncated,
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).filePreviewPartialSource,
                ),
              ),
            SmartTextPreview(key: const Key('file-preview-text'), data: data),
          ],
        ),
      );
    }
    if (data.mimeType == 'application/pdf' && data.bytes?.isNotEmpty == true) {
      return PdfFilePreview(bytes: data.bytes!);
    }
    return _PreviewNotice(
      icon: AppIconography.file,
      title: readerL10n(context).readerUiPreviewUnavailable,
      message: [
        data.mimeType ?? readerL10n(context).readerUiUnknownType,
        if (data.byteLength != null)
          readerL10n(context).readerUiBytes(data.byteLength!),
        readerL10n(context).readerUiFormatUnsupported,
      ].join('\n'),
    );
  }
}

class _FocusedSourcePreview extends StatefulWidget {
  final String text;
  final int initialLine;

  const _FocusedSourcePreview({required this.text, required this.initialLine});

  @override
  State<_FocusedSourcePreview> createState() => _FocusedSourcePreviewState();
}

class _FocusedSourcePreviewState extends State<_FocusedSourcePreview> {
  static const _lineHeight = 24.0;

  /// Gutter (line numbers), gap, and a little breathing room after the
  /// longest line.
  static const _trailingPadding = 24.0;

  late List<String> _lines = widget.text.split('\n');
  int get _targetLine =>
      widget.initialLine >= 1 && widget.initialLine <= _lines.length
      ? widget.initialLine
      : 0;
  late final ScrollController _vertical = ScrollController(
    initialScrollOffset: ((_targetLine - 1) * _lineHeight - _lineHeight * 2)
        .clamp(0, (_lines.length - 1) * _lineHeight),
  );
  final ScrollController _horizontal = ScrollController();

  /// The measured width of the widest line, cached until the content, the
  /// text style, or the text scale changes — never guessed per character.
  bool _positioned = false;
  double? _widestLineWidth;
  TextStyle? _measuredStyle;
  TextScaler? _measuredScaler;

  @override
  void didUpdateWidget(covariant _FocusedSourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lines = widget.text.split('\n');
      _widestLineWidth = null;
      _positioned = false;
    }
  }

  double _widestLine(TextStyle style, TextScaler scaler) {
    final cached = _widestLineWidth;
    if (cached != null &&
        _measuredStyle == style &&
        _measuredScaler == scaler) {
      return cached;
    }
    // Monospace: the longest line is the widest, so one layout pass measures
    // the whole file.
    var longest = '';
    for (final line in _lines) {
      if (line.length > longest.length) longest = line;
    }
    final painter = TextPainter(
      text: TextSpan(text: longest, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    _widestLineWidth = width;
    _measuredStyle = style;
    _measuredScaler = scaler;
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: AppTheme.monoFamily,
      height: 1.35,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final widest = codeStyle == null ? 0.0 : _widestLine(codeStyle, scaler);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrap =
            ReaderPreferencesScope.maybeOf(context)?.value.wrapCode ?? false;
        final lineHeight = scaler.scale(14) * 1.35 + 8;
        final gutterPainter = TextPainter(
          text: TextSpan(
            text: '${_lines.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: AppTheme.monoFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final gutter = gutterPainter.width + 20;
        gutterPainter.dispose();
        final contentWidth = wrap
            ? constraints.maxWidth
            : (widest + gutter + _trailingPadding).clamp(
                constraints.maxWidth,
                double.infinity,
              );
        final codeWidth = (contentWidth - gutter - 12).clamp(
          1.0,
          double.infinity,
        );
        final heights = <double>[];
        for (final line in _lines) {
          if (!wrap) {
            heights.add(lineHeight);
            continue;
          }
          final painter = TextPainter(
            text: TextSpan(text: line.isEmpty ? ' ' : line, style: codeStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout(maxWidth: codeWidth);
          heights.add((painter.height + 8).clamp(lineHeight, double.infinity));
          painter.dispose();
        }
        if (!_positioned) {
          _positioned = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_vertical.hasClients || _targetLine == 0) return;
            double sum(Iterable<double> values) =>
                values.fold<double>(0, (a, b) => a + b);
            final targetTop = sum(heights.take(_targetLine - 1));
            final targetHeight = heights[_targetLine - 1];
            final context = sum(
              heights.skip((_targetLine - 3).clamp(0, heights.length)).take(2),
            );
            // Show two rows of context above the target, but never at the
            // cost of pushing the target itself out of the viewport: wrapped
            // rows at large text scales can each fill most of the screen.
            final position = _vertical.position;
            final offset = math.max(
              targetTop - context,
              targetTop + targetHeight - position.viewportDimension,
            );
            _vertical.jumpTo(
              offset.clamp(0.0, math.min(targetTop, position.maxScrollExtent)),
            );
          });
        }
        final list = SelectionArea(
          child: ListView.builder(
            key: const Key('file-preview-focused-source'),
            controller: _vertical,
            itemExtentBuilder: (index, _) => heights[index],
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final selected = index + 1 == _targetLine;
              return ColoredBox(
                key: selected ? const Key('file-preview-target-line') : null,
                color: selected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: .45)
                    : Colors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: gutter,
                      child: SelectionContainer.disabled(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFamily: AppTheme.monoFamily,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _lines[index].isEmpty ? ' ' : _lines[index],
                          softWrap: wrap,
                          maxLines: wrap ? null : 1,
                          textDirection: TextDirection.ltr,
                          style: codeStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        return Directionality(
          textDirection: TextDirection.ltr,
          child: wrap
              ? list
              : Scrollbar(
                  controller: _horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      height: constraints.maxHeight,
                      child: list,
                    ),
                  ),
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }
}

/// Renders textual artifacts according to their actual content while keeping
/// a selectable raw representation available for Markdown.
class SmartTextPreview extends StatefulWidget {
  const SmartTextPreview({super.key, required this.data});

  final FilePreviewData data;

  @override
  State<SmartTextPreview> createState() => _SmartTextPreviewState();
}

class _SmartTextPreviewState extends State<SmartTextPreview> {
  bool _rawMarkdown = false;

  String get _text => widget.data.text ?? '';

  bool get _isMarkdown {
    final mime = widget.data.mimeType;
    final name = widget.data.name.toLowerCase();
    if (mime == 'text/markdown' ||
        name.endsWith('.md') ||
        name.endsWith('.mdx')) {
      return true;
    }
    return RegExp(
      r'(^|\n)#{1,6}\s+|(^|\n)```|(^|\n)\|[^\n]+\|\s*\n\|?\s*:?-{3,}',
      multiLine: true,
    ).hasMatch(_text);
  }

  String? get _language {
    final name = widget.data.name.toLowerCase().split('?').first;
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1);
    return switch (extension) {
      'dart' => 'dart',
      'js' || 'mjs' || 'cjs' => 'javascript',
      'ts' => 'typescript',
      'tsx' => 'tsx',
      'jsx' => 'jsx',
      'py' => 'python',
      'go' => 'go',
      'rs' => 'rust',
      'java' => 'java',
      'kt' || 'kts' => 'kotlin',
      'swift' => 'swift',
      'c' || 'h' => 'c',
      'cc' || 'cpp' || 'cxx' || 'hpp' => 'cpp',
      'cs' => 'csharp',
      'sh' || 'bash' || 'zsh' => 'shell',
      'html' || 'htm' => 'html',
      'css' => 'css',
      'scss' => 'scss',
      'xml' || 'svg' => 'xml',
      'yaml' || 'yml' => 'yaml',
      'toml' => 'toml',
      'sql' => 'sql',
      'gradle' => 'gradle',
      'diff' || 'patch' => 'diff',
      _ => null,
    };
  }

  String? get _prettyJson {
    final mime = widget.data.mimeType;
    final name = widget.data.name.toLowerCase();
    final trimmed = _text.trim();
    final candidate =
        mime == 'application/json' ||
        name.endsWith('.json') ||
        ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
            (trimmed.startsWith('[') && trimmed.endsWith(']')));
    if (!candidate) return null;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prettyJson = _prettyJson;
    final language = _language;
    if (_isMarkdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const Key('file-preview-rendered-mode'),
                    onPressed: _rawMarkdown
                        ? () => setState(() => _rawMarkdown = false)
                        : null,
                    child: Text(readerL10n(context).readerUiRendered),
                  ),
                  TextButton(
                    key: const Key('file-preview-raw-mode'),
                    onPressed: _rawMarkdown
                        ? null
                        : () => setState(() => _rawMarkdown = true),
                    child: Text(readerL10n(context).readerUiRaw),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_rawMarkdown)
            CodeBlock(
              code: _text,
              originalSource: widget.data.copyText,
              language: 'markdown',
            )
          else
            MarkdownText(_text),
        ],
      );
    }
    if (prettyJson != null) {
      return CodeBlock(
        code: prettyJson,
        originalSource: widget.data.copyText,
        language: 'json',
      );
    }
    if (language != null) {
      return CodeBlock(
        code: _text,
        originalSource: widget.data.copyText,
        language: language,
      );
    }
    return SelectableText(
      _text,
      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _metadata(BuildContext context, FilePreviewData data) => [
  data.mimeType ?? readerL10n(context).readerUiUnknownType,
  if (data.byteLength != null)
    readerL10n(context).readerUiBytes(data.byteLength!),
].join(' · ');

AppLocalizations readerL10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));
