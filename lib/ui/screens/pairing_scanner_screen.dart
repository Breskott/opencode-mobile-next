import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/camera.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/pairing.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_progress.dart';
import '../kit/kit_screen.dart';
import '../kit/kit_state_view.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../kit/kit_top_bar.dart';
import '../widgets/setup_ui_messages.dart';

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

  /// When the camera was asked for: the starting state escalates from here
  /// after 8 s (STATE-5) and offers pasting instead.
  DateTime _startedAt = DateTime.now();

  /// Why the last decode was rejected. Shown under the preview so the user
  /// can tell "that QR is not a pairing code" from "the camera is broken",
  /// while scanning continues.
  String? _rejected;

  /// The device's own words for a camera that would not open (never a
  /// decoded value): the failed state's Details.
  String? _deviceMessage;

  /// Set the instant a valid payload is found, so a second frame decoding the
  /// same code cannot pop the route twice.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  void _restart() {
    setState(() {
      _stage = _ScanStage.starting;
      _startedAt = DateTime.now();
      _rejected = null;
      _deviceMessage = null;
    });
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
        _deviceMessage = error is MobileScannerException
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
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    void pasteInstead() => Navigator.of(context).pop();
    final paste = KitAction(
      key: const ValueKey('pairing-scanner-secondary'),
      label: l10n.e7SetupPasteInstead,
      icon: AppIconography.paste,
      onPressed: pasteInstead,
    );
    return KitScreen(
      key: const ValueKey('pairing-scanner-screen'),
      topBar: KitTopBar(
        title: l10n.e7SetupScanPairing,
        exit: KitTopBarExit.close,
        exitKey: const ValueKey('pairing-scanner-close'),
      ),
      body: switch (_stage) {
        _ScanStage.starting => KitStateView(
          key: const ValueKey('pairing-scanner-starting'),
          icon: AppIconography.camera,
          tone: AppStatusTone.progress,
          title: l10n.pairingScannerStarting,
          progress: const KitProgress.waiting(),
          since: _startedAt,
          onSlow: [paste],
        ),
        _ScanStage.scanning => _preview(context, l10n),
        _ScanStage.denied => KitStateView(
          key: const ValueKey('pairing-scanner-denied'),
          icon: AppIconography.camera,
          title: l10n.e7SetupCameraNeeded,
          body: l10n.e7SetupCameraPrivacy,
          primary: KitAction(
            key: const ValueKey('pairing-scanner-primary'),
            label: l10n.pairingScannerAllowCamera,
            icon: AppIconography.camera,
            onPressed: _restart,
          ),
          secondary: paste,
        ),
        _ScanStage.permanentlyDenied => KitStateView(
          key: const ValueKey('pairing-scanner-blocked'),
          icon: AppIconography.cameraOff,
          title: l10n.e7SetupCameraDisabled,
          body: l10n.e7SetupCameraSettingsDetail,
          primary: KitAction(
            key: const ValueKey('pairing-scanner-primary'),
            label: l10n.e7SetupOpenAppSettings,
            icon: AppIconography.settings,
            onPressed: () => unawaited(cameraPlatform.openAppSettings()),
          ),
          secondary: paste,
        ),
        _ScanStage.noCamera => KitStateView(
          key: const ValueKey('pairing-scanner-no-camera'),
          icon: AppIconography.cameraOff,
          title: l10n.e7SetupNoCamera,
          body: l10n.e7SetupNoCameraDetail,
          primary: KitAction(
            key: const ValueKey('pairing-scanner-primary'),
            label: l10n.e7SetupPasteInstead,
            icon: AppIconography.paste,
            onPressed: pasteInstead,
          ),
        ),
        _ScanStage.failed => KitStateView(
          key: const ValueKey('pairing-scanner-failed'),
          icon: AppIconography.error,
          tone: AppStatusTone.failure,
          title: l10n.e7SetupCameraFailed,
          body: l10n.e7SetupCameraFailedDetail,
          details: _deviceMessage,
          primary: KitAction(
            key: const ValueKey('pairing-scanner-primary'),
            label: l10n.isolatedTaskRetryOpen,
            icon: AppIconography.retry,
            onPressed: _restart,
          ),
          secondary: paste,
        ),
      },
    );
  }

  Widget _preview(BuildContext context, AppLocalizations l10n) {
    final controller = _controller;
    if (controller == null) {
      return KitStateView(
        icon: AppIconography.camera,
        tone: AppStatusTone.progress,
        title: l10n.pairingScannerStarting,
        progress: const KitProgress.waiting(),
      );
    }
    final tokens = KitTokens.of(context);
    final rejected = _rejected;
    return Column(
      key: const ValueKey('pairing-scanner-preview'),
      children: [
        // The camera surface itself; kit-KitScanner (blocked, not built)
        // will own it with its viewfinder.
        Expanded(
          child: MobileScanner(controller: controller, onDetect: _onDetect),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.gutter,
            tokens.space4,
            tokens.gutter,
            tokens.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KitText(
                l10n.e7SetupScanInstruction,
                textAlign: TextAlign.center,
                tone: KitTextTone.secondary,
              ),
              if (rejected != null) ...[
                SizedBox(height: tokens.space3),
                KitNotice(
                  key: const ValueKey('pairing-scanner-rejected'),
                  icon: AppIconography.warning,
                  message: setupUiMessage(l10n, rejected),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
