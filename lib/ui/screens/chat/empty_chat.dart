part of '../chat_screen.dart';

/// What the app can learn cheaply about the folder a new conversation runs
/// in: one file listing and the Git status the server already keeps.
///
/// Every field is optional because each answer may never come (a backend
/// without file browsing, an offline server, an isolated task); the empty
/// state then says less instead of guessing.
@immutable
class ChatStartFacts {
  const ChatStartFacts({
    this.directory,
    this.entries,
    this.git,
    this.hasHistory = false,
    this.changes,
    this.settled = true,
  });

  /// The folder is being looked at; nothing is known about it yet.
  const ChatStartFacts.pending(this.directory)
    : entries = null,
      git = null,
      hasHistory = false,
      changes = null,
      settled = false;

  final String? directory;

  /// Top-level entries other than `.git`, or null when the listing is not
  /// available.
  final int? entries;

  /// True for a Git repository, false when the server says it is not one,
  /// null when unknown.
  final bool? git;

  /// The repository has at least one commit, so "what changed recently" has
  /// something to answer with.
  final bool hasHistory;

  /// Uncommitted changes, or null when Git status is not available.
  final int? changes;

  /// False while the listing and Git status are still on their way.
  final bool settled;

  String get _normalized => (directory?.trim() ?? '').replaceAll('\\', '/');

  /// The last path segment: what a person calls the project.
  String? get projectName {
    final parts = _normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.last;
  }

  /// The phone server's folder of projects is where projects live, not a
  /// project itself.
  bool get isProjectsRoot => _normalized.endsWith('/root/projects');

  /// A real project folder the starters and facts can talk about.
  bool get hasProject => projectName != null && !isProjectsRoot;
}

/// One way to start: the words on the chip and what it puts in the composer.
@immutable
class ChatStarter {
  const ChatStarter(this.label);

  final String label;

  /// A label ending in an ellipsis is the start of a sentence; the composer
  /// gets it with a trailing space so the person just keeps typing.
  String get text => label.endsWith('…')
      ? '${label.substring(0, label.length - 1).trimRight()} '
      : label;

  @override
  bool operator ==(Object other) =>
      other is ChatStarter && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// The starters for [facts], most useful first.
///
/// A folder created a second ago has no bugs and no history, so it gets
/// ways to make something; a folder with files gets ways to work on them,
/// and "what changed recently" only when Git has commits to read. Nothing
/// is offered while the folder is still being looked at, so the row never
/// shows one set and swaps to another.
@visibleForTesting
List<ChatStarter> chatStartSuggestions(
  ChatStartFacts facts, {
  AppLocalizations? l10n,
}) {
  final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
  if (!facts.settled) return const [];
  if (!facts.hasProject) {
    // No project (the server's own default folder) or the folder that holds
    // the projects: asking about "this project" would ask about nothing.
    return [
      ChatStarter(strings.chatStartListFolder),
      ChatStarter(strings.chatStartFindBug),
    ];
  }
  if (facts.entries == 0) {
    return [
      ChatStarter(strings.chatStartBuildWebPage),
      ChatStarter(strings.chatStartPythonScript),
      ChatStarter(strings.chatStartNodeProject),
      ChatStarter(strings.chatStartReadme),
    ];
  }
  // Files, or a listing the server could not give: work on what is there.
  return [
    ChatStarter(strings.chatStartExplainProject),
    if (facts.hasHistory) ChatStarter(strings.chatStartWhatChanged),
    ChatStarter(strings.chatStartFindBug),
    ChatStarter(strings.chatStartAddTests),
  ];
}

/// The muted line under the project name, such as "Empty folder · Git" or
/// "24 items · Git · 3 changes"; null when there is nothing to say.
@visibleForTesting
String? chatStartFactsLine(ChatStartFacts facts, {AppLocalizations? l10n}) {
  final strings = l10n ?? lookupAppLocalizations(const Locale('en'));
  if (!facts.settled) return strings.chatStartLooking;
  final entries = facts.entries;
  final changes = facts.changes;
  final parts = [
    if (entries == 0)
      strings.chatStartEmptyFolder
    else if (entries != null)
      strings.chatStartItemCount(entries),
    if (facts.git == true) strings.chatStartGit,
    if (facts.git == true && changes != null && changes > 0)
      strings.chatStartChangeCount(changes),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The top of a new conversation: where you are, what is there, and a
/// caret that says the session is ready for you.
///
/// It sits at the bottom of the empty transcript, right above the starters
/// and the composer, so the first message later appears exactly where it
/// was. With the keyboard up (or in a short window) it shrinks to one line
/// and drops the tip, and when even that line would not fit it steps aside
/// rather than be cut.
class _ChatStartHeader extends StatefulWidget {
  const _ChatStartHeader({required this.facts, required this.compact});

  final ChatStartFacts facts;
  final bool compact;

  @override
  State<_ChatStartHeader> createState() => _ChatStartHeaderState();
}

class _ChatStartHeaderState extends State<_ChatStartHeader> {
  // A terminal caret's rhythm. It rests after a few seconds, as desktop
  // terminals do, so an idle screen is still.
  static const _blinkInterval = Duration(milliseconds: 530);
  static const _blinkTicks = 16;

  Timer? _blink;
  int _ticks = 0;
  bool _caretOn = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _blink?.cancel();
      _blink = null;
      _caretOn = true;
    } else if (_blink == null && _ticks < _blinkTicks) {
      // A timer, not an animation controller: nothing asks for frames
      // between blinks, so waiting for the screen to settle still settles.
      _blink = Timer.periodic(_blinkInterval, (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    _ticks += 1;
    final resting = _ticks >= _blinkTicks;
    if (resting) {
      _blink?.cancel();
    }
    setState(() => _caretOn = resting || !_caretOn);
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _chatL10n(context);
    final scheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final facts = widget.facts;
    final name = facts.projectName ?? strings.chatStartServerFolder;
    final factsLine = chatStartFactsLine(facts, l10n: strings);
    final nameStyle = theme.textTheme.titleMedium!.copyWith(
      fontFamily: AppTheme.monoFamily,
      fontWeight: FontWeight.w600,
    );
    final factsStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final fontSize = nameStyle.fontSize ?? 16;
    final caret = ExcludeSemantics(
      child: Opacity(
        key: const ValueKey('chat-start-caret'),
        opacity: _caretOn ? 1 : 0,
        child: Container(
          width: textScaler.scale(fontSize * .55),
          height: textScaler.scale(fontSize * 1.15),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
    final nameText = Text(
      name,
      key: const ValueKey('chat-start-name'),
      maxLines: widget.compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );
    final Widget content = widget.compact
        ? Row(
            key: const ValueKey('chat-start-header-compact'),
            children: [
              Flexible(child: nameText),
              const SizedBox(width: 3),
              caret,
              if (factsLine != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    factsLine,
                    key: const ValueKey('chat-start-facts'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: factsStyle,
                  ),
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(child: nameText),
                  const SizedBox(width: 3),
                  caret,
                ],
              ),
              if (factsLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  factsLine,
                  key: const ValueKey('chat-start-facts'),
                  style: factsStyle,
                ),
              ],
              const SizedBox(height: 14),
              Text(
                strings.chatStartTip,
                key: const ValueKey('chat-start-tip'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: .8),
                ),
              ),
            ],
          );
    // The standard's 16 dp side rails (design standard §1), like every
    // other screen's body.
    final padding = widget.compact
        ? const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 6)
        : const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12);
    // One line of the name plus its padding: below this the compact header
    // would be clipped, so it is left out instead.
    final compactHeight = textScaler.scale(fontSize) * 1.5 + 12;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.compact &&
            constraints.hasBoundedHeight &&
            constraints.maxHeight < compactHeight) {
          return const SizedBox.shrink();
        }
        return SingleChildScrollView(
          // Taller than the space (large text, short window): the lines
          // nearest the composer stay in view and the rest scroll.
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: padding,
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Semantics(
                      container: true,
                      child: _entrance(context, content),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _entrance(BuildContext context, Widget child) =>
      MediaQuery.disableAnimationsOf(context)
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: child,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 8),
              child: child,
            ),
          ),
        );
}

