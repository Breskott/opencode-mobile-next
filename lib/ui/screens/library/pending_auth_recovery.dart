part of '../library_screen.dart';

// Equality only. Unlike inventory identity this deliberately excludes the
// replaceable transport: each explicit action reacquires it in the controller.
Object _authSourceFor(ConnectionController controller) => (
  controller.profile?.id,
  controller.profile?.baseUrl,
  controller.profile?.username,
  controller.profile?.password,
  controller.profile?.flavor,
  controller.locationRevision,
);

/// A sign-in this device started and can still pick up: one card on the
/// Providers page with its words and its actions (resume, enter the code,
/// cancel on the server, forget on this device).
class _PendingAuthRecoveryTile extends StatefulWidget {
  const _PendingAuthRecoveryTile({
    super.key,
    required this.controller,
    required this.entry,
    required this.onComplete,
  });
  final ConnectionController controller;
  final PendingAuthAttempt entry;
  final Future<void> Function() onComplete;
  @override
  State<_PendingAuthRecoveryTile> createState() =>
      _PendingAuthRecoveryTileState();
}

class _PendingAuthRecoveryTileState extends State<_PendingAuthRecoveryTile> {
  bool _busy = false;
  IntegrationAuthState? _status;
  String? _error;
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  Future<void> _act({
    bool cancel = false,
    bool enterCode = false,
    bool forget = false,
  }) async {
    if (_busy) return;
    final controller = widget.controller;
    final entry = widget.entry;
    final source = _authSourceFor(controller);
    final location = controller.locationRevision;
    final route = ModalRoute.of(context);
    bool current() =>
        mounted &&
        source == _authSourceFor(controller) &&
        controller.isProfileReadable(entry.profileID) &&
        (route?.isCurrent ?? true);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? code;
      if (forget) {
        final confirmed = await showKitConfirm(
          context,
          icon: AppIconography.delete,
          title: _l10n.pendingAuthRecoveryForgetTitle(entry.integrationID),
          body: _l10n.pendingAuthRecoveryForgetBody,
          confirmLabel: _l10n.pendingAuthForget,
          confirmKey: const ValueKey('pending-auth-forget-confirm'),
        );
        if (!confirmed || !current()) return;
        await controller.forgetIntegrationAuth(
          entry,
          locationRevision: location,
        );
        return;
      }
      if (enterCode) {
        // The one finish-sign-in dialog (screen-library-1): the code is
        // parsed in place, entered as a secret and never echoed.
        code = await _showFinishSignInDialog(
          context,
          label: _l10n.e7LibraryAuthorizationCode,
          helper: _l10n.integrationsFinishSignInProviderHelper,
          parse: providerOAuthCompletionCode,
          fieldKey: const ValueKey('oauth-completion-code'),
        );
        if (code == null || !current()) return;
      }
      if (!current()) return;
      final result = await controller.recoverIntegrationAuth(
        entry,
        cancel: cancel,
        code: code,
        locationRevision: location,
      );
      if (!mounted || !current()) return;
      setState(() => _status = result.state);
      // Complete: the card says so until the refreshed list drops it and
      // the provider's row shows the new connection (feedback in place,
      // K2 §4.8).
      if (result.state == IntegrationAuthState.complete) {
        await widget.onComplete();
      }
    } catch (_) {
      if (current()) setState(() => _error = _l10n.pendingAuthFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final l10n = _l10n;
    final tokens = KitTokens.of(context);
    final expired = entry.expired || _status == IntegrationAuthState.expired;
    final supported = widget.controller.integrationAuthRecoverySupported;
    final canResume = !expired && supported;
    final codeEntry =
        entry.kind == PendingAuthKind.oauth &&
        entry.mode == IntegrationAuthMode.code;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: tokens.space3,
      ),
      child: KitNotice.card(
        key: ValueKey('pending-auth-${entry.integrationID}'),
        title: l10n.pendingAuthTitle(entry.integrationID),
        message: entry.kind == PendingAuthKind.command
            ? l10n.commandAuthPending
            : l10n.pendingAuthDetail,
        notes: [
          if (!supported) l10n.pendingAuthUnsupported,
          if (expired) l10n.pendingAuthExpired,
          if (_status == IntegrationAuthState.pending)
            l10n.pendingAuthStillPending,
          if (_status == IntegrationAuthState.failed)
            l10n.pendingAuthServerFailed,
          if (_status == IntegrationAuthState.complete)
            l10n.pendingAuthComplete,
          ?_error,
        ],
        primary: canResume
            ? KitAction(
                key: const ValueKey('pending-auth-resume'),
                label: l10n.pendingAuthResume,
                working: _busy,
                onPressed: _busy ? null : () => _act(),
              )
            : null,
        secondary: canResume && codeEntry
            ? KitAction(
                key: const ValueKey('pending-auth-enter-code'),
                label: l10n.pendingAuthEnterCode,
                onPressed: _busy ? null : () => _act(enterCode: true),
              )
            : null,
        actions: [
          if (supported)
            KitAction(
              key: const ValueKey('pending-auth-cancel'),
              label: l10n.commandAuthCancel,
              onPressed: _busy ? null : () => _act(cancel: true),
            ),
          KitAction(
            key: const ValueKey('pending-auth-forget'),
            label: l10n.pendingAuthForget,
            onPressed: _busy ? null : () => _act(forget: true),
          ),
        ],
      ),
    );
  }
}

/// A start the server may have taken without telling the app its attempt:
/// the app blocks a second start until the person clears it here.
// revamp: merge-into:integrations-forget-pending-auth-sheet (no owner)
class _UncertainAuthRecoveryTile extends StatefulWidget {
  const _UncertainAuthRecoveryTile({
    required this.controller,
    required this.integrationID,
    required this.kind,
  });
  final ConnectionController controller;
  final String integrationID;
  final PendingAuthKind kind;

  @override
  State<_UncertainAuthRecoveryTile> createState() =>
      _UncertainAuthRecoveryTileState();
}

class _UncertainAuthRecoveryTileState
    extends State<_UncertainAuthRecoveryTile> {
  String? _error;

  Future<void> _forget() async {
    final controller = widget.controller;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final source = _authSourceFor(controller);
    final location = controller.locationRevision;
    final confirmed = await showKitConfirm(
      context,
      icon: AppIconography.delete,
      title: l10n.uncertainAuthForgetTitle,
      body: l10n.uncertainAuthForgetDetail,
      confirmLabel: l10n.uncertainAuthForget,
    );
    if (!confirmed || !mounted || source != _authSourceFor(controller)) {
      return;
    }
    try {
      controller.forgetUncertainIntegrationAuth(
        widget.integrationID,
        widget.kind,
        locationRevision: location,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.e7LibraryTheSignInSourceChanged);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: tokens.space3,
      ),
      child: KitNotice.card(
        title: l10n.uncertainAuthTitle(widget.integrationID),
        message: l10n.uncertainAuthDetail,
        notes: [?_error],
        actions: [
          KitAction(
            key: const ValueKey('uncertain-auth-forget'),
            label: l10n.uncertainAuthForget,
            onPressed: _forget,
          ),
        ],
      ),
    );
  }
}
