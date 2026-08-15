import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_brand.dart';
import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';
import '../viewmodels/household_viewmodel.dart';
import 'add_item_screen.dart';
import 'barcode_scanner_screen.dart';
import 'item_detail_screen.dart';

enum _InventoryView { active, consumed }
enum _InventorySort { expiry, name, recentlyAdded }

/// Firestore-backed inventory dashboard.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  _InventoryView _selectedView = _InventoryView.active;
  _InventorySort _sort = _InventorySort.expiry;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<GroceryViewModel>();
    final household = context.watch<HouseholdViewModel>();
    final canWrite = household.canWriteInventory;
    final activeItems = inventory.items.where((item) => !item.isConsumed).toList();
    final consumedItems = inventory.items.where((item) => item.isConsumed).toList();
    final sourceItems = _selectedView == _InventoryView.active
        ? activeItems
        : consumedItems;
    final query = _searchQuery.trim().toLowerCase();
    final visibleItems = sourceItems.where((item) {
      final categoryMatches =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final searchMatches = query.isEmpty || item.name.toLowerCase().contains(query);
      return categoryMatches && searchMatches;
    }).toList();
    _sortItems(visibleItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppBrand.name),
        actions: [
          PopupMenuButton<_InventorySort>(
            tooltip: 'Sort inventory',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _InventorySort.expiry,
                child: Text('Expiry soonest'),
              ),
              PopupMenuItem(
                value: _InventorySort.name,
                child: Text('Name A–Z'),
              ),
              PopupMenuItem(
                value: _InventorySort.recentlyAdded,
                child: Text('Recently added'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
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
            if (canWrite)
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
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Guest access'),
                  subtitle: Text('This household is read-only for your account.'),
                ),
              ),
            const SizedBox(height: AppTheme.spacingL),
            _InventorySummary(
              inventory: inventory,
              activeCount: activeItems.length,
              consumedCount: consumedItems.length,
            ),
            const SizedBox(height: AppTheme.spacingL),
            SegmentedButton<_InventoryView>(
              segments: [
                ButtonSegment(
                  value: _InventoryView.active,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text('Active (${activeItems.length})'),
                ),
                ButtonSegment(
                  value: _InventoryView.consumed,
                  icon: const Icon(Icons.history),
                  label: Text('Consumed (${consumedItems.length})'),
                ),
              ],
              selected: {_selectedView},
              onSelectionChanged: (selection) {
                setState(() => _selectedView = selection.first);
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                labelText: 'Search inventory',
                hintText: 'Search by item name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
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
              _EmptyState(
                consumedView: _selectedView == _InventoryView.consumed,
                filtered: _selectedCategory != 'All' || query.isNotEmpty,
              )
            else
              ...visibleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                  child: _InventoryCard(
                    item: item,
                    onTap: () => _openItem(context, item),
                    onDelete: canWrite ? () => _deleteItem(context, item) : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _sortItems(List<GroceryItem> items) {
    if (_sort == _InventorySort.expiry) {
      items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    } else if (_sort == _InventorySort.name) {
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else {
      items.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    }
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
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
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
  const _InventorySummary({
    required this.inventory,
    required this.activeCount,
    required this.consumedCount,
  });

  final GroceryViewModel inventory;
  final int activeCount;
  final int consumedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryValue(label: 'Active', value: activeCount),
            _SummaryValue(
              label: 'Expiring',
              value: inventory.expiringSoonItems.length,
            ),
            _SummaryValue(
              label: 'Expired',
              value: inventory.expiredItems.length,
            ),
            _SummaryValue(label: 'Consumed', value: consumedCount),
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
    this.onDelete,
  });

  final GroceryItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final status = item.isConsumed
        ? 'Consumed'
        : item.isExpired
            ? 'Expired'
            : days == 0
                ? 'Expires today'
                : days == 1
                    ? 'Expires tomorrow'
                    : 'Expires in $days days';
    final scheme = Theme.of(context).colorScheme;
    final metadata = <String>[
      item.category,
      'Qty ${item.quantity}',
      if (item.location?.trim().isNotEmpty == true) item.location!.trim(),
    ].join(' • ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            item.isConsumed ? Icons.history : Icons.inventory_2_outlined,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(item.name),
        subtitle: Text('$metadata\n$status'),
        isThreeLine: true,
        trailing: onDelete == null
            ? null
            : IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.consumedView, required this.filtered});

  final bool consumedView;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          Icon(
            filtered
                ? Icons.search_off
                : consumedView
                    ? Icons.history
                    : Icons.inventory_2_outlined,
            size: 64,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            filtered
                ? 'No matching items'
                : consumedView
                    ? 'No consumed items'
                    : 'No active items',
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            filtered
                ? 'Try a different search or category.'
                : consumedView
                    ? 'Items you mark consumed will remain available here to restore.'
                    : 'Add an item manually or scan a barcode to get started.',
            textAlign: TextAlign.center,
          ),
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
