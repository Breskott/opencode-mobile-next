import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../state/reader_preferences.dart';

/// Place above the Navigator so every reader, including a pushed snapshot,
/// shares the current profile's display preferences.
class ReaderPreferencesScope extends StatefulWidget {
  const ReaderPreferencesScope({
    super.key,
    required this.profileId,
    required this.prefs,
    required this.child,
  });

  final String? profileId;
  final SharedPreferences prefs;
  final Widget child;

  static ReaderPreferencesStore? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ReaderPreferencesInherited>()
      ?.notifier;

  @override
  State<ReaderPreferencesScope> createState() => _ReaderPreferencesScopeState();
}

class _ReaderPreferencesScopeState extends State<ReaderPreferencesScope> {
  late ReaderPreferencesStore _store = _create();

  ReaderPreferencesStore _create() =>
      ReaderPreferencesStore(prefs: widget.prefs, profileId: widget.profileId);

  @override
  void didUpdateWidget(ReaderPreferencesScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileId != oldWidget.profileId ||
        widget.prefs != oldWidget.prefs) {
      final previous = _store;
      _store = _create();
      previous.dispose();
    }
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ReaderPreferencesInherited(notifier: _store, child: widget.child);
}

class _ReaderPreferencesInherited
    extends InheritedNotifier<ReaderPreferencesStore> {
  const _ReaderPreferencesInherited({
    required super.notifier,
    required super.child,
  });
}

Future<void> saveReaderPreferences(
  BuildContext context, {
  bool? sourceFirst,
  bool? wrapCode,
}) async {
  final store = ReaderPreferencesScope.maybeOf(context);
  if (store == null) return;
  final saved = await store.update(
    sourceFirst: sourceFirst,
    wrapCode: wrapCode,
  );
  if (saved ||
      !context.mounted ||
      !identical(ReaderPreferencesScope.maybeOf(context), store)) {
    return;
  }
  final strings = lookupAppLocalizations(Localizations.localeOf(context));
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(strings.readerUiSaveFailed)));
}

/// Reuse the existing reader action area instead of adding a settings bar.
class ReaderWrapButton extends StatelessWidget {
  const ReaderWrapButton({super.key, this.fallbackWrap});

  final bool? fallbackWrap;

  @override
  Widget build(BuildContext context) {
    final store = ReaderPreferencesScope.maybeOf(context);
    if (store == null) return const SizedBox.shrink();
    final strings = lookupAppLocalizations(Localizations.localeOf(context));
    final wrap =
        store.value.wrapCode ??
        fallbackWrap ??
        MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      toggled: wrap,
      child: IconButton(
        tooltip: wrap ? strings.markdownScrollCode : strings.markdownWrapCode,
        isSelected: wrap,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          visualDensity: VisualDensity.standard,
        ),
        icon: const Icon(Icons.wrap_text_rounded),
        onPressed: () => saveReaderPreferences(context, wrapCode: !wrap),
      ),
    );
  }
}
