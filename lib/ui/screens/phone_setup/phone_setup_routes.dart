import 'package:flutter/material.dart';

import '../../../builtin/setup/phone_setup.dart';
import 'phone_setup_customize_sheet.dart';
import 'phone_setup_progress_screen.dart';
import 'phone_setup_start_screen.dart';

// Routes between the phone setup screens (docs/design/phone-setup-v2-2026-09-24.md).
// Each screen's owner replaces only its own function below; the others call
// these, so the screens can be built in parallel.

/// Screen A: "On this phone".
Future<void> openPhoneSetupStart(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'phone-setup-start'),
        builder: (_) => const PhoneSetupStartScreen(),
      ),
    );

/// Screen A's Customize sheet. [addMode] is "Add tools" from screen D: only
/// optional components, installed ones shown as installed.
///
/// Returns the ids to hand to `SetupEngine.run`, or null when dismissed:
/// the whole selection for first setup, only the new tools in [addMode].
/// [selected] reopens the sheet on an earlier choice instead of the
/// registry defaults.
Future<Set<String>?> showPhoneSetupCustomize(
  BuildContext context, {
  bool addMode = false,
  Set<String>? selected,
}) => showSetupCustomizeSheet(
  context,
  engine: PhoneSetup.engine,
  addMode: addMode,
  selected: selected,
);

/// Screen B: the setup in progress (and continue after an interruption).
Future<void> openPhoneSetupProgress(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PhoneSetupProgressScreen()),
    );

/// Screen C: ready, name the first project.
Future<void> openPhoneSetupReady(BuildContext context) async {
  // Replaced by screen C.
}
