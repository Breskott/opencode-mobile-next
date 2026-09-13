import '../../l10n/app_localizations.dart';
import '../widgets/setup_ui_messages.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../platform/camera.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/pairing.dart';
import '../app_iconography.dart';

/// Scans the QR that `opencode2 pair` prints and returns the parsed payload.
///
/// Pops with a [PairingPayload] on success and `null` on every other exit, so
/// the caller has exactly one thing to check. The decoded text is fed to the
/// same [parsePairingPayload] the clipboard path uses — a QR is just another
/// way to get the string across, and it deserves no second, laxer parser.
///
/// The raw decoded text is never held in state, never rendered, and never
/// logged: any QR in the world can be pointed at this screen, but the one we
/// are looking for carries the serve password.
class PairingScannerScreen extends StatefulWidget {
  const PairingScannerScreen({super.key});

  @override
  State<PairingScannerScreen> createState() => _PairingScannerScreenState();
}

/// What the scanner is doing, so the screen renders one honest state rather
/// than a preview with an error painted over it.
enum _ScanStage {
  /// Asking the platform for the camera.
  starting,

  /// Preview is up and looking for a code.
  scanning,

  /// The user said no, and can be asked again.
  denied,

  /// The user said no twice, or ticked "don't ask again". Only app settings
  /// can undo this.
  permanentlyDenied,

  /// There is no camera on this device.
  noCamera,

  /// Something else went wrong opening the camera.
  failed,
}

class _PairingScannerScreenState extends State<PairingScannerScreen> {
  MobileScannerController? _controller;
  _ScanStage _stage = _ScanStage.starting;

  /// Why the last decode was rejected. Shown under the preview so the user
  /// can tell "that QR is not a pairing code" from "the camera is broken",
  /// while scanning continues.
  String? _rejected;

  /// Set the instant a valid payload is found, so a second frame decoding the
  /// same code cannot pop the route twice.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // Backstop: the affordance that opens this screen is gated, but a route
    // is reachable by other means and a desktop build has no camera code to
    // run at all.
    if (!platformCapabilities.supportsQrPairing) {
      if (mounted) setState(() => _stage = _ScanStage.noCamera);
      return;
    }
    if (!await cameraPlatform.hasCamera()) {
      if (mounted) setState(() => _stage = _ScanStage.noCamera);
      return;
    }
    final permission = await cameraPlatform.requestCameraPermission();
    if (!mounted) return;
    switch (permission) {
      case CameraPermission.denied:
        setState(() => _stage = _ScanStage.denied);
        return;
      case CameraPermission.permanentlyDenied:
        setState(() => _stage = _ScanStage.permanentlyDenied);
        return;
      case CameraPermission.granted:
        break;
    }
    final controller = MobileScannerController(
      // Only QR carries pairing codes; narrowing the formats keeps the
      // decoder from spending frames on barcodes we would reject anyway.
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    try {
      await controller.start();
    } catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _stage = _ScanStage.failed;
        // A camera failure message is about the device, not the payload, so
        // it is safe to show — and it is the only clue the user has.
        _rejected = error is MobileScannerException
            ? error.errorDetails?.message ?? error.errorCode.name
            : '$error';
      });
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _stage = _ScanStage.scanning;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final parsed = parsePairingPayload(raw);
      if (parsed.ok) {
        _handled = true;
        // Stop before popping so no further frame is decoded behind the
        // closing route.
        unawaited(_controller?.stop());
        Navigator.of(context).pop(parsed.payload);
        return;
      }
      // Not a pairing code. Say so and keep scanning — the user has very
      // likely just pointed the camera at the wrong QR.
      if (_rejected != parsed.error) {
        setState(() => _rejected = parsed.error);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('pairing-scanner-screen'),
      appBar: AppBar(
        leading: IconButton(
          tooltip: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7SetupCloseScanner,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(AppIconography.close),
        ),
        title: Text(
          lookupAppLocalizations(
            Localizations.localeOf(context),
          ).e7SetupScanPairing,
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _ScanStage.starting => const Center(
            key: ValueKey('pairing-scanner-starting'),
            child: CircularProgressIndicator(),
          ),
          _ScanStage.scanning => _preview(theme),
          _ScanStage.denied => _Recovery(
            key: const ValueKey('pairing-scanner-denied'),
            icon: AppIconography.camera,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupCameraNeeded,
            body: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupCameraPrivacy,
            primaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).isolatedTaskRetryOpen,
            onPrimary: () {
              setState(() => _stage = _ScanStage.starting);
              unawaited(_start());
            },
            secondaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupPasteInstead,
            onSecondary: () => Navigator.of(context).pop(),
          ),
          _ScanStage.permanentlyDenied => _Recovery(
            key: const ValueKey('pairing-scanner-blocked'),
            icon: AppIconography.cameraOff,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupCameraDisabled,
            body: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupCameraSettingsDetail,
            primaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupOpenAppSettings,
            onPrimary: () => unawaited(cameraPlatform.openAppSettings()),
            secondaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupPasteInstead,
            onSecondary: () => Navigator.of(context).pop(),
          ),
          _ScanStage.noCamera => _Recovery(
            key: const ValueKey('pairing-scanner-no-camera'),
            icon: AppIconography.cameraOff,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupNoCamera,
            body: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupNoCameraDetail,
            primaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupPasteInstead,
            onPrimary: () => Navigator.of(context).pop(),
          ),
          _ScanStage.failed => _Recovery(
            key: const ValueKey('pairing-scanner-failed'),
            icon: AppIconography.error,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupCameraFailed,
            body: [
              ?_rejected,
              lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7SetupCameraFailedDetail,
            ].join('\n\n'),
            primaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).isolatedTaskRetryOpen,
            onPrimary: () {
              setState(() {
                _stage = _ScanStage.starting;
                _rejected = null;
              });
              unawaited(_start());
            },
            secondaryLabel: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7SetupPasteInstead,
            onSecondary: () => Navigator.of(context).pop(),
          ),
        },
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rejected = _rejected;
    return Column(
      key: const ValueKey('pairing-scanner-preview'),
      children: [
        Expanded(
          child: MobileScanner(controller: controller, onDetect: _onDetect),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).e7SetupScanInstruction,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (rejected != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  key: const ValueKey('pairing-scanner-rejected'),
                  container: true,
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      setupUiMessage(
                        lookupAppLocalizations(Localizations.localeOf(context)),
                        rejected,
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A full-screen "this did not work, here is what to do" state.
class _Recovery extends StatelessWidget {
  const _Recovery({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('pairing-scanner-primary'),
          onPressed: onPrimary,
          child: Text(primaryLabel),
        ),
        if (secondaryLabel case final label?) ...[
          const SizedBox(height: 10),
          TextButton(
            key: const ValueKey('pairing-scanner-secondary'),
            onPressed: onSecondary,
            child: Text(label),
          ),
        ],
      ],
    );
  }
}
