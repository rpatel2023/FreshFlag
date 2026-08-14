import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({
    super.key,
    required this.itemId,
    required this.initialItem,
  });

  final String itemId;
  final GroceryItem initialItem;

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<GroceryViewModel>();
    final liveItem = inventory.getItemById(itemId);
    final item = liveItem ?? (inventory.isLoading ? initialItem : null);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Item details')),
      body: item == null
          ? const _UnavailableItem()
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: AppTheme.spacingXS),
                                  Text(item.category),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        _DetailRow(
                          label: 'Expiry date',
                          value: GroceryItem.formatDateOnly(item.expiryDate),
                        ),
                        _DetailRow(label: 'Status', value: _statusText(item)),
                        _DetailRow(label: 'Quantity', value: '${item.quantity}'),
                        if (item.location != null && item.location!.trim().isNotEmpty)
                          _DetailRow(label: 'Location', value: item.location!.trim()),
                        if (item.barcode != null && item.barcode!.isNotEmpty)
                          _DetailRow(label: 'Barcode', value: item.barcode!),
                        if (item.notes != null && item.notes!.trim().isNotEmpty)
                          _DetailRow(label: 'Notes', value: item.notes!.trim()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FilledButton.icon(
                  onPressed: inventory.isUploading
                      ? null
                      : () => _setConsumed(context, item, !item.isConsumed),
                  icon: Icon(
                    item.isConsumed ? Icons.undo : Icons.check_circle_outline,
                  ),
                  label: Text(
                    item.isConsumed ? 'Restore to inventory' : 'Mark consumed',
                  ),
                ),
              ],
            ),
    );
  }

  static String _statusText(GroceryItem item) {
    if (item.isConsumed) return 'Consumed';
    if (item.isExpired) return 'Expired';
    final days = item.daysUntilExpiry;
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }

  static Future<void> _setConsumed(
    BuildContext context,
    GroceryItem item,
    bool consumed,
  ) async {
    try {
      await context
          .read<GroceryViewModel>()
          .updateItem(item.copyWith(isConsumed: consumed));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            consumed
                ? 'Could not mark item consumed.'
                : 'Could not restore item.',
          ),
        ),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _UnavailableItem extends StatelessWidget {
  const _UnavailableItem();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56),
            SizedBox(height: AppTheme.spacingM),
            Text('This item is no longer available.'),
          ],
        ),
      ),
    );
  }
}
