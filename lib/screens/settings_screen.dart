import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/fcm_service.dart';
import '../services/firebase_auth_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';
import 'household_invite_screen.dart';
import 'household_members_screen.dart';
import 'notification_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _loadingNotificationState = true;
  bool _updatingNotifications = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotificationState());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<FirebaseAuthService>();
    final user = auth.currentUser;
    final theme = context.watch<ThemeProvider>();
    final household = context.watch<HouseholdViewModel>();
    final current = household.current;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                user?.displayName?.trim().isNotEmpty == true
                    ? user!.displayName!
                    : 'FreshFlag user',
              ),
              subtitle: Text(user?.email ?? 'Signed in'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (current != null)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: Text(current.name),
                    subtitle: Text(
                      '${current.timezone} • ${household.isOwner ? 'Owner' : 'Member'}',
                    ),
                    trailing: household.isOwner
                        ? IconButton(
                            tooltip: 'Edit household',
                            onPressed: household.isLoading
                                ? null
                                : () => _editHousehold(
                                      context,
                                      current.name,
                                      current.timezone,
                                    ),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Household members'),
                    subtitle: Text(
                      household.isOwner
                          ? 'View members or remove access'
                          : 'View members or leave this household',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HouseholdMembersScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text('Household sharing'),
                    subtitle: Text(
                      household.isOwner
                          ? 'Create invite codes or join another household'
                          : 'Join another household with an invite code',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HouseholdInviteScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Expiry reminder rules'),
                    subtitle: Text(
                      household.isOwner
                          ? 'Choose days, send time, and reminder messages'
                          : 'View household reminder rules',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationRulesScreen(),
                      ),
                    ),
                  ),
                  if (household.households.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingM,
                        0,
                        AppTheme.spacingM,
                        AppTheme.spacingM,
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: current.id,
                        decoration: const InputDecoration(
                          labelText: 'Active household',
                        ),
                        items: household.households
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: household.isLoading
                            ? null
                            : (value) async {
                                if (value != null) {
                                  await household.selectHousehold(value);
                                }
                              },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.spacingM),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: Text(
                    _loadingNotificationState
                        ? 'Checking notification permission…'
                        : _notificationsEnabled
                            ? 'Household expiry reminders are enabled'
                            : 'Enable to receive household expiry reminders',
                  ),
                  value: _notificationsEnabled,
                  onChanged: _loadingNotificationState || _updatingNotifications
                      ? null
                      : _setNotificationsEnabled,
                ),
                SwitchListTile(
                  title: const Text('Dark mode'),
                  value: theme.isDarkMode,
                  onChanged: (_) => theme.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('FreshFlag'),
                  subtitle: Text('Shared household inventory build'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotificationState() async {
    final enabled = await FCMService.instance.syncPushPreferenceForCurrentUser();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _loadingNotificationState = false;
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    setState(() => _updatingNotifications = true);
    try {
      await FCMService.instance.setPushEnabledForCurrentUser(value);
      if (!mounted) return;
      setState(() => _notificationsEnabled = value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingNotifications = false);
    }
  }

  Future<void> _editHousehold(
    BuildContext context,
    String currentName,
    String currentTimezone,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: currentName);
    final timezoneController = TextEditingController(text: currentTimezone);

    final input = await showDialog<_HouseholdSettingsInput>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Household settings'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Household name'),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Enter a household name'
                    : null,
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: timezoneController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'IANA timezone',
                  helperText: 'For example America/Toronto',
                ),
                validator: (value) {
                  final timezone = value?.trim() ?? '';
                  return timezone.isEmpty || !timezone.contains('/')
                      ? 'Enter a timezone such as America/Toronto'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                _HouseholdSettingsInput(
                  nameController.text.trim(),
                  timezoneController.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    timezoneController.dispose();
    if (input == null || !context.mounted) return;

    try {
      await context.read<HouseholdViewModel>().updateCurrentHousehold(
            name: input.name,
            timezone: input.timezone,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update household: $e')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await context.read<FirebaseAuthService>().signOut();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not sign out: $e')),
      );
    }
  }
}

class _HouseholdSettingsInput {
  const _HouseholdSettingsInput(this.name, this.timezone);

  final String name;
  final String timezone;
}
