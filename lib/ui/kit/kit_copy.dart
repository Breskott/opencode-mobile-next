import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'kit_redact.dart';
import 'motion/kit_haptics.dart';

/// The one way the app copies text: redacted, confirmed by a light tick and
/// a single screen-reader announcement. Never a SnackBar — the control that
/// copied shows its own brief "copied" state if it wants one.
abstract final class KitCopy {
  /// Copies [text] to the clipboard after masking secrets with
  /// [KitRedact.text], then announces [announcement] (default: "Copied")
  /// once.
  static Future<void> copy(
    BuildContext context,
    String text, {
    String? announcement,
  }) async {
    final safe = KitRedact.text(text);
    final message =
        announcement ??
        lookupAppLocalizations(Localizations.localeOf(context)).kitCopied;
    final view = View.of(context);
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    KitHaptics.send(context);
    await Clipboard.setData(ClipboardData(text: safe));
    await SemanticsService.sendAnnouncement(view, message, direction);
  }
}
