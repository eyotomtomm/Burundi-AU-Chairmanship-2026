import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'manual_lookup_screen.dart';
import 'qr_scan_result_screen.dart';
import 'yd_scan_history_screen.dart';
import '../../l10n/app_localizations.dart';

class QrScannerScreen extends StatefulWidget {
  final String? mode;
  final String? programmeName;

  const QrScannerScreen({super.key, this.mode, this.programmeName});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  String? _lastCode;
  DateTime? _lastScanAt;
  static const _rescanCooldown = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded; resume when the app comes back.
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isProcessing) _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Ignore the same code re-read right after returning from the result screen.
    final now = DateTime.now();
    if (rawValue == _lastCode &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < _rescanCooldown) {
      return;
    }
    _lastCode = rawValue;
    _lastScanAt = now;

    setState(() => _isProcessing = true);

    // Stop camera immediately after detecting a code (one-scan-at-a-time)
    _controller.stop();

    _verifyCode(rawValue);
  }

  Future<void> _verifyCode(String qrData) async {
    try {
      final result = await ApiService().verifyQrCode(qrData);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrScanResultScreen(result: result, mode: widget.mode, programmeName: widget.programmeName),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrScanResultScreen(
            result: {
              'valid': false,
              'detail': e.toString().replaceFirst('Exception: ', ''),
            },
            mode: widget.mode,
            programmeName: widget.programmeName,
          ),
        ),
      );
    } finally {
      if (mounted) {
        // Restart camera when returning from result screen
        _lastScanAt = DateTime.now();
        _controller.start();
        setState(() => _isProcessing = false);
      }
    }
  }

  bool get _isYdMode => widget.mode == 'youth_dialogue';
  String get _programmeName => widget.programmeName ?? 'Continental Dialogue';

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthProvider>().isStaff;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF101810),
      // The comp floats the controls over the camera instead of using a bar.
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) => _CameraError(
              permissionDenied:
                  error.errorCode == MobileScannerErrorCode.permissionDenied,
              onRetry: () => _controller.start(),
            ),
          ),

          // Header row
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.maybePop(context),
                    child: const SizedBox(
                      width: 34,
                      height: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.arrow_back_rounded, size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _isYdMode ? '$_programmeName ${l10n.translate('scan_scanner')}' : l10n.translate('scan_credential_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (_, state, _) => IconButton(
                    icon: Icon(
                      state.torchState == TorchState.on
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _controller.toggleTorch(),
                    tooltip: l10n.translate('scan_toggle_flash'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 20),
                  onPressed: () => _controller.switchCamera(),
                  tooltip: l10n.translate('scan_switch_camera'),
                ),
              ],
            ),
          ),

          // 250px reticle: gold corner brackets + a green scan line.
          Align(
            alignment: const Alignment(0, -0.12),
            child: SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                children: const [
                  Positioned(left: 0, top: 0, child: _Corner(topLeft: true)),
                  Positioned(right: 0, top: 0, child: _Corner(topRight: true)),
                  Positioned(left: 0, bottom: 0, child: _Corner(bottomLeft: true)),
                  Positioned(right: 0, bottom: 0, child: _Corner(bottomRight: true)),
                  Positioned(left: 10, right: 10, top: 118, child: _ScanLine()),
                ],
              ),
            ),
          ),

          // Instruction copy
          Align(
            alignment: const Alignment(0, 0.42),
            child: _isProcessing
                ? const CircularProgressIndicator(color: Ds.green)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isYdMode
                              ? '${l10n.translate('scan_qr_for')} $_programmeName'
                              : l10n.translate('scan_align_frame'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
          ),

          // Glass action bar
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isYdMode)
                  _GlassBar(
                    icon: Icons.history_rounded,
                    label: l10n.translate('scan_history_title'),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const YdScanHistoryScreen())),
                  ),
                if (_isYdMode && isStaff) const SizedBox(height: 10),
                if (isStaff)
                  _GlassBar(
                    icon: Icons.keyboard_rounded,
                    label: l10n.translate('scan_lookup_manually'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManualLookupScreen(
                          mode: widget.mode,
                          programmeName: widget.programmeName,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One 44px gold bracket of the scanner reticle.
class _Corner extends StatelessWidget {
  final bool topLeft, topRight, bottomLeft, bottomRight;
  const _Corner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Ds.gold, width: 4);
    const r = Radius.circular(12);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          left: topLeft || bottomLeft ? side : BorderSide.none,
          right: topRight || bottomRight ? side : BorderSide.none,
          top: topLeft || topRight ? side : BorderSide.none,
          bottom: bottomLeft || bottomRight ? side : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: topLeft ? r : Radius.zero,
          topRight: topRight ? r : Radius.zero,
          bottomLeft: bottomLeft ? r : Radius.zero,
          bottomRight: bottomRight ? r : Radius.zero,
        ),
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine();

  @override
  Widget build(BuildContext context) => Container(
        height: 3,
        decoration: BoxDecoration(
          color: Ds.green,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(color: Ds.green.withValues(alpha: 0.9), blurRadius: 14),
          ],
        ),
      );
}

/// Translucent bar the comp floats over the camera feed.
class _GlassBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassBar({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(Ds.rCard),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Ds.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the camera preview when it cannot start.
/// permission_handler is not a dependency, so we give instructions rather than
/// a deep link into Settings.
class _CameraError extends StatelessWidget {
  final bool permissionDenied;
  final VoidCallback onRetry;
  const _CameraError({required this.permissionDenied, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              permissionDenied
                  ? l10n.translate('camera_permission_denied')
                  : l10n.translate('generic_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
