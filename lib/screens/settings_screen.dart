import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_auth_service.dart';
import '../services/local_database_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_theme.dart';

/// Minimal trustworthy settings surface for Phase 1.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = LocalDatabaseService.notificationsEnabled;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<FirebaseAuthService>();
    final user = auth.currentUser;
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user?.displayName?.trim().isNotEmpty == true
                  ? user!.displayName!
                  : 'FreshFlag user'),
              subtitle: Text(user?.email ?? 'Signed in'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text('Allow expiry reminder notifications'),
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    await LocalDatabaseService.setNotificationsEnabled(value);
                    if (!mounted) return;
                    setState(() => _notificationsEnabled = value);
                  },
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
                  subtitle: Text('Phase 1 stabilization build'),
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
