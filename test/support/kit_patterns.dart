// The source patterns the kit gates count (docs/ux-system/revamp/STANDARDS.md
// §18.2: G1, G2, G7, G17 and G21), in one place so every gate counts the same
// thing the same way.
//
// Today only test/design_standard_test.dart (G3x) reads this file: it holds
// every screen in `_migrated` at zero for every pattern that applies to its
// path. The whole-lib/ ratchets in test/kit_ratchet_test.dart do not share
// the list yet: its G1 keeps its own `_g1PatternNames` (the same names as
// [kitG1Names]), and G2, G7, G17 and G21 are not built. Their owners are
// meant to import this file rather than copy it.
//
// A pattern knows where it applies ([KitPattern.appliesTo]) and how to count
// itself in comment-stripped source ([KitPattern.count]); it knows nothing
// about baselines. Adding a pattern here tightens G3x at once (a migrated
// file that uses it fails), so a new pattern lands together with the fix or
// the G3x baseline entry that absorbs it (STANDARDS.md KIT-44, PROC-13).
//
// Pure Dart: no Flutter imports, no file access except [kitCodeOf].
import 'dart:io';

/// One countable source pattern of a kit gate.
class KitPattern {
  const KitPattern({
    required this.gate,
    required this.name,
    required this.rules,
    required this.scope,
    required this.count,
    this.exempt = const {},
    this.absoluteIn,
  });

  /// The §18 gate that owns the pattern: 'G1', 'G2', 'G7', 'G17' or 'G21'.
  final String gate;

  /// Short, stable label, unique within [gate] (baseline JSON keys use
  /// [id], so renaming one resets its history: don't).
  final String name;

  /// STANDARDS.md rule ids the pattern enforces.
  final List<String> rules;

  /// Paths (repo-relative, POSIX) the pattern is counted in.
  final bool Function(String path) scope;

  /// Files the pattern never counts in, with the reason.
  final Map<String, String> exempt;

  /// Where the ratchet must hold the count at zero with no baseline
  /// (STANDARDS.md §18.2 "absolute"); null means a plain per-file ratchet.
  final bool Function(String path)? absoluteIn;

  /// Occurrences in comment-stripped source (see [kitStripLineComments]).
  final int Function(String code) count;

  /// `'<gate> <name>'`, the key used in baselines and failure messages.
  String get id => '$gate $name';

  bool appliesTo(String path) => scope(path) && !exempt.containsKey(path);

  bool isAbsoluteAt(String path) => absoluteIn?.call(path) ?? false;
}

// --- Paths -----------------------------------------------------------------

const kitDir = 'lib/ui/kit/';

bool kitIsInLib(String path) => path.startsWith('lib/');
bool kitIsInUi(String path) => path.startsWith('lib/ui/');
bool kitIsInKit(String path) => path.startsWith(kitDir);

String _base(String path) => path.substring(path.lastIndexOf('/') + 1);

/// `app_theme.dart`, `theme_packs*.dart` and `theme_roles.dart`: the files
/// that define colours and type, where G17 and G21 do not look.
bool kitIsThemeFile(String path) {
  final base = _base(path);
  return base == 'app_theme.dart' ||
      base == 'theme_roles.dart' ||
      (base.startsWith('theme_packs') && base.endsWith('.dart'));
}

/// A kit file whose basename is [base] (the kit may nest it in a folder,
/// e.g. `lib/ui/kit/motion/kit_haptics.dart`).
bool _isKitFile(String path, String base) =>
    kitIsInKit(path) && _base(path) == base;

bool _outsideKit(String path) => kitIsInLib(path) && !kitIsInKit(path);
bool _uiNotTheme(String path) => kitIsInUi(path) && !kitIsThemeFile(path);
bool _uiNotThemeOutsideKit(String path) =>
    _uiNotTheme(path) && !kitIsInKit(path);
bool _kitNotTheme(String path) => kitIsInKit(path) && !kitIsThemeFile(path);

/// Where numeric shape and type literals may live (G21, LOOK-19, LAY-7).
bool _isTokenFile(String path) =>
    _isKitFile(path, 'kit_tokens.dart') || _isKitFile(path, 'kit_text.dart');

