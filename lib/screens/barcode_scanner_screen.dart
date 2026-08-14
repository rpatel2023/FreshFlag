import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/app_theme.dart';
import 'add_item_screen.dart';

/// Scans a packaged-food barcode and hands the captured value to Add Item.
///
/// Product recognition is intentionally deferred to Phase 2. Phase 1 only
/// guarantees that a scanned barcode is no longer discarded.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _handlingBarcode = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            onPressed: _toggleTorch,
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryGreen,
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppTheme.spacingL,
            right: AppTheme.spacingL,
            bottom: AppTheme.spacingXL,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Place the product barcode inside the frame.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      TextButton(
                        onPressed: _handlingBarcode ? null : _addManually,
                        child: const Text('Add manually instead'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handlingBarcode) return;

    String? value;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        value = candidate;
        break;
      }
    }

    if (value == null) return;

    setState(() => _handlingBarcode = true);
    await _controller.stop();

    if (!mounted) return;

    final action = await showModalBottomSheet<_ScanAction>(
      context: context,
      isDismissible: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 52,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(height: AppTheme.spacingM),
              const Text(
                'Barcode scanned',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingS),
              SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: AppTheme.spacingL),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, _ScanAction.scanAgain),
                      child: const Text('Scan again'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _ScanAction.add),
                      child: const Text('Add item'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (action == _ScanAction.add) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AddItemScreen(initialBarcode: value),
        ),
      );
      return;
    }

    setState(() => _handlingBarcode = false);
    await _controller.start();
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) {
      setState(() => _torchOn = !_torchOn);
    }
  }

  void _addManually() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
  }
}

enum _ScanAction { scanAgain, add }
