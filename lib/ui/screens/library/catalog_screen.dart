part of '../library_screen.dart';

/// "Deprecated" / "Preview" lifecycle pill for a catalog model; null when
/// the model is plainly active.
class ModelStatusPill extends StatelessWidget {
  const ModelStatusPill._(this.label, this.tone, {super.key});

  static ModelStatusPill? forModel(
    CatalogModel model,
    AppLocalizations l10n, {
    Key? key,
  }) {
    if (model.deprecated) {
      return ModelStatusPill._(
        l10n.e7LibraryDeprecated,
        AppStatusTone.neutral,
        key: key,
      );
    }
    if (model.preview) {
      return ModelStatusPill._(
        l10n.e7LibraryPreview,
        AppStatusTone.attention,
        key: key,
      );
    }
    return null;
  }

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.statusColor(theme, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  final ConnectionController controller;
  const CatalogScreen({super.key, required this.controller});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.catalog == null) {
      widget.controller.refreshCatalog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7LibraryModelsAndAgents,
        ),
      ),
      body: ModelCatalogView(controller: widget.controller, showHeader: false),
    );
  }
}