/// The tallest the starter row gets at [textScaler]: one line of chip label,
/// the chip's own padding and border, never under the 48dp touch target.
@visibleForTesting
double chatStartersHeight(TextScaler textScaler) =>
    math.max(48.0, textScaler.scale(20) + 18) + 2;

/// The empty transcript: the header fills the space and the starters sit at
/// its foot, which is the top edge of the composer.
///
/// The row lives inside the flexible area rather than beside the composer
/// so a short window (large text, keyboard up, landscape) takes it away
/// before the composer loses a pixel: the composer is what the person
/// needs, the starters are a shortcut.
class _ChatStartArea extends StatelessWidget {
  const _ChatStartArea({required this.header, required this.starters});

  final Widget header;
  final Widget? starters;

  @override
  Widget build(BuildContext context) {
    final rowHeight = chatStartersHeight(MediaQuery.textScalerOf(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = starters;
        final fits =
            !constraints.hasBoundedHeight || constraints.maxHeight >= rowHeight;
        return Column(
          children: [
            Expanded(child: header),
            if (row != null && fits) row,
          ],
        );
      },
    );
  }
}

/// The ways to start, as one row right above the composer, so they stay
/// next to where you type with the keyboard up. A tap fills the composer;
/// nothing is sent until the person sends it.
class _ChatStarters extends StatelessWidget {
  const _ChatStarters({required this.starters, required this.onPick});

  final List<ChatStarter> starters;
  final ValueChanged<ChatStarter> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      label: _chatL10n(context).chatStartSuggestionsLabel,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        key: const ValueKey('chat-starters'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 0),
        child: Row(
          // Keyed by the set, so a new set (the folder's facts arrived)
          // fades in again instead of silently swapping words.
          key: ValueKey(starters.map((starter) => starter.label).join('|')),
          children: [
            for (final (index, starter) in starters.indexed)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _stagger(
                  reduceMotion: reduceMotion,
                  rtl: rtl,
                  index: index,
                  child: ActionChip(
                    key: ValueKey('chat-starter-${starter.label}'),
                    label: Text(starter.label),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    // Compact to look at, 48dp to hit.
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    shape: const StadiumBorder(),
                    onPressed: () => onPick(starter),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Each chip arrives 40 ms after the one before it and settles toward the
  // start of the line: the row reads as offered, not printed.
  static Widget _stagger({
    required bool reduceMotion,
    required bool rtl,
    required int index,
    required Widget child,
  }) {
    if (reduceMotion) return child;
    const fade = 200;
    final delay = 40 * index;
    final total = fade + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((1 - t) * (rtl ? -8 : 8), 0),
          child: child,
        ),
      ),
    );
  }
}
