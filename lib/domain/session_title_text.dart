/// A session title as it may be shown: the server's title with any leaked
/// model markup cut off.
///
/// OpenCode names a session from the model's first words, and some models
/// (seen with the AI Team's refinery agent) put a tool call right after
/// them, so the stored title reads
/// `I'll run the startup sequence … prime the merge queue.<tool_call><fu…`.
/// Everything from the first markup marker on is dropped, then the space and
/// the truncation ellipsis the server left behind it. The stored title is
/// never changed; this is for display only, and every place that shows a
/// session title goes through it (see `presentedSessionTitle`).
///
/// Returns the trimmed title, or an empty string when nothing readable is
/// left (the caller shows its own "untitled" wording then).
String displaySessionTitleText(String? title) {
  var value = title?.trim() ?? '';
  if (value.isEmpty) return value;
  var cut = false;
  final lower = value.toLowerCase();
  var at = -1;
  for (final marker in _markers) {
    final index = lower.indexOf(marker);
    if (index >= 0 && (at < 0 || index < at)) at = index;
  }
  if (at >= 0) {
    value = value.substring(0, at);
    cut = true;
  } else {
    // A marker the server's length limit cut in half: `…queue.<tool_ca…`.
    final tail = _truncatedMarker.firstMatch(value);
    if (tail != null) {
      final fragment = tail.group(1)!.toLowerCase();
      if (_markers.any((marker) => marker.startsWith(fragment))) {
        value = value.substring(0, tail.start);
        cut = true;
      }
    }
  }
  if (cut) {
    value = value.replaceFirst(_trailingEllipsis, '');
  }
  return value.trim();
}

/// Where leaked model markup starts: tool-call tags and special tokens.
const _markers = [
  '<tool_call',
  '</tool_call',
  '<tool_use',
  '<function',
  '</function',
  '<|',
];

/// A `<` followed by a marker's first letters, then the ellipsis the server
/// put where it cut the title. Without the ellipsis a trailing `<f` is left
/// alone: it may be the person's own text.
final _truncatedMarker = RegExp(r'(<[A-Za-z_|/]*)\s*(?:…|\.\.\.)\s*$');

final _trailingEllipsis = RegExp(r'[\s…]*(?:\.\.\.)?[\s…]*$');
