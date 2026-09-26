import 'package:flutter/material.dart';

import 'request_routes.dart';
import '../app_iconography.dart';
import '../kit/kit_sheet.dart';

/// The older name of [showKitConfirm] (docs/ux-system/kit-v2.md §2.14):
/// deprecated, kept as a thin wrapper so its call sites get the kit's
/// confirmation at once. New code calls [showKitConfirm] with a [kind];
/// this wrapper is deleted once every call site passes one.
///
/// [message] is the body. [destructive] maps to [KitConfirmKind.destructive]
/// unless [kind] says otherwise (a stop is [KitConfirmKind.stop]). The old
/// default "?" icon and the English "Cancel" give way to the kind's own
/// icon and cancel word. Returns true only when the confirming action is
/// chosen.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  IconData? icon,
  bool destructive = false,
  KitConfirmKind? kind,
  Key? sheetKey,
  Key? confirmKey,
  RequestRoutes? routes,
}) => showKitConfirm(
  context,
  title: title,
  body: message,
  confirmLabel: confirmLabel,
  kind:
      kind ??
      (destructive ? KitConfirmKind.destructive : KitConfirmKind.neutral),
  cancelLabel: cancelLabel == 'Cancel' ? null : cancelLabel,
  icon: icon == AppIconography.question ? null : icon,
  sheetKey: sheetKey,
  confirmKey: confirmKey,
  routes: routes,
);

/// End-swipe reveal behind list rows whose swipe leads into the destructive
/// confirm flow above: a destructive field with a trailing delete glyph.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 24),
      child: Icon(AppIconography.delete, color: scheme.onErrorContainer),
    );
  }
}
