import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_target.dart';
import '../services/fcm_service.dart';
import '../viewmodels/grocery_viewmodel.dart';
import '../viewmodels/household_viewmodel.dart';
import 'dashboard_screen.dart';
import 'item_detail_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

/// Main authenticated FreshFlag shell.
class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  StreamSubscription<NotificationTarget>? _notificationSubscription;
  NotificationTarget? _queuedTarget;
  bool _isOpeningNotification = false;

  static const _screens = <Widget>[
    DashboardScreen(),
    RemindersScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _notificationSubscription = FCMService.instance.navigationTargets.listen(
      (target) {
        // The stream event is authoritative for live taps. Clearing the
        // pending slot prevents the same target being replayed if the shell is
        // rebuilt, without replacing this event with a newer queued target.
        FCMService.instance.takePendingNavigationTarget();
        unawaited(_openNotificationTarget(target));
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = FCMService.instance.takePendingNavigationTarget();
      if (pending != null) {
        unawaited(_openNotificationTarget(pending));
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _openNotificationTarget(NotificationTarget target) async {
    if (_isOpeningNotification) {
      _queuedTarget = target;
      return;
    }

    _isOpeningNotification = true;
    try {
      final households = context.read<HouseholdViewModel>();
      final inventory = context.read<GroceryViewModel>();
      final canAccessHousehold = households.households.any(
        (household) => household.id == target.householdId,
      );

      if (!canAccessHousehold) {
        _showMessage('You no longer have access to this household.');
        return;
      }

      if (households.current?.id != target.householdId) {
        await households.selectHousehold(target.householdId);
      }
      await inventory.bindHousehold(target.householdId);

      final item = inventory.getItemById(target.itemId) ??
          await inventory.fetchItem(target.itemId);
      if (!mounted) return;
      if (item == null) {
        _showMessage('This reminder item is no longer available.');
        return;
      }

      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(
            itemId: target.itemId,
            initialItem: item,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the reminder item.');
      }
    } finally {
      _isOpeningNotification = false;
      final queued = _queuedTarget;
      _queuedTarget = null;
      if (mounted && queued != null) {
        unawaited(_openNotificationTarget(queued));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
