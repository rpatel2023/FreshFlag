import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grocery_item.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';

/// Shows expiry reminders directly from the authoritative inventory state.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<GroceryViewModel>();
    final expired = inventory.expiredItems.where((item) => !item.isConsumed).toList();
    final expiring = inventory.expiringSoonItems
        .where((item) => !item.isConsumed && !item.isExpired)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Reminders')),
      body: RefreshIndicator(
        onRefresh: inventory.loadItems,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Count(label: 'Expired', value: expired.length),
                    _Count(label: 'Expiring soon', value: expiring.length),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            if (inventory.isLoading && inventory.items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (inventory.error != null && inventory.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Text(
                  inventory.error!,
                  textAlign: TextAlign.center,
                ),
              )
            else if (expired.isEmpty && expiring.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 64),
                    SizedBox(height: AppTheme.spacingM),
                    Text('Nothing needs attention right now.'),
                  ],
                ),
              )
            else ...[
              if (expired.isNotEmpty) ...[
                Text(
                  'Expired',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacingS),
                ...expired.map(
                  (item) => _ReminderTile(item: item, expired: true),
                ),
                const SizedBox(height: AppTheme.spacingL),
              ],
              if (expiring.isNotEmpty) ...[
                Text(
                  'Expiring soon',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacingS),
                ...expiring.map(
                  (item) => _ReminderTile(item: item, expired: false),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

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

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.item, required this.expired});

  final GroceryItem item;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final subtitle = expired
        ? 'Expired ${days.abs()} day${days.abs() == 1 ? '' : 's'} ago'
        : days == 0
            ? 'Expires today'
            : 'Expires in $days day${days == 1 ? '' : 's'}';

    return Card(
      child: ListTile(
        leading: Icon(
          expired ? Icons.warning_amber_rounded : Icons.schedule,
          color: expired ? AppTheme.errorRed : AppTheme.warningOrange,
        ),
        title: Text(item.name),
        subtitle: Text('$subtitle • Qty ${item.quantity}'),
      ),
    );
  }
}
