import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_brand.dart';
import '../config/distribution_config.dart';
import '../models/household.dart';
import '../services/fcm_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/household_member_service.dart';
import '../services/local_expiry_notification_service.dart';
import '../services/local_database_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_theme.dart';
import '../viewmodels/grocery_viewmodel.dart';
import '../viewmodels/household_viewmodel.dart';
import 'auth/change_password_screen.dart';
import 'discord_reminders_screen.dart';
import 'household_invite_screen.dart';
import 'household_members_screen.dart';
import 'notification_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = LocalDatabaseService.notificationsEnabled;
  bool _localExpiryRemindersEnabled =
      LocalDatabaseService.localExpiryRemindersEnabled;
  bool _updatingNotifications = false;
  bool _leavingHousehold = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<FirebaseAuthService>();
    final user = auth.currentUser;
    final theme = context.watch<ThemeProvider>();
    final household = context.watch<HouseholdViewModel>();
    final current = household.current;
    final supportsRemotePush = DistributionConfig.supportsRemotePush;
    final roleLabel = household.role?.label ?? 'Member';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(
                    user?.displayName?.trim().isNotEmpty == true
                        ? user!.displayName!
                        : '${AppBrand.name} user',
                  ),
                  subtitle: Text(user?.email ?? 'Signed in'),
                ),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  subtitle: const Text('Update your Fresh Flag sign-in password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
              ],
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
                    subtitle: Text('${current.timezone} • $roleLabel'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Members & access'),
                    subtitle: const Text(
                      'See household members and their roles',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HouseholdMembersScreen(
                          householdId: current.id,
                          householdName: current.name,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text('Household sharing'),
                    subtitle: Text(
                      household.canManageHousehold
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
                      household.canManageHousehold
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
                  if (!household.isOwner)
                    ListTile(
                      leading: const Icon(Icons.exit_to_app),
                      title: const Text('Leave household'),
                      subtitle: const Text(
                        'Remove your access to this household',
                      ),
                      enabled: !_leavingHousehold,
                      onTap: _leavingHousehold
                          ? null
                          : () => _leaveHousehold(
                              context,
                              current.id,
                              current.name,
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
                if (supportsRemotePush)
                  SwitchListTile(
                    title: const Text('Push notifications'),
                    subtitle: const Text('Receive household expiry reminders'),
                    value: _notificationsEnabled,
                    onChanged: _updatingNotifications
                        ? null
                        : _setNotificationsEnabled,
                  )
                else
                  SwitchListTile(
                    title: const Text('Expiry reminders on this iPhone'),
                    subtitle: const Text(
                      'Schedule local alerts from the inventory synced to this device',
                    ),
                    value: _localExpiryRemindersEnabled,
                    onChanged: _updatingNotifications
                        ? null
                        : _setLocalExpiryRemindersEnabled,
                  ),
                ListTile(
                  leading: const Icon(Icons.discord),
                  title: const Text('Discord reminders'),
                  subtitle: const Text(
                    'Connect your own Discord channel for expiry reminders',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DiscordRemindersScreen(),
                    ),
                  ),
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
                  title: Text(AppBrand.name),
                  subtitle: Text(AppBrand.tagline),
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

  Future<void> _setNotificationsEnabled(bool value) async {
    if (!DistributionConfig.supportsRemotePush) return;
    setState(() => _updatingNotifications = true);
    try {
      await FCMService.instance.setPushEnabledForCurrentUser(value);
      await LocalDatabaseService.setNotificationsEnabled(value);
      if (!mounted) return;
      setState(() => _notificationsEnabled = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingNotifications = false);
    }
  }

  Future<void> _setLocalExpiryRemindersEnabled(bool value) async {
    setState(() => _updatingNotifications = true);
    try {
      final inventory = context.read<GroceryViewModel>();
      await LocalExpiryNotificationService.instance.setEnabled(
        value,
        inventory.items,
      );
      if (!mounted) return;
      setState(() => _localExpiryRemindersEnabled = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update expiry reminders: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingNotifications = false);
    }
  }

  Future<void> _leaveHousehold(
    BuildContext context,
    String householdId,
    String householdName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave household?'),
        content: Text('You will lose access to $householdName.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _leavingHousehold = true);
    try {
      await HouseholdMemberService.instance.leaveHousehold(householdId);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Left $householdName.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not leave household: $e')),
      );
    } finally {
      if (mounted) setState(() => _leavingHousehold = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await context.read<FirebaseAuthService>().signOut();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign out: $e')));
    }
  }
}