/// LOOK-27: the files allowed to construct glass. Kit parts of the
/// navigation layer (composer, floating tab bar, rail, top controls, desktop
/// sidebar header and toolbar) join when the unit that builds them lands.
bool kitMayBuildGlass(String path) =>
    path.startsWith('${kitDir}glass/') ||
    path == 'lib/ui/screens/home_screen.dart' ||
    path == 'lib/ui/widgets/glass_surface.dart';

/// MOT-2: the kit's transitions (KitTabSwitcher, the page transitions and
/// everything else under `lib/ui/kit/motion/`).
bool _isKitTransition(String path) =>
    path.startsWith('${kitDir}motion/') || _isKitFile(path, 'kit_motion.dart');

// --- Source helpers --------------------------------------------------------

/// Drops full-line `//` and `///` comments, the technique every scan in
/// test/ already uses, so doc comments never count.
String kitStripLineComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// The comment-stripped source of the file at repo-relative [path].
String kitCodeOf(String path) =>
    kitStripLineComments(File(path).readAsStringSync());

/// The argument text of every call that [start] finds, where [start] ends
/// at the call's opening parenthesis. Parentheses inside string literals are
/// skipped; an unbalanced call yields the rest of [code].
List<String> kitCallArguments(String code, RegExp start) {
  final result = <String>[];
  for (final match in start.allMatches(code)) {
    final open = match.end - 1;
    if (open < 0 || code[open] != '(') continue;
    var depth = 0;
    String? quote;
    var end = code.length;
    for (var i = open; i < code.length; i++) {
      final char = code[i];
      if (quote != null) {
        if (char == r'\') {
          i++;
        } else if (char == quote) {
          quote = null;
        }
        continue;
      }
      if (char == "'" || char == '"') {
        quote = char;
      } else if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']' || char == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    result.add(code.substring(open + 1, end));
  }
  return result;
}

/// Splits [arguments] at its top-level commas.
List<String> kitSplitArguments(String arguments) {
  final parts = <String>[];
  var depth = 0;
  String? quote;
  var from = 0;
  for (var i = 0; i < arguments.length; i++) {
    final char = arguments[i];
    if (quote != null) {
      if (char == r'\') {
        i++;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ',' && depth == 0) {
      parts.add(arguments.substring(from, i).trim());
      from = i + 1;
    }
  }
  final last = arguments.substring(from).trim();
  if (last.isNotEmpty) parts.add(last);
  return parts;
}

int Function(String) _re(String pattern, {bool caseSensitive = true}) {
  final re = RegExp(pattern, caseSensitive: caseSensitive);
  return (code) => re.allMatches(code).length;
}

/// Calls found by [start] whose argument text satisfies [test].
int Function(String) _calls(String start, bool Function(String args) test) {
  final re = RegExp(start);
  return (code) => kitCallArguments(code, re).where(test).length;
}

/// A numeric literal that is not part of a name or a member access.
final _numericLiteral = RegExp(r'(?<![\w.$])\d');

/// A top-level `width:` or `height:` argument with a numeric literal, in
/// any position and across lines (dart format splits long calls). A nested
/// call in `child:` is judged as its own call, not as this one's.
bool _numericSize(String args) => kitSplitArguments(
  args,
).any((arg) => RegExp(r'^(?:width|height)\s*:\s*\d').hasMatch(arg));

const _edgeInsetsCall =
    r'\bEdgeInsets(?:Directional)?\.(?:all|only|symmetric|fromLTRB|fromSTEB)\(';

/// `(?<![A-Za-z0-9_])name(<T>)?(`: a call of [name], not of `_name` or
/// `showKitName`.
String _callOf(String name) =>
    '(?<![A-Za-z0-9_])${RegExp.escape(name)}(?:<[^>]*>)?\\(';

// --- G1 --------------------------------------------------------------------

/// KIT-2: modal and toast entry points live only inside the kit.
const kitG1Names = [
  'showDialog(',
  'showModalBottomSheet(',
  'showGeneralDialog(',
  'AlertDialog(',
  'SimpleDialog(',
  'DraggableScrollableSheet(',
  'showSnackBar(',
  'SnackBar(',
  'MaterialBanner(',
  'showConfirmSheet(',
];

final kitG1Patterns = <KitPattern>[
  for (final name in kitG1Names)
    KitPattern(
      gate: 'G1',
      name: name,
      rules: const ['KIT-2', 'KIT-15', 'KIT-33', 'KIT-34', 'KIT-38'],
      scope: _outsideKit,
      count: _re(_callOf(name.substring(0, name.length - 1))),
    ),
];

// --- G2 --------------------------------------------------------------------

/// KIT-43: old names a kit change retires, added by the unit that retires
/// them (`/// Retired by <unit id>: use …`). Call sites only shrink.
const kitRetiredNames = <String>[];

/// SEC-1: launchers passed into `openExternalLink`, with the reason.
const kitLaunchUrlAllowlist = <String, String>{};

final kitG2Patterns = <KitPattern>[
  KitPattern(
    gate: 'G2',
    name: 'Clipboard.setData(',
    rules: const ['KIT-23'],
    scope: (p) => kitIsInLib(p) && !_isKitFile(p, 'kit_copy.dart'),
    absoluteIn: kitIsInKit,
    count: _re(r'\bClipboard\.setData\('),
  ),
  KitPattern(
    gate: 'G2',
    name: 'HapticFeedback.',
    rules: const ['MOT-11'],
    scope: (p) => kitIsInLib(p) && !_isKitFile(p, 'kit_haptics.dart'),
    absoluteIn: kitIsInKit,
    count: _re(r'\bHapticFeedback\.'),
  ),
  KitPattern(
    gate: 'G2',
    name: 'launchUrl(',
    rules: const ['SEC-1'],
    scope: (p) => kitIsInLib(p) && p != 'lib/ui/widgets/external_link.dart',
    exempt: kitLaunchUrlAllowlist,
    count: _re(r'\blaunchUrl(?:String)?\('),
  ),
  KitPattern(
    gate: 'G2',
    name: 'AnimatedSize(',
    rules: const ['MOT-5'],
    // The one allowlisted use: KitButton's spinner slot.
    scope: (p) => kitIsInLib(p) && !_isKitFile(p, 'kit_buttons.dart'),
    absoluteIn: kitIsInKit,
    count: _re(r'\bAnimatedSize\('),
  ),
  KitPattern(
    gate: 'G2',
    name: 'ProductErrorState(|ProductEmptyState(|ProductInlineEmpty(',
    rules: const ['STATE-1', 'KIT-38'],
    scope: _outsideKit,
    count: _re(
      r'\b(?:ProductErrorState|ProductEmptyState|ProductInlineEmpty)\(',
    ),
  ),
  KitPattern(
    gate: 'G2',
    name: 'showConfirmSheet(',
    rules: const ['KIT-38'],
    scope: _outsideKit,
    count: _re(_callOf('showConfirmSheet')),
  ),
  KitPattern(
    gate: 'G2',
    name: 'KitSecretField(',
    rules: const ['KIT-38', 'KIT-43'],
    scope: _outsideKit,
    count: _re(r'\bKitSecretField\('),
  ),
  for (final name in kitRetiredNames)
    KitPattern(
      gate: 'G2',
      name: name,
      rules: const ['KIT-43'],
      scope: _outsideKit,
      count: _re(RegExp.escape(name)),
    ),
  KitPattern(
    gate: 'G2',
    name: 'duration: Duration(',
    rules: const ['MOT-1'],
    scope: (p) => kitIsInUi(p) && !_isKitFile(p, 'kit_motion.dart'),
    absoluteIn: kitIsInKit,
    count: _re(r'\b(?:duration|reverseDuration):\s*(?:const\s+)?Duration\('),
  ),
  KitPattern(
    gate: 'G2',
    name: 'Curves.',
    rules: const ['MOT-1'],
    scope: (p) => kitIsInUi(p) && !_isKitFile(p, 'kit_motion.dart'),
    absoluteIn: kitIsInKit,
    count: _re(r'\bCurves\.'),
  ),
];

// --- G7 --------------------------------------------------------------------

/// LAY-8: left alignment is correct inside a forced-LTR technical value.
const _forcedLtr = <String, String>{
  'lib/ui/kit/kit_technical_value.dart': 'forced-LTR technical value (LAY-8)',
  'lib/ui/kit/kit_code_block.dart': 'forced-LTR code block (LAY-8)',
  'lib/ui/kit/kit_log_panel.dart': 'forced-LTR log panel (LAY-8)',
  'lib/ui/kit/kit_diff_view.dart': 'forced-LTR diff view (LAY-8)',
};

final kitG7Patterns = <KitPattern>[
  KitPattern(
    gate: 'G7',
    name: 'EdgeInsets.only(left|right:)',
    rules: const ['LAY-8'],
    scope: kitIsInLib,
    count: _calls(
      r'\bEdgeInsets\.only\(',
      (args) => RegExp(r'\b(?:left|right)\s*:').hasMatch(args),
    ),
  ),
  KitPattern(
    gate: 'G7',
    name: 'EdgeInsets.fromLTRB asymmetric',
    rules: const ['LAY-8'],
    scope: kitIsInLib,
    count: _calls(r'\bEdgeInsets\.fromLTRB\(', (args) {
      final parts = kitSplitArguments(args);
      return parts.length >= 3 && parts[0] != parts[2];
    }),
  ),
  KitPattern(
    gate: 'G7',
    name: 'Alignment.centerLeft|Right',
    rules: const ['LAY-8'],
    scope: kitIsInLib,
    exempt: _forcedLtr,
    count: _re(r'\bAlignment\.center(?:Left|Right)\b'),
  ),
  KitPattern(
    gate: 'G7',
    name: 'TextAlign.left|right',
    rules: const ['LAY-8'],
    scope: kitIsInLib,
    exempt: _forcedLtr,
    count: _re(r'\bTextAlign\.(?:left|right)\b'),
  ),
  KitPattern(
    gate: 'G7',
    name: 'Positioned(left|right:)',
    rules: const ['LAY-8'],
    scope: kitIsInLib,
    count: _calls(
      r'\bPositioned\(',
      (args) => RegExp(r'\b(?:left|right)\s*:').hasMatch(args),
    ),
  ),
  KitPattern(
    gate: 'G7',
    name: 'bidi literal',
    rules: const ['COPY-30'],
    scope: _outsideKit,
    // The characters themselves or their \u escapes: LRI, RLI, FSI, PDI, LRM.
    count: _re(
      '[\u2066-\u2069\u200E]'
      r'|\\u\{?20(?:6[6-9]|0[eE])\}?',
    ),
  ),
];

// --- G17 -------------------------------------------------------------------

final _attentionRole = RegExp(
  r'(?:\b([A-Za-z_]\w*)|[)\]])?\s*\.(?:attention|attentionFill'
  r'|onAttentionFill|attentionSurface|attentionLine)\b',
);

final kitG17Patterns = <KitPattern>[
  KitPattern(
    gate: 'G17',
    name: 'Color(0x',
    rules: const ['LOOK-1'],
    scope: _uiNotTheme,
    count: _re(r'\bColor\(0x'),
  ),
  KitPattern(
    gate: 'G17',
    name: 'Colors.*',
    rules: const ['LOOK-1'],
    scope: _uiNotTheme,
    count: _re(r'\bColors\.(?!transparent\b)\w+'),
  ),
  KitPattern(
    gate: 'G17',
    name: '.colorScheme.',
    rules: const ['LOOK-2'],
    scope: _uiNotThemeOutsideKit,
    count: _re(r'\.colorScheme\.'),
  ),
  KitPattern(
    gate: 'G17',
    name: '.textTheme.',
    rules: const ['LOOK-2'],
    scope: _uiNotThemeOutsideKit,
    count: _re(r'\.textTheme\.'),
  ),
  KitPattern(
    gate: 'G17',
    name: '.accent',
    rules: const ['LOOK-6'],
    scope: _uiNotThemeOutsideKit,
    count: _re(r'\.accent\b'),
  ),
  KitPattern(
    gate: 'G17',
    name: 'hairline.withValues(',
    rules: const ['LOOK-3'],
    scope: _uiNotTheme,
    count: _re(r'hairline\S*\.withValues\('),
  ),
  KitPattern(
    gate: 'G17',
    name: 'attention role',
    rules: const ['LOOK-4', 'LOOK-24'],
    scope: _uiNotThemeOutsideKit,
    // A role is read from an instance (`roles.attention`,
    // `ThemeRoles.of(context).attention`); `AppStatusTone.attention` and
    // other enum or static members named attention are not roles.
    count: (code) => _attentionRole
        .allMatches(code)
        .where((m) => !(m.group(1)?.startsWith(RegExp('[A-Z]')) ?? false))
        .length,
  ),
];

// --- G21 -------------------------------------------------------------------

KitPattern _g21OutsideKit(String name, List<String> rules, String pattern) =>
    KitPattern(
      gate: 'G21',
      name: name,
      rules: rules,
      scope: _uiNotThemeOutsideKit,
      count: _re(pattern),
    );

/// Shape and spacing literals: outside the kit, and inside it except in
/// `kit_tokens.dart` and `kit_text.dart` (KIT-9, LOOK-19, LAY-7).
KitPattern _g21Literal(
  String name,
  List<String> rules,
  int Function(String) count,
) => KitPattern(
  gate: 'G21',
  name: name,
  rules: rules,
  scope: (p) => _uiNotTheme(p) && !_isTokenFile(p),
  count: count,
);

final kitG21Patterns = <KitPattern>[
  _g21OutsideKit('fontSize:', const ['LOOK-12', 'LOOK-13'], r'\bfontSize:'),
  KitPattern(
    gate: 'G21',
    name: 'kit fontSize: <n>',
    rules: const ['KIT-9', 'LOOK-12'],
    scope: (p) => _kitNotTheme(p) && !_isTokenFile(p),
    count: _re(r'\bfontSize:\s*\d'),
  ),
  _g21OutsideKit('TextStyle(', const ['LOOK-12'], r'\bTextStyle\('),
  _g21Literal('BorderRadius.circular(<n>', const [
    'LOOK-19',
    'KIT-9',
  ], _re(r'\bBorderRadius\.circular\(\s*\d')),
  _g21Literal('Radius.circular(<n>', const [
    'LOOK-19',
    'KIT-9',
  ], _re(r'\bRadius\.circular\(\s*\d')),
  _g21Literal('EdgeInsets(<n>)', const [
    'LAY-6',
    'LAY-7',
    'KIT-9',
  ], _calls(_edgeInsetsCall, _numericLiteral.hasMatch)),
  _g21Literal('SizedBox(width|height: <n>)', const [
    'LAY-7',
    'KIT-9',
  ], _calls(r'\bSizedBox\(', _numericSize)),
  _g21OutsideKit('BoxShadow(', const ['LOOK-20'], r'\bBoxShadow\('),
  _g21OutsideKit('boxShadow:', const ['LOOK-20'], r'\bboxShadow:'),
  _g21OutsideKit('shadows: [', const [
    'LOOK-14',
    'LOOK-20',
  ], r'\bshadows:\s*\['),
  _g21OutsideKit('ImageFilter.blur', const ['LOOK-22'], r'\bImageFilter\.blur'),
  _g21OutsideKit('BackdropFilter(', const ['LOOK-22'], r'\bBackdropFilter\('),
  _g21OutsideKit('Border.all(', const ['LOOK-21'], r'\bBorder\.all\('),
  _g21OutsideKit('thickness:', const ['LOOK-21'], r'\bthickness:'),
  _g21OutsideKit('.toUpperCase()', const ['LOOK-15'], r'\.toUpperCase\(\)'),
  _g21OutsideKit('Gradient(', const [
    'LOOK-9',
  ], r'\b(?:Radial|Linear|Sweep)Gradient\('),
  _g21OutsideKit(
    'Image.asset|network|memory|file(',
    const ['LOOK-35', 'LOOK-37'],
    r'\bImage\.(?:asset|network|memory|file)\(',
  ),
  KitPattern(
    gate: 'G21',
    name: 'Icon size not 20/22/24',
    rules: const ['LOOK-33'],
    scope: _uiNotThemeOutsideKit,
    count: _calls(r'\bIcon\(', (args) {
      final size = RegExp(r'\bsize:\s*(\d+(?:\.\d+)?)\b').firstMatch(args);
      if (size == null) return false;
      return !const {
        '20',
        '22',
        '24',
        '20.0',
        '22.0',
        '24.0',
      }.contains(size.group(1));
    }),
  ),
  _g21OutsideKit('PageRouteBuilder(', const ['MOT-3'], r'\bPageRouteBuilder\('),
  _g21OutsideKit('transitionsBuilder:', const [
    'MOT-2',
    'MOT-3',
  ], r'\btransitionsBuilder:'),
  _g21OutsideKit('KitEffects.of(', const ['MOT-12'], r'\bKitEffects\.of\('),
  _g21OutsideKit(
    'text scale clamp',
    const ['A11Y-8'],
    r'\bTextScaler\.linear|\bmaxScaleFactor:|\bTextScaler\.noScaling',
  ),
  _g21OutsideKit('withOpacity(|Opacity(', const [
    'LOOK-14',
  ], r'\bwithOpacity\(|\bOpacity\('),
  KitPattern(
    gate: 'G21',
    name: 'KitGlass(|GlassSurface(',
    rules: const ['LOOK-27'],
    scope: (p) => _uiNotTheme(p) && !kitMayBuildGlass(p),
    absoluteIn: kitIsInUi,
    count: _re(r'\b(?:KitGlass|GlassSurface)\('),
  ),
  KitPattern(
    gate: 'G21',
    name: 'KitSurfaceLevel.glass|raised|tonal',
    rules: const ['KIT-42'],
    scope: _uiNotTheme,
    absoluteIn: kitIsInUi,
    count: _re(r'\bKitSurfaceLevel\.(?:glass|raised|tonal)\b'),
  ),
  KitPattern(
    gate: 'G21',
    name: 'disableAnimationsOf',
    rules: const ['MOT-8'],
    scope: (p) => _uiNotTheme(p) && !_isKitFile(p, 'kit_motion.dart'),
    absoluteIn: kitIsInUi,
    count: _re(r'\bdisableAnimationsOf\b'),
  ),
  KitPattern(
    gate: 'G21',
    name: 'Transform.scale|ScaleTransition',
    rules: const ['MOT-2'],
    scope: _isKitTransition,
    absoluteIn: _isKitTransition,
    count: _re(r'\bTransform\.scale\b|\bScaleTransition\b'),
  ),
  KitPattern(
    gate: 'G21',
    name: 'metal|chrome',
    rules: const ['LOOK-32'],
    scope: kitIsInLib,
    absoluteIn: kitIsInLib,
    count: _re(r'\b(?:metal|chrome)\w*', caseSensitive: false),
  ),
  KitPattern(
    gate: 'G21',
    name: 'kit BorderSide(width: <not KitTokens>)',
    rules: const ['LOOK-21'],
    scope: _kitNotTheme,
    count: _calls(r'\bBorderSide\(', (args) {
      final width = RegExp(r'\bwidth:\s*([^,]+)').firstMatch(args);
      return width != null && !width.group(1)!.contains('KitTokens');
    }),
  ),
];

/// Every pattern of G1, G2, G7, G17 and G21, in gate order.
final kitGatePatterns = <KitPattern>[
  ...kitG1Patterns,
  ...kitG2Patterns,
  ...kitG7Patterns,
  ...kitG17Patterns,
  ...kitG21Patterns,
];

/// Counts of every pattern in [patterns] that applies to [path], from
/// comment-stripped [code]; zero counts are left out.
Map<String, int> kitCountPatterns(
  String path,
  String code, {
  Iterable<KitPattern>? patterns,
}) {
  final counts = <String, int>{};
  for (final pattern in patterns ?? kitGatePatterns) {
    if (!pattern.appliesTo(path)) continue;
    final n = pattern.count(code);
    if (n > 0) counts[pattern.id] = n;
  }
  return counts;
}
