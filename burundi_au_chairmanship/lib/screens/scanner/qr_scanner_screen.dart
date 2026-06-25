import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import 'qr_scan_result_screen.dart';
import 'yd_scan_history_screen.dart';

class QrScannerScreen extends StatefulWidget {
  final String? mode;

  const QrScannerScreen({super.key, this.mode});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

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
          builder: (_) => QrScanResultScreen(result: result, mode: widget.mode),
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
          ),
        ),
      );
    } finally {
      if (mounted) {
        // Restart camera when returning from result screen
        _controller.start();
        setState(() => _isProcessing = false);
      }
    }
  }

  bool get _isYdMode => widget.mode == 'youth_dialogue';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_isYdMode ? 'CD Credential Scanner' : 'QR Scanner'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isYdMode)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YdScanHistoryScreen()),
                );
              },
              tooltip: 'Scan History',
            ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (_, state, __) => IconButton(
              icon: Icon(
                state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
              ),
              onPressed: () => _controller.toggleTorch(),
              tooltip: 'Toggle Flash',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.burundiGreen, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Bottom instruction
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isProcessing)
                  const CircularProgressIndicator(color: AppColors.burundiGreen)
                else
                  Text(
                    _isYdMode
                        ? 'Scan a Continental Dialogue QR code'
                        : 'Point your camera at a QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
