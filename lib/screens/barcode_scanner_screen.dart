import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/product_lookup_result.dart';
import '../services/product_lookup_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';
import 'add_item_screen.dart';

/// Scans a packaged-food barcode, recognizes it through Open Food Facts, and
/// hands the barcode plus any recognized display name to Add item.
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
  final ProductLookupService _productLookupService = ProductLookupService();

  bool _handlingBarcode = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    _productLookupService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan barcode'),
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
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryGreen, width: 4),
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
                      Text(
                        _handlingBarcode
                            ? 'Looking up product…'
                            : 'Place the product barcode inside the frame.',
                        textAlign: TextAlign.center,
                      ),
                      if (_handlingBarcode) ...[
                        const SizedBox(height: AppTheme.spacingM),
                        const CircularProgressIndicator(),
                      ] else ...[
                        const SizedBox(height: AppTheme.spacingS),
                        TextButton(
                          onPressed: _addManually,
                          child: const Text('Add manually instead'),
                        ),
                      ],
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
    final scannedValue = value;
    final inventory = context.read<GroceryViewModel>();

    setState(() => _handlingBarcode = true);
    await _controller.stop();

    ProductLookupResult? product;
    String? lookupMessage;
    try {
      product = await inventory.lookupCachedProduct(scannedValue);
      product ??= await _productLookupService.lookupBarcode(scannedValue);
      if (product == null) {
        lookupMessage = 'Product not found. You can enter the name manually.';
      }
    } on ProductLookupException catch (e) {
      lookupMessage = e.message;
    }

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
              Icon(
                product == null
                    ? Icons.help_outline
                    : Icons.check_circle_outline,
                size: 52,
                color: product == null
                    ? AppTheme.warningOrange
                    : AppTheme.primaryGreen,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                product == null ? 'Barcode scanned' : product.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (product?.quantityLabel != null) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(product!.quantityLabel!),
              ],
              const SizedBox(height: AppTheme.spacingS),
              SelectableText(
                scannedValue,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              if (lookupMessage != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                Text(lookupMessage, textAlign: TextAlign.center),
              ],
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
                      child: Text(
                        product == null ? 'Enter manually' : 'Set expiry',
                      ),
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
          builder: (_) => AddItemScreen(
            initialBarcode: scannedValue,
            initialName: product?.name,
            initialCategory: product?.category,
          ),
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
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AddItemScreen()));
  }
}

enum _ScanAction { scanAgain, add }
