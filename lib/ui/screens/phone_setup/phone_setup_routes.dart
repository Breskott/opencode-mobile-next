import 'package:flutter/material.dart';

import 'phone_setup_ready_screen.dart';

// Routes between the phone setup screens (docs/design/phone-setup-v2-2026-09-24.md).
// Each screen's owner replaces only its own function below; the others call
// these, so the screens can be built in parallel.

/// Screen A: "On this phone".
Future<void> openPhoneSetupStart(BuildContext context) async {
  // Replaced by screen A.
}

/// Screen A's Customize sheet. [addMode] is "Add tools" from screen D: only
/// optional components, installed ones shown as installed.
Future<Set<String>?> showPhoneSetupCustomize(
  BuildContext context, {
  bool addMode = false,
}) async {
  // Replaced by screen A.
  return null;
}

/// Screen B: the setup in progress (and continue after an interruption).
Future<void> openPhoneSetupProgress(BuildContext context) async {
  // Replaced by screen B.
}

/// Screen C: ready, name the first project. It takes the progress screen's
/// place, so Back never returns to a finished setup. Screen B calls it only
/// when a first setup is done; updates and added tools end on B.
Future<void> openPhoneSetupReady(BuildContext context) =>
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => const PhoneSetupReadyScreen()),
    );
