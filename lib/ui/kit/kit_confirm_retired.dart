import 'package:flutter/widgets.dart';

import '../app_iconography.dart';
import '../widgets/request_routes.dart';
import 'kit_sheet.dart';

/// Retired by shared-shell-1: use [showKitConfirm] with a [KitConfirmKind].
///
/// The older name of [showKitConfirm] (docs/ux-system/kit-v2.md §2.14,
/// STANDARDS KIT-38, KIT-43). It moved here from
/// `lib/ui/widgets/confirm_sheet.dart` (R12), which still re-exports it, so
/// its remaining call sites keep compiling and get the kit's confirmation at
/// once. Gate G2 counts every call (`showConfirmSheet(`), so the call sites
/// only shrink; the unit that brings the count to zero deletes this file.
///
/// [message] is the body. [destructive] maps to [KitConfirmKind.destructive]
/// unless [kind] says otherwise (a stop is [KitConfirmKind.stop]). The old
/// default "?" icon and the English "Cancel" give way to the kind's own icon
/// and cancel word. Returns true only when the confirming action is chosen.
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
