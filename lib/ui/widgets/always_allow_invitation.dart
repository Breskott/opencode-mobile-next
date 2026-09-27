import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../api/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/consent_owners.dart';
import '../../state/connection.dart';
import '../../state/repeated_permission_consent.dart';
import '../app_iconography.dart';
import '../app_theme.dart' show AppStatusTone;
import '../kit/kit.dart';

/// The exact scope a permission request would be remembered by: its own
/// patterns and the standing grant the server proposes, never display text.
PermissionConsentScope permissionConsentScope(PermissionRequest permission) =>
    PermissionConsentScope(
      sessionID: permission.sessionID,
      permission: permission.permission,
      patterns: permission.patterns,
      alwaysPatterns: permission.always,
    );

/// "Always allow this" on the third identical ask (P6.7, consent once, in
/// flow): one line under a permission request's card, shown once per server
/// and scope, and only where the server keeps saved grants.
///
/// It counts the request when it first builds (a replayed request is not
/// counted again) and shows only when [RepeatedPermissionConsent] hands out
/// the one-time invitation. Accepting states the grant's scope first, then
/// answers the request with `always` through the same path as the card; the
/// invitation is recorded as accepted only once the server took that answer,
/// and the grant is then on the server's Always allowed actions. "Keep
/// asking" is remembered, explained on What runs by itself, and the card's
/// Allow once and Reject stay as they were. Nothing here answers by itself.
///
/// The conversation owns where it sits: directly under the request's card,
/// keyed by the request id.
class AlwaysAllowInvitation extends StatefulWidget {
  const AlwaysAllowInvitation({
    super.key,
    required this.controller,
    required this.permission,
    this.contextLabel,
  });

  final ConnectionController controller;
  final PermissionRequest permission;

  /// Where the grant applies, as the request sheet says it ("in this
  /// conversation" by default).
  final String? contextLabel;

  @override
  State<AlwaysAllowInvitation> createState() => _AlwaysAllowInvitationState();
}

class _AlwaysAllowInvitationState extends State<AlwaysAllowInvitation> {
  bool _invited = false;
  bool _working = false;
  bool _failed = false;

  String? get _profileId => widget.controller.profile?.id;

  String get _requestKey =>
      '${widget.permission.sessionID}/${widget.permission.id}';

  @override
  void initState() {
    super.initState();
    final profileId = _profileId;
    final controller = widget.controller;
    if (profileId == null ||
        !controller.capabilities.persistentPermissionGrants) {
      return;
    }
    // Rebuilt for a request already invited: the history now answers
    // "offered", but the invitation still belongs under this card.
    _invited = ConsentOwners.invitedRequests(
      controller.store.prefs,
      profileId,
    ).contains(_requestKey);
    if (!_invited) unawaited(_observe(profileId));
  }

  Future<void> _observe(String profileId) async {
    final prefs = widget.controller.store.prefs;
    final invited = ConsentOwners.invitedRequests(prefs, profileId);
    final status = await ConsentOwners.repeated(prefs, profileId).observe(
      scope: permissionConsentScope(widget.permission),
      requestID: widget.permission.id,
      supportsPersistentGrants: true,
    );
    if (!status.offerAlwaysAllow) return;
    invited.add(_requestKey);
    if (mounted) setState(() => _invited = true);
  }

  void _done() {
    final profileId = _profileId;
    if (profileId != null) {
      ConsentOwners.invitedRequests(
        widget.controller.store.prefs,
        profileId,
      ).remove(_requestKey);
    }
    if (mounted) setState(() => _invited = false);
  }

  Future<void> _accept() async {
    final profileId = _profileId;
    if (_working || profileId == null) return;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final permission = widget.permission;
    final broader = permission.always.isNotEmpty
        ? permission.always
        : permission.patterns;
    final confirmed = await showKitConfirm(
      context,
      title: l10n.chatRequestAlwaysTitle,
      body: l10n.chatRequestAlwaysScope(
        broader.isEmpty
            ? l10n.chatUiAllMatchingRequests
            : KitBidi.ltr(broader.join(', ')),
        widget.contextLabel ?? l10n.chatUiInThisChat,
      ),
      confirmLabel: l10n.chatUiAlwaysAllow,
      icon: AppIconography.privacy,
      sheetKey: const ValueKey('always-allow-invite-confirm'),
      confirmKey: const ValueKey('always-allow-invite-confirm-allow'),
    );
    if (!confirmed || !mounted) return;
    final controller = widget.controller;
    final request = controller.permissionIdentity(permission);
    if (!controller.isRequestPending(request)) return;
    setState(() {
      _working = true;
      _failed = false;
    });
    try {
      await controller.answerPermission(
        permission.id,
        'always',
        expectedRequest: request,
      );
    } catch (_) {
      // Recorded only once the server took the answer: a refusal is said
      // here and the invitation stays for another try.
      if (mounted) {
        setState(() {
          _working = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) setState(() => _working = false);
    await ConsentOwners.repeated(
      controller.store.prefs,
      profileId,
    ).recordDecision(permissionConsentScope(permission), accepted: true);
    _done();
  }

  Future<void> _decline() async {
    final profileId = _profileId;
    if (_working || profileId == null) return;
    _done();
    await ConsentOwners.repeated(
      widget.controller.store.prefs,
      profileId,
    ).recordDecision(
      permissionConsentScope(widget.permission),
      accepted: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_invited) return const SizedBox.shrink();
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final permission = widget.permission;
    final what = permission.always.isNotEmpty
        ? permission.always.join(', ')
        : permission.patterns.isNotEmpty
        ? permission.patterns.join(', ')
        : permission.permission;
    final ask = KitAskLine(
      key: const ValueKey('always-allow-invite'),
      icon: AppIconography.privacy,
      question: l10n.consentAlwaysAllowQuestion(KitBidi.ltr(what)),
      decline: KitAction(
        key: const ValueKey('always-allow-invite-decline'),
        label: l10n.consentAlwaysAllowDecline,
        onPressed: _working ? null : () => unawaited(_decline()),
      ),
      accept: KitAction(
        key: const ValueKey('always-allow-invite-accept'),
        label: l10n.chatUiAlwaysAllow,
        onPressed: _working ? null : () => unawaited(_accept()),
      ),
    );
    if (!_failed) return ask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitNotice(
          key: const ValueKey('always-allow-invite-failed'),
          tone: AppStatusTone.failure,
          message: l10n.consentAlwaysAllowFailed,
        ),
        ask,
      ],
    );
  }
}
