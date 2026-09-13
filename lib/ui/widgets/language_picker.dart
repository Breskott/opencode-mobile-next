import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';

class LanguageSettingsTile extends StatelessWidget {
  const LanguageSettingsTile({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale?>(
    valueListenable: controller.appLocale,
    builder: (context, locale, _) {
      final l10n = AppLocalizations.of(context);
      return ListTile(
        leading: const Icon(Icons.language_rounded),
        title: Text(l10n.e7LocaleUiLanguage),
        subtitle: Text(_localeLabel(l10n, locale)),
        trailing: const Icon(Icons.chevron_right_rounded),
        minVerticalPadding: 12,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          enableDrag: false,
          builder: (_) => _LanguageSheet(controller: controller),
        ),
      );
    },
  );
}

String _localeLabel(AppLocalizations l10n, Locale? locale) =>
    switch (locale?.languageCode) {
      'ar' => l10n.e7LocaleUiArabic,
      'en' => l10n.e7LocaleUiEnglish,
      _ => l10n.e7LocaleUiSystem,
    };

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.controller});
  final ConnectionController controller;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _select(Locale? locale) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.controller.setAppLocale(locale);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.e7LocaleUiLanguage,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    tooltip: l10n.e7LocaleUiClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 12),
                child: Text(l10n.e7LocaleUiDescription),
              ),
              for (final locale in <Locale?>[
                null,
                const Locale('en'),
                const Locale('ar'),
              ])
                ListTile(
                  minVerticalPadding: 16,
                  title: Text(_localeLabel(l10n, locale)),
                  selected: widget.controller.appLocale.value == locale,
                  trailing: widget.controller.appLocale.value == locale
                      ? const Icon(Icons.check_rounded)
                      : null,
                  enabled: !_saving,
                  onTap: () => _select(locale),
                ),
              if (_saving)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.e7LocaleUiSaving),
                  ),
                ),
              if (_failed)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.e7LocaleUiSaveFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
