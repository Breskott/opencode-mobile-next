part of '../library_screen.dart';

/// "Models": the server's model catalog as a page (map `catalog`, proposal
/// fix), built from kit parts (screen-library-1). The list itself is the
/// shared [ModelCatalogView] the chat's model picker also uses; this page
/// adds what the map found missing around it: one "No models yet" state
/// that offers to connect a provider when none is signed in (in place of
/// the list), the loading bar, the offline line, and an explanation on
/// servers that do not share a catalog.
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
    if (widget.controller.capabilities.serverCatalog &&
        widget.controller.catalog == null) {
      widget.controller.refreshCatalog();
    }
  }

  Future<void> _connectProvider() async {
    await Navigator.of(context).push<void>(
      KitPageRoute<void>(
        builder: (_) => IntegrationsScreen(
          controller: widget.controller,
          mode: IntegrationsMode.providers,
        ),
      ),
    );
    if (mounted) await widget.controller.refreshCatalog();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = _libraryCopy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final catalog = controller.catalog;
    final available = controller.capabilities.serverCatalog;
    final offline = controller.status != StreamStatus.connected;
    final noProvider = catalog != null && catalog.models.isEmpty;
    final rails = EdgeInsetsDirectional.only(
      start: tokens.gutter,
      end: tokens.gutter,
      bottom: tokens.space3,
    );
    return KitScreen(
      topBar: KitTopBar(title: l10n.catalogScreenTitle),
      loading: available && controller.catalogLoading,
      loadingLabel: l10n.catalogScreenLoading,
      body: !available
          ? ListView(
              padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
              children: [
                // Codex and Paseo keep their models to themselves: say so
                // and which servers can (P7.4), never an empty page.
                KitCapabilityExplainer.state(
                  key: const ValueKey('catalog-unavailable'),
                  capability: 'flag:serverCatalog',
                  serverName: controller.profile?.name,
                  source: 'catalog',
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (offline)
                  Padding(
                    padding: rails,
                    child: KitNotice(
                      key: const ValueKey('catalog-offline'),
                      icon: AppIconography.warning,
                      message: catalog == null
                          ? l10n.catalogScreenOffline
                          : l10n.catalogScreenOfflineStale,
                    ),
                  ),
                // No provider signed in: one state with one way out, and
                // the catalog view (its own empty state, notices and
                // browse link) waits until a model exists.
                if (noProvider)
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
                      children: [
                        KitStateView(
                          key: const ValueKey('catalog-no-provider'),
                          icon: AppIconography.login,
                          title: l10n.catalogScreenNoProviderTitle,
                          body: l10n.catalogScreenNoProviderBody,
                          primary: KitAction(
                            key: const ValueKey('catalog-connect-provider'),
                            label: l10n.catalogScreenConnectProvider,
                            onPressed: _connectProvider,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ModelCatalogView(
                      controller: controller,
                      showHeader: false,
                    ),
                  ),
              ],
            ),
    );
  }
}
