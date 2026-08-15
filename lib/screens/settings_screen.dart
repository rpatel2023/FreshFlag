import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/distribution_config.dart';
import '../models/household.dart';
import '../services/fcm_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/local_database_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';
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
  bool _updatingNotifications = false;

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
                    subtitle: Text('${current.timezone} • $roleLabel'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Members & access'),
                    subtitle: const Text('See household members and their roles'),
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
                    supportsRemotePush
                        ? 'Receive household expiry reminders'
                        : 'Unavailable in the SideStore build. Use Discord reminders.',
                  ),
                  value: supportsRemotePush ? _notificationsEnabled : false,
                  onChanged: !supportsRemotePush || _updatingNotifications
                      ? null
                      : _setNotificationsEnabled,
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
