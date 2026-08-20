import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory_activity.dart';
import '../services/activity_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdViewModel>().current;

    if (household == null) {
      return const Scaffold(
        body: Center(child: Text('Select a household to see activity.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: StreamBuilder<List<InventoryActivity>>(
        stream: ActivityService.instance.streamRecentActivity(household.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Text('Could not load activity: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activity = snapshot.data ?? const <InventoryActivity>[];
          if (activity.isEmpty) {
            return const Center(child: Text('No recent activity yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            itemBuilder: (context, index) {
              final entry = activity[index];
              return ListTile(
                leading: Icon(_iconFor(entry.eventType)),
                title: Text(entry.title),
                subtitle: Text(entry.subtitle),
                trailing: Text(_timeLabel(entry.createdAt)),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: activity.length,
          );
        },
      ),
    );
  }

  IconData _iconFor(InventoryActivityType type) => switch (type) {
    InventoryActivityType.itemAdded => Icons.add_circle_outline,
    InventoryActivityType.itemChanged => Icons.edit_outlined,
    InventoryActivityType.itemRemoved => Icons.remove_circle_outline,
    InventoryActivityType.itemConsumed => Icons.check_circle_outline,
    InventoryActivityType.itemRestored => Icons.restore_outlined,
    InventoryActivityType.unknown => Icons.history_outlined,
  };

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final elapsed = now.difference(value);
    if (elapsed.inMinutes < 1) return 'now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h';
    return '${elapsed.inDays}d';
  }
}
