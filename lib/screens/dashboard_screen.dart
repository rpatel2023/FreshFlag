import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';
import 'add_item_screen.dart';
import 'barcode_scanner_screen.dart';
import 'item_detail_screen.dart';

/// Firestore-backed inventory dashboard.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCategory = 'All';

  static const _categories = <String>[
    'All',
    'Fruits',
    'Vegetables',
    'Dairy',
    'Meat',
    'Bakery',
    'Beverages',
    'Snacks',
    'Frozen',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<GroceryViewModel>();
    final visibleItems = inventory.items.where((item) {
      if (item.isConsumed) return false;
      return _selectedCategory == 'All' || item.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('FreshFlag'),
        actions: [
          IconButton(
            tooltip: 'Refresh inventory',
            onPressed: inventory.isLoading ? null : inventory.loadItems,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: inventory.loadItems,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Add item',
                    onTap: () => _openAddItem(context),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan barcode',
                    onTap: () => _openScanner(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),
            _InventorySummary(inventory: inventory),
            const SizedBox(height: AppTheme.spacingL),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTheme.spacingS),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) => setState(
                      () => _selectedCategory = category,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            if (inventory.isLoading && inventory.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (inventory.error != null && inventory.items.isEmpty)
              _ErrorState(
                message: inventory.error!,
                onRetry: inventory.loadItems,
              )
            else if (visibleItems.isEmpty)
              const _EmptyState()
            else
              ...visibleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                  child: _InventoryCard(
                    item: item,
                    onTap: () => _openItem(context, item),
                    onDelete: () => _deleteItem(context, item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddItem(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  Future<void> _openItem(BuildContext context, GroceryItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          itemId: item.id,
          initialItem: item,
        ),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, GroceryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove ${item.name} from your inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<GroceryViewModel>().deleteItem(item.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete item.')),
      );
    }
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              Icon(icon, size: 32, color: AppTheme.primaryGreen),
              const SizedBox(height: AppTheme.spacingS),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({required this.inventory});

  final GroceryViewModel inventory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryValue(label: 'Items', value: inventory.items.length),
            _SummaryValue(
              label: 'Expiring',
              value: inventory.expiringSoonItems.length,
            ),
            _SummaryValue(
              label: 'Expired',
              value: inventory.expiredItems.length,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label),
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final GroceryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final status = item.isExpired
        ? 'Expired'
        : days == 0
            ? 'Expires today'
            : 'Expires in $days day${days == 1 ? '' : 's'}';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.lightGreen,
          child: const Icon(Icons.inventory_2_outlined),
        ),
        title: Text(item.name),
        subtitle: Text(
          '${item.category} • Qty ${item.quantity}\n$status'
          '${item.barcode == null ? '' : '\nBarcode: ${item.barcode}'}',
        ),
        isThreeLine: item.barcode != null,
        trailing: IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 64),
          SizedBox(height: AppTheme.spacingM),
          Text('No items yet'),
          SizedBox(height: AppTheme.spacingS),
          Text('Add an item manually or scan a barcode to get started.'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: AppTheme.spacingM),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacingM),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
